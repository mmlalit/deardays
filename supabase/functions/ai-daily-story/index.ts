/**
 * ai-daily-story — Daily story page generator
 *
 * Triggered by pg_cron at midnight (user's timezone or UTC fallback).
 * Can also be invoked on-demand from the app as a fallback.
 *
 * For each user with entries today (or for a specific user+date):
 *   1. Fetches all grammar-fixed memories for that date
 *   2. Calls AI to weave them into one flowing daily narrative
 *   3. Extracts highlights, mood_summary, and people
 *   4. Splits narrative into ~250-word pages
 *   5. Upserts rows into the pages table (granularity='daily')
 *
 * Request body (optional — for on-demand single-user generation):
 *   { "user_id": "uuid", "date": "2026-03-30" }
 *
 * If no body, processes all users with needs_refresh=true daily pages
 * or users who have entries today but no daily page yet.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { generate, PROVIDERS } from "../_shared/ai-providers.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const WORDS_PER_PAGE = 250;
const BATCH_LIMIT = 50; // max users per cron invocation

// ---------------------------------------------------------------------------
// Daily story prompt
// ---------------------------------------------------------------------------

const DAILY_STORY_PROMPT = `You are writing a daily journal page for a personal life book.

INPUT: Multiple journal entries from the same day, in chronological order.
Each entry has: time, content (grammar-fixed), mood, and optional location.

YOUR TASK:
1. Weave ALL entries into ONE flowing narrative of the day.
2. Write in first person ("I", "we", "my").
3. Keep the same tense as the user's original text.
4. Transition naturally between different moments of the day.
5. Keep ALL facts, people, and events — do not drop anything.
6. Do NOT add details, emotions, or events the user did not write.
7. Do NOT use fancy or literary language. Write like a normal person.
8. No word limit — write as much as the content needs.
9. If there is only ONE entry, retell it as a story page (same rules).

ALSO extract and return as JSON:
- "highlights": array of 2-5 short bullet points (key moments of the day)
- "mood_summary": one short sentence describing the emotional arc
- "people": array of names/people mentioned

RESPONSE FORMAT (strict JSON):
{
  "story": "The morning started with...",
  "highlights": ["Morning run — 8km personal best", "Mom's 60th birthday dinner"],
  "mood_summary": "Started calm, ended joyful",
  "people": ["Mom", "Dad", "Aanya"]
}

Return ONLY valid JSON. No markdown. No explanation.`;

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json().catch(() => ({}));
    const singleUserId = body.user_id as string | undefined;
    const singleDate = body.date as string | undefined;

    let usersToProcess: { user_id: string; date: string }[] = [];

    if (singleUserId && singleDate) {
      // On-demand: generate for specific user + date
      usersToProcess = [{ user_id: singleUserId, date: singleDate }];
    } else {
      // Cron: find all users who need daily pages generated
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const dateStr = yesterday.toISOString().split("T")[0];

      // Users with entries yesterday but no daily page, OR pages needing refresh
      const { data: needsGen } = await supabase.rpc(
        "get_users_needing_daily_story",
        { p_date: dateStr },
      );

      usersToProcess = (needsGen ?? [])
        .slice(0, BATCH_LIMIT)
        .map((r: { user_id: string }) => ({
          user_id: r.user_id,
          date: dateStr,
        }));
    }

    const results = [];

    for (const { user_id, date } of usersToProcess) {
      try {
        const result = await generateDailyStory(user_id, date);
        results.push({ user_id, date, status: "ok", pages: result.pageCount });
      } catch (e) {
        console.error(`[ai-daily-story] Failed for ${user_id} on ${date}:`, e);
        results.push({ user_id, date, status: "error", error: String(e) });
      }
    }

    return new Response(JSON.stringify({ processed: results.length, results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[ai-daily-story] Fatal error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

// ---------------------------------------------------------------------------
// Core generation logic
// ---------------------------------------------------------------------------

async function generateDailyStory(
  userId: string,
  date: string,
): Promise<{ pageCount: number }> {
  // 1. Fetch entries for this date
  const { data: entries, error: fetchErr } = await supabase.rpc(
    "get_entries_for_daily_story",
    { p_user_id: userId, p_date: date },
  );

  if (fetchErr) throw new Error(`Fetch entries failed: ${fetchErr.message}`);
  if (!entries || entries.length === 0) {
    return { pageCount: 0 }; // No entries — nothing to generate
  }

  // 2. Build input text for AI
  const inputLines = entries.map((e: any) => {
    const parts = [`[${e.entry_time}]`];
    if (e.mood) parts.push(`(mood: ${e.mood})`);
    if (e.location_name) parts.push(`(at: ${e.location_name})`);
    parts.push(e.content);
    return parts.join(" ");
  });

  const userInput = inputLines.join("\n\n---\n\n");

  // 3. Call AI
  const aiResponse = await generate({
    provider: PROVIDERS.primary,
    systemPrompt: DAILY_STORY_PROMPT,
    userPrompt: userInput,
    maxTokens: 4000,
    temperature: 0.7,
  });

  // 4. Parse JSON response
  let parsed: {
    story: string;
    highlights: string[];
    mood_summary: string;
    people: string[];
  };

  try {
    // Strip markdown code fences if present
    const cleaned = aiResponse
      .replace(/^```json\s*/i, "")
      .replace(/```\s*$/, "")
      .trim();
    parsed = JSON.parse(cleaned);
  } catch {
    // If JSON parsing fails, treat entire response as story text
    parsed = {
      story: aiResponse.trim(),
      highlights: [],
      mood_summary: "",
      people: [],
    };
  }

  if (!parsed.story || parsed.story.trim().length === 0) {
    return { pageCount: 0 };
  }

  // 5. Get user's default book
  const { data: books } = await supabase
    .from("books")
    .select("id")
    .eq("user_id", userId)
    .order("sort_order")
    .limit(1);

  const bookId = books?.[0]?.id ?? null;

  // 6. Split story into ~250-word pages
  const words = parsed.story.split(/\s+/);
  const pages: { content: string; wordCount: number; pageNumber: number }[] = [];

  if (words.length <= WORDS_PER_PAGE) {
    pages.push({
      content: parsed.story,
      wordCount: words.length,
      pageNumber: 0,
    });
  } else {
    let wordIdx = 0;
    let pageNum = 0;
    while (wordIdx < words.length) {
      const end = Math.min(wordIdx + WORDS_PER_PAGE, words.length);
      // Try to break at paragraph boundary
      let breakAt = end;
      if (end < words.length) {
        const slice = words.slice(wordIdx, end).join(" ");
        const lastParagraph = slice.lastIndexOf("\n\n");
        if (lastParagraph > slice.length * 0.5) {
          breakAt = wordIdx + slice.substring(0, lastParagraph).split(/\s+/).length;
        }
      }
      const pageWords = words.slice(wordIdx, breakAt);
      pages.push({
        content: pageWords.join(" "),
        wordCount: pageWords.length,
        pageNumber: pageNum,
      });
      wordIdx = breakAt;
      pageNum++;
    }
  }

  // 7. Delete existing daily pages for this date (full replace)
  await supabase
    .from("pages")
    .delete()
    .eq("user_id", userId)
    .eq("granularity", "daily")
    .eq("page_date", date);

  // 8. Insert new pages
  const entryIds = entries.map((e: any) => e.id);

  const pageRows = pages.map((p) => ({
    user_id: userId,
    book_id: bookId,
    chapter_id: null,
    granularity: "daily",
    page_date: date,
    week_start: getWeekStart(date),
    page_number: p.pageNumber,
    content: p.content,
    word_count: p.wordCount,
    highlights: parsed.highlights,
    mood_summary: parsed.mood_summary,
    people: parsed.people,
    entry_ids: entryIds,
    needs_refresh: false,
    status: "published",
    source: "daily_cron",
  }));

  const { error: insertErr } = await supabase.from("pages").insert(pageRows);

  if (insertErr) throw new Error(`Insert pages failed: ${insertErr.message}`);

  // 9. Log cost
  await supabase.from("ai_cost_log").insert({
    user_id: userId,
    function_name: "ai-daily-story",
    input_tokens: Math.ceil(userInput.length / 4),
    output_tokens: Math.ceil(parsed.story.length / 4),
    model: PROVIDERS.primary.model,
  }).catch(() => {}); // non-critical

  return { pageCount: pages.length };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getWeekStart(dateStr: string): string {
  const d = new Date(dateStr);
  const day = d.getDay(); // 0=Sun, 1=Mon, ...
  const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Monday
  const monday = new Date(d.setDate(diff));
  return monday.toISOString().split("T")[0];
}
