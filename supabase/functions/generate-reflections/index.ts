/**
 * generate-reflections — scheduled Edge Function
 *
 * Runs on a cron schedule (see supabase/config.toml):
 *   - Every Sunday  23:00 UTC → generates weekly reflections
 *   - 1st of month  23:30 UTC → generates monthly reflections (from weekly cache)
 *   - Jan 1         23:45 UTC → generates yearly reflections (from monthly cache)
 *
 * For each period it:
 *   1. Finds all users who have entries in the relevant date range
 *   2. Skips users who already have a fresh cache entry for this period_key
 *   3. Calls Gemini to generate summary + themes for the rest
 *   4. Upserts results into reflection_cache
 *
 * Uses service_role key — runs entirely server-side, bypasses RLS.
 * User data is never logged or retained beyond the function invocation.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { geminiGenerate } from "../_shared/ai-providers.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

// ── Period key helpers ────────────────────────────────────────────────────────

function isoWeekKey(date: Date): string {
  const thursday = new Date(date);
  thursday.setDate(date.getDate() + (4 - (date.getDay() || 7)));
  const yearStart = new Date(thursday.getFullYear(), 0, 1);
  const weekNum = Math.ceil(
    ((thursday.getTime() - yearStart.getTime()) / 86400000 + 1) / 7,
  );
  return `${thursday.getFullYear()}-W${String(weekNum).padStart(2, "0")}`;
}

function monthKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function yearKey(date: Date): string {
  return String(date.getFullYear());
}

// Week keys that fall inside a given year-month
function weekKeysForMonth(year: number, month: number): string[] {
  const keys = new Set<string>();
  const daysInMonth = new Date(year, month, 0).getDate();
  for (let day = 1; day <= daysInMonth; day++) {
    keys.add(isoWeekKey(new Date(year, month - 1, day)));
  }
  return [...keys];
}

// Monthly keys for a given year
function monthKeysForYear(year: number): string[] {
  return Array.from({ length: 12 }, (_, i) =>
    `${year}-${String(i + 1).padStart(2, "0")}`
  );
}

// ── Prompt builders ───────────────────────────────────────────────────────────

function summaryPrompt(period: string): string {
  return [
    `Summarize the following ${period} journal entries.`,
    "Highlight key themes, emotions, and notable events.",
    "Be warm, personal, and reflective — as if writing to the person.",
    "Keep it to 3-5 sentences.",
  ].join("\n");
}

function themesPrompt(): string {
  return [
    "Extract 3-6 recurring themes from these journal entries.",
    "Return ONLY a JSON array of short theme labels, e.g.: [\"Family\",\"Travel\",\"Growth\"]",
    "No explanation, no markdown, just the JSON array.",
  ].join("\n");
}

function entriesText(entries: string[]): string {
  return entries
    .map((e, i) => `Entry ${i + 1}:\n${e.slice(0, 1500)}`)
    .join("\n\n");
}

// ── Core generator ────────────────────────────────────────────────────────────

async function generateForUser(
  userId: string,
  period: "weekly" | "monthly" | "yearly",
  periodKey: string,
  inputTexts: string[],
): Promise<void> {
  if (inputTexts.length === 0) return;

  const prompt = entriesText(inputTexts);

  // Generate summary and themes in parallel to halve latency.
  const [summary, themesRaw] = await Promise.all([
    geminiGenerate(prompt, summaryPrompt(period)),
    geminiGenerate(prompt, themesPrompt()),
  ]);

  let themes: string[] = [];
  try {
    const parsed = JSON.parse(themesRaw);
    if (Array.isArray(parsed)) themes = parsed.map(String);
  } catch {
    // themesRaw was not valid JSON — skip themes rather than crash
  }

  await supabase.from("reflection_cache").upsert(
    {
      user_id: userId,
      period,
      period_key: periodKey,
      summary,
      themes,
      generated_at: new Date().toISOString(),
    },
    { onConflict: "user_id,period,period_key" },
  );
}

// ── Weekly run ────────────────────────────────────────────────────────────────

async function runWeekly(now: Date): Promise<number> {
  const periodKey = isoWeekKey(now);
  const since = new Date(now);
  since.setDate(now.getDate() - 6);

  // Users who have entries this week and don't have a cache entry yet.
  const { data: active } = await supabase.rpc("get_active_users_since", {
    since_date: since.toISOString().split("T")[0],
  });
  if (!active?.length) return 0;

  const alreadyCached = await supabase
    .from("reflection_cache")
    .select("user_id")
    .eq("period", "weekly")
    .eq("period_key", periodKey)
    .in("user_id", active.map((r: { user_id: string }) => r.user_id));

  const cachedIds = new Set(
    (alreadyCached.data ?? []).map((r: { user_id: string }) => r.user_id),
  );
  const pending = active.filter(
    (r: { user_id: string }) => !cachedIds.has(r.user_id),
  );

  let count = 0;
  for (const { user_id } of pending) {
    const { data: entries } = await supabase
      .from("journal_entries")
      .select("content, polished_content")
      .eq("user_id", user_id)
      .gte("entry_date", since.toISOString().split("T")[0])
      .lte("entry_date", now.toISOString().split("T")[0])
      .limit(50);

    const texts = (entries ?? []).map(
      (e: { content: string; polished_content: string | null }) =>
        e.polished_content ?? e.content,
    );
    await generateForUser(user_id, "weekly", periodKey, texts);
    count++;
  }
  return count;
}

// ── Monthly run (1st of month) ────────────────────────────────────────────────

async function runMonthly(now: Date): Promise<number> {
  const prevMonth = now.getMonth() === 0
    ? new Date(now.getFullYear() - 1, 11, 1)
    : new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const periodKey = monthKey(prevMonth);
  const weekKeys = weekKeysForMonth(prevMonth.getFullYear(), prevMonth.getMonth() + 1);

  // All users with any weekly cache in that month.
  const { data: weeklyCaches } = await supabase
    .from("reflection_cache")
    .select("user_id, summary")
    .eq("period", "weekly")
    .in("period_key", weekKeys);

  if (!weeklyCaches?.length) return 0;

  // Group by user.
  const byUser = new Map<string, string[]>();
  for (const row of weeklyCaches) {
    if (!row.summary) continue;
    const list = byUser.get(row.user_id) ?? [];
    list.push(row.summary);
    byUser.set(row.user_id, list);
  }

  // Skip users already cached for this monthly key.
  const userIds = [...byUser.keys()];
  const { data: existing } = await supabase
    .from("reflection_cache")
    .select("user_id")
    .eq("period", "monthly")
    .eq("period_key", periodKey)
    .in("user_id", userIds);

  const cachedIds = new Set(
    (existing ?? []).map((r: { user_id: string }) => r.user_id),
  );

  let count = 0;
  for (const [userId, summaries] of byUser) {
    if (cachedIds.has(userId)) continue;
    await generateForUser(userId, "monthly", periodKey, summaries);
    count++;
  }
  return count;
}

// ── Yearly run (Jan 1) ────────────────────────────────────────────────────────

async function runYearly(now: Date): Promise<number> {
  const year = now.getFullYear() - 1;
  const periodKey = String(year);
  const mKeys = monthKeysForYear(year);

  const { data: monthlyCaches } = await supabase
    .from("reflection_cache")
    .select("user_id, summary")
    .eq("period", "monthly")
    .in("period_key", mKeys);

  if (!monthlyCaches?.length) return 0;

  const byUser = new Map<string, string[]>();
  for (const row of monthlyCaches) {
    if (!row.summary) continue;
    const list = byUser.get(row.user_id) ?? [];
    list.push(row.summary);
    byUser.set(row.user_id, list);
  }

  const userIds = [...byUser.keys()];
  const { data: existing } = await supabase
    .from("reflection_cache")
    .select("user_id")
    .eq("period", "yearly")
    .eq("period_key", periodKey)
    .in("user_id", userIds);

  const cachedIds = new Set(
    (existing ?? []).map((r: { user_id: string }) => r.user_id),
  );

  let count = 0;
  for (const [userId, summaries] of byUser) {
    if (cachedIds.has(userId)) continue;
    await generateForUser(userId, "yearly", periodKey, summaries);
    count++;
  }
  return count;
}

// ── Entry point ───────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // Allow manual trigger via POST with { "period": "weekly"|"monthly"|"yearly" }
  // Scheduled invocations send an empty body.
  const now = new Date();
  const dayOfWeek = now.getUTCDay(); // 0 = Sun
  const dayOfMonth = now.getUTCDate();
  const month = now.getUTCMonth(); // 0 = Jan

  let body: Record<string, string> = {};
  try {
    if (req.body) body = await req.json();
  } catch { /* empty body on cron */ }

  const forcePeriod = body.period as string | undefined;

  const results: Record<string, number> = {};

  try {
    // Weekly: every Sunday OR forced
    if (forcePeriod === "weekly" || (!forcePeriod && dayOfWeek === 0)) {
      results.weekly = await runWeekly(now);
    }

    // Monthly: 1st of month OR forced
    if (forcePeriod === "monthly" || (!forcePeriod && dayOfMonth === 1)) {
      results.monthly = await runMonthly(now);
    }

    // Yearly: Jan 1 OR forced
    if (
      forcePeriod === "yearly" ||
      (!forcePeriod && dayOfMonth === 1 && month === 0)
    ) {
      results.yearly = await runYearly(now);
    }

    return new Response(JSON.stringify({ ok: true, generated: results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[generate-reflections]", message);
    return new Response(JSON.stringify({ ok: false, error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
