// ai-tag: Automatically tags a journal entry with semantic metadata + embedding.
// Called fire-and-forget after entry creation from the Flutter app.
//
// Two-tier approach:
//   Tier 1 — instant, no AI, saves immediately:
//     sentiment_score  (AFINN word-list)
//     people           (relationship words + name heuristic)
//     extracted_locations (known places + preposition patterns)
//
//   Tier 2 — background AI call, saves when complete:
//     emotion, tags, activities, topics  (Gemini/OpenAI)
//     embedding                          (vector search)
//
// This means sentiment is available for photo scoring the moment an entry is saved.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { generate, embed, PROVIDERS } from "../_shared/ai-providers.ts";
import { scoreSentiment, extractPeople, extractLocations } from "../_shared/sentiment.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Auth: require valid Supabase JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const client = createClient(supabaseUrl, supabaseKey);

    // Verify JWT and extract user_id
    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await client.auth.getUser(jwt);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { entry_id, content } = await req.json() as {
      entry_id: string;
      content: string;
    };

    if (!entry_id || !content) {
      return new Response(JSON.stringify({ error: "entry_id and content required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Truncate content to ~3000 chars to stay within token limits
    const truncated = content.length > 3000 ? content.substring(0, 3000) : content;

    // ── Tier 1: instant library-based analysis ───────────────────────────────
    const sentimentScore  = scoreSentiment(truncated);
    const people          = extractPeople(truncated);
    const locations       = extractLocations(truncated);

    // Save tier 1 immediately — available for photo scoring right away
    const { error: tier1Error } = await client
      .from("journal_entries")
      .update({
        sentiment_score:      sentimentScore,
        people:               people,
        extracted_locations:  locations,
      })
      .eq("id", entry_id)
      .eq("user_id", user.id);

    if (tier1Error) {
      console.error("[ai-tag] Tier 1 DB update error:", tier1Error.message);
    } else {
      console.log(
        `[ai-tag] Tier 1 saved — entry ${entry_id} ` +
        `sentiment: ${sentimentScore}, people: ${people.join(", ")}`,
      );
    }

    // ── Tier 2: AI call in background ────────────────────────────────────────
    // Don't await — return response immediately, AI enrichment runs async.
    const tier2Promise = _runAiTagging(client, entry_id, user.id, truncated)
      .catch((e) => console.error("[ai-tag] Tier 2 failed:", e));

    // Deno edge runtime: keep function alive until tier 2 completes
    // even after the response is returned.
    if (typeof (globalThis as unknown as { EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void } })
      .EdgeRuntime?.waitUntil === "function") {
      (globalThis as unknown as { EdgeRuntime: { waitUntil: (p: Promise<unknown>) => void } })
        .EdgeRuntime.waitUntil(tier2Promise);
    }

    return new Response(
      JSON.stringify({ ok: true, tier: 1, sentiment_score: sentimentScore }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[ai-tag] Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ---------------------------------------------------------------------------
// Tier 2 — AI enrichment (emotion, tags, activities, topics, embedding)
// Sentiment / people / locations are already saved by tier 1 — excluded here.
// ---------------------------------------------------------------------------

async function _runAiTagging(
  client: ReturnType<typeof createClient>,
  entry_id: string,
  user_id: string,
  content: string,
): Promise<void> {
  const [analysisRaw, embedding] = await Promise.all([
    _analyzeEntry(content),
    embed(content),
  ]);

  const analysis = _parseAnalysis(analysisRaw);

  const { error } = await client
    .from("journal_entries")
    .update({
      emotion:      analysis.emotion,
      tags:         analysis.tags,
      activities:   analysis.activities,
      topics:       analysis.topics,
      embedding:    embedding,
      tags_generated: true,
    })
    .eq("id", entry_id)
    .eq("user_id", user_id);

  if (error) {
    console.error("[ai-tag] Tier 2 DB update error:", error.message);
  } else {
    console.log(
      `[ai-tag] Tier 2 saved — entry ${entry_id} ` +
      `emotion: ${analysis.emotion}, tags: ${analysis.tags?.join(", ")}`,
    );
  }
}

// ---------------------------------------------------------------------------
// AI prompt — reduced: no longer asks for sentiment, people, or locations
// (those come from tier 1 library). Saves ~30% tokens per call.
// ---------------------------------------------------------------------------

async function _analyzeEntry(content: string): Promise<string> {
  const prompt =
    `Analyze this journal entry and return a JSON object with exactly these fields:\n\n` +
    `- emotion: one primary emotion string from: ` +
    `joy, sadness, anxiety, gratitude, anger, excitement, nostalgia, ` +
    `contentment, frustration, loneliness, pride, love, neutral\n` +
    `- tags: array of 2-6 short topic tags (e.g. ["work", "family", "travel", "health"])\n` +
    `- activities: array of activities described (e.g. ["hiking", "cooking", "reading"])\n` +
    `- topics: array of 1-4 abstract emotional themes ` +
    `(e.g. ["connection", "growth", "loss", "ambition"])\n\n` +
    `Return ONLY valid JSON. No explanation, no markdown, no code block.\n\n` +
    `Journal entry:\n${content}`;

  return (await generate(prompt, undefined, 300, PROVIDERS.FAST)).trim();
}

// ---------------------------------------------------------------------------
// Parse tier 2 AI response
// ---------------------------------------------------------------------------

interface Tier2Analysis {
  emotion:     string;
  tags:        string[];
  activities:  string[];
  topics:      string[];
}

function _parseAnalysis(raw: string): Tier2Analysis {
  const defaults: Tier2Analysis = {
    emotion:    "neutral",
    tags:       [],
    activities: [],
    topics:     [],
  };

  try {
    const cleaned = raw
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/, "")
      .trim();

    const parsed = JSON.parse(cleaned) as Partial<Tier2Analysis>;

    return {
      emotion:    typeof parsed.emotion === "string" ? parsed.emotion : "neutral",
      tags:       Array.isArray(parsed.tags)       ? parsed.tags.map(String)       : [],
      activities: Array.isArray(parsed.activities) ? parsed.activities.map(String) : [],
      topics:     Array.isArray(parsed.topics)     ? parsed.topics.map(String)     : [],
    };
  } catch {
    console.warn("[ai-tag] Failed to parse tier 2 JSON, using defaults. Raw:", raw.substring(0, 200));
    return defaults;
  }
}
