// ai-tag: Automatically tags a journal entry with semantic metadata + embedding.
// Called fire-and-forget after entry creation from the Flutter app.
// Updates journal_entries directly — no response body needed by caller.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { generate, embed } from "../_shared/ai-providers.ts";

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

    // Truncate content to ~3000 chars to stay well within Gemini's token limit
    const truncated = content.length > 3000 ? content.substring(0, 3000) : content;

    // Run analysis and embedding in parallel
    const [analysisRaw, embedding] = await Promise.all([
      _analyzeEntry(truncated),
      embed(truncated),
    ]);

    // Parse the JSON analysis from Gemini
    const analysis = _parseAnalysis(analysisRaw);

    // Update the journal entry with all extracted metadata
    const { error: updateError } = await client
      .from("journal_entries")
      .update({
        sentiment_score: analysis.sentiment_score,
        emotion: analysis.emotion,
        tags: analysis.tags,
        people: analysis.people,
        activities: analysis.activities,
        extracted_locations: analysis.extracted_locations,
        topics: analysis.topics,
        embedding: embedding,
        tags_generated: true,
      })
      .eq("id", entry_id)
      .eq("user_id", user.id);

    if (updateError) {
      console.error("[ai-tag] DB update error:", updateError.message);
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[ai-tag] Tagged entry ${entry_id} — emotion: ${analysis.emotion}, tags: ${analysis.tags?.join(", ")}`);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[ai-tag] Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ---------------------------------------------------------------------------
// Gemini analysis prompt
// ---------------------------------------------------------------------------

async function _analyzeEntry(content: string): Promise<string> {
  const prompt = `Analyze this journal entry and return a JSON object with the following fields:

- sentiment_score: number from -1.0 (very negative) to 1.0 (very positive)
- emotion: one primary emotion string from: joy, sadness, anxiety, gratitude, anger, excitement, nostalgia, contentment, frustration, loneliness, pride, love, neutral
- tags: array of 2-6 short topic tags (e.g. ["work", "family", "travel", "health"])
- people: array of names of people mentioned (first names or relationships, e.g. ["Mom", "Sarah", "my boss"])
- activities: array of activities described (e.g. ["hiking", "cooking", "reading", "meeting"])
- extracted_locations: array of place names mentioned in the text (not from GPS, from the writing itself)
- topics: array of 1-4 abstract emotional themes (e.g. ["connection", "growth", "loss", "ambition"])

Return ONLY valid JSON. No explanation, no markdown, no code block.

Journal entry:
${content}`;

  const raw = await generate(prompt);
  return raw.trim();
}

// ---------------------------------------------------------------------------
// Parse analysis response (with fallback for malformed JSON)
// ---------------------------------------------------------------------------

interface EntryAnalysis {
  sentiment_score: number;
  emotion: string;
  tags: string[];
  people: string[];
  activities: string[];
  extracted_locations: string[];
  topics: string[];
}

function _parseAnalysis(raw: string): EntryAnalysis {
  const defaults: EntryAnalysis = {
    sentiment_score: 0,
    emotion: "neutral",
    tags: [],
    people: [],
    activities: [],
    extracted_locations: [],
    topics: [],
  };

  try {
    // Strip markdown code fences if present
    const cleaned = raw
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/, "")
      .trim();

    const parsed = JSON.parse(cleaned) as Partial<EntryAnalysis>;

    return {
      sentiment_score: typeof parsed.sentiment_score === "number"
        ? Math.max(-1, Math.min(1, parsed.sentiment_score))
        : 0,
      emotion: typeof parsed.emotion === "string" ? parsed.emotion : "neutral",
      tags: Array.isArray(parsed.tags) ? parsed.tags.map(String) : [],
      people: Array.isArray(parsed.people) ? parsed.people.map(String) : [],
      activities: Array.isArray(parsed.activities) ? parsed.activities.map(String) : [],
      extracted_locations: Array.isArray(parsed.extracted_locations)
        ? parsed.extracted_locations.map(String)
        : [],
      topics: Array.isArray(parsed.topics) ? parsed.topics.map(String) : [],
    };
  } catch {
    console.warn("[ai-tag] Failed to parse analysis JSON, using defaults. Raw:", raw.substring(0, 200));
    return defaults;
  }
}
