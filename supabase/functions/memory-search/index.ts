// memory-search: Conversational search over journal entries.
// 1. Rule-based query parsing (year, mood, emotion, people, activities)
// 2. SQL filter search (fast, no AI cost for structured queries)
// 3. Optional vector reranking (when query is semantic / open-ended)
// 4. Gemini summary synthesising the answer from matched entries

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { generate, embed } from "../_shared/ai-providers.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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

    const jwt = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await client.auth.getUser(jwt);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { query, language } = await req.json() as {
      query: string;
      language?: string;
    };

    if (!query?.trim()) {
      return new Response(JSON.stringify({ error: "query required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ----------------------------------------------------------------
    // Step 1: Parse query for structured filters
    // ----------------------------------------------------------------
    const filters = _parseQuery(query);
    console.log("[memory-search] Parsed filters:", JSON.stringify(filters));

    // ----------------------------------------------------------------
    // Step 2: SQL filter search
    // ----------------------------------------------------------------
    const { data: filterRows, error: filterError } = await client.rpc(
      "search_entries_by_filters",
      {
        p_user_id:    user.id,
        p_mood:       filters.mood ?? null,
        p_emotion:    filters.emotion ?? null,
        p_year:       filters.year ?? null,
        p_tags:       filters.tags.length > 0 ? filters.tags : null,
        p_people:     filters.people.length > 0 ? filters.people : null,
        p_activities: filters.activities.length > 0 ? filters.activities : null,
        p_start_date: filters.startDate ?? null,
        p_end_date:   filters.endDate ?? null,
        p_limit:      100,
      },
    );

    if (filterError) {
      console.error("[memory-search] Filter RPC error:", filterError.message);
    }

    let candidateIds: string[] = (filterRows ?? []).map((r: { id: string }) => r.id);

    // ----------------------------------------------------------------
    // Step 3: Vector similarity reranking (when query is semantic)
    // ----------------------------------------------------------------
    const isSemanticQuery = _isSemanticQuery(query, filters);
    let vectorIds: string[] = [];

    if (isSemanticQuery) {
      try {
        const embedding = await embed(query);
        const { data: vectorRows, error: vectorError } = await client.rpc(
          "search_entries_by_embedding",
          {
            p_user_id:   user.id,
            p_embedding: embedding,
            p_limit:     30,
            p_threshold: 0.6,
          },
        );

        if (vectorError) {
          console.warn("[memory-search] Vector RPC error:", vectorError.message);
        } else {
          vectorIds = (vectorRows ?? []).map((r: { id: string }) => r.id);
        }
      } catch (embErr) {
        console.warn("[memory-search] Embedding error (non-fatal):", embErr);
      }
    }

    // Merge: vector results first (higher relevance), then filter results
    // Deduplicate and cap at 20 entries for the AI summary
    const seen = new Set<string>();
    const merged: string[] = [];
    for (const id of [...vectorIds, ...candidateIds]) {
      if (!seen.has(id)) {
        seen.add(id);
        merged.push(id);
      }
      if (merged.length >= 20) break;
    }

    // If no results at all, fall back to the most recent 10 entries
    let entryIds = merged;
    if (entryIds.length === 0) {
      const { data: recent } = await client
        .from("journal_entries")
        .select("id")
        .eq("user_id", user.id)
        .order("entry_date", { ascending: false })
        .limit(10);
      entryIds = (recent ?? []).map((r: { id: string }) => r.id);
    }

    // ----------------------------------------------------------------
    // Step 4: Load entry summaries for the AI
    // ----------------------------------------------------------------
    const { data: entries, error: entriesError } = await client
      .from("journal_entries")
      .select("id, entry_date, mood, emotion, content, location_name")
      .in("id", entryIds)
      .eq("user_id", user.id);

    if (entriesError) {
      console.error("[memory-search] Entries fetch error:", entriesError.message);
    }

    const entryList = (entries ?? []) as Array<{
      id: string;
      entry_date: string;
      mood: string | null;
      emotion: string | null;
      content: string;
      location_name: string | null;
    }>;

    // ----------------------------------------------------------------
    // Step 5: Gemini summary
    // ----------------------------------------------------------------
    const answer = await _generateAnswer(query, entryList, language);

    // Build follow-up suggestions based on what was found
    const followUps = _generateFollowUps(query, entryList);

    return new Response(
      JSON.stringify({
        answer,
        entry_ids: entryIds,
        follow_up_questions: followUps,
        total_searched: entryIds.length,
        used_vector: isSemanticQuery && vectorIds.length > 0,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[memory-search] Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ---------------------------------------------------------------------------
// Query parser — extracts structured filters without LLM cost
// ---------------------------------------------------------------------------

interface QueryFilters {
  mood?: string;
  emotion?: string;
  year?: number;
  tags: string[];
  people: string[];
  activities: string[];
  startDate?: string;
  endDate?: string;
}

function _parseQuery(q: string): QueryFilters {
  const lower = q.toLowerCase();
  const filters: QueryFilters = { tags: [], people: [], activities: [] };

  // Year extraction: "in 2023", "last year" (relative), "2022", etc.
  const yearMatch = lower.match(/\b(20\d{2})\b/);
  if (yearMatch) {
    filters.year = parseInt(yearMatch[1]);
  } else if (lower.includes("last year")) {
    filters.year = new Date().getFullYear() - 1;
  } else if (lower.includes("this year")) {
    filters.year = new Date().getFullYear();
  }

  // Mood mapping
  const moodMap: Record<string, string> = {
    "great": "great", "amazing": "great", "fantastic": "great",
    "good": "good", "happy": "good", "well": "good",
    "okay": "okay", "ok": "okay", "fine": "okay",
    "sad": "low", "low": "low", "down": "low", "unhappy": "low",
    "tough": "tough", "terrible": "tough", "awful": "tough", "bad": "tough",
  };
  for (const [keyword, mood] of Object.entries(moodMap)) {
    if (lower.includes(`feeling ${keyword}`) || lower.includes(`felt ${keyword}`) ||
        lower.includes(`was ${keyword}`) || lower.includes(`mood was ${keyword}`)) {
      filters.mood = mood;
      break;
    }
  }

  // Emotion mapping
  const emotionKeywords: Record<string, string> = {
    "anxious": "anxiety", "anxiety": "anxiety", "stressed": "anxiety", "worried": "anxiety",
    "grateful": "gratitude", "thankful": "gratitude", "appreciative": "gratitude",
    "excited": "excitement", "thrilled": "excitement",
    "nostalgic": "nostalgia", "nostalgically": "nostalgia", "miss": "nostalgia",
    "proud": "pride", "accomplished": "pride",
    "lonely": "loneliness", "alone": "loneliness",
    "angry": "anger", "frustrated": "frustration",
    "joyful": "joy", "joyous": "joy",
    "content": "contentment", "peaceful": "contentment",
    "love": "love", "loved": "love",
  };
  for (const [keyword, emotion] of Object.entries(emotionKeywords)) {
    if (lower.includes(keyword)) {
      filters.emotion = emotion;
      break;
    }
  }

  // Activity extraction (common keywords)
  const activityKeywords = [
    "hiking", "running", "cooking", "reading", "writing",
    "traveling", "travel", "working", "exercising", "yoga",
    "meditating", "swimming", "cycling", "studying",
  ];
  for (const activity of activityKeywords) {
    if (lower.includes(activity)) {
      filters.activities.push(activity.replace("ing", "").replace("ling", "l"));
    }
  }

  return filters;
}

// Determines if we should do vector similarity search in addition to SQL filters
function _isSemanticQuery(query: string, filters: QueryFilters): boolean {
  const lower = query.toLowerCase();
  // If query is purely structured (year + mood), SQL is enough
  if (filters.year && filters.mood && !filters.emotion && filters.activities.length === 0) {
    return false;
  }
  // Open-ended questions benefit from vector search
  const semanticStarters = [
    "when did", "what was", "how did", "why did", "tell me about",
    "show me", "find", "last time", "first time", "remember",
    "memories about", "entries about", "times when",
  ];
  return semanticStarters.some((s) => lower.includes(s)) || lower.endsWith("?");
}

// ---------------------------------------------------------------------------
// Gemini answer generation
// ---------------------------------------------------------------------------

async function _generateAnswer(
  query: string,
  entries: Array<{
    id: string;
    entry_date: string;
    mood: string | null;
    emotion: string | null;
    content: string;
    location_name: string | null;
  }>,
  language?: string,
): Promise<string> {
  if (entries.length === 0) {
    return "I couldn't find any matching memories for that query. Try writing more entries or rephrasing your question.";
  }

  const entrySummaries = entries.map((e, i) => {
    const date = e.entry_date.split("T")[0];
    const mood = e.mood ?? "unknown";
    const emotion = e.emotion ?? "";
    const location = e.location_name ? ` | ${e.location_name}` : "";
    const snippet = e.content.replace(/\n+/g, " ").substring(0, 200);
    return `[${i + 1}] ${date} | ${mood}${emotion ? " / " + emotion : ""}${location}\n${snippet}`;
  }).join("\n\n");

  const langNote = language && language !== "English"
    ? `\nRespond in ${language}.`
    : "";

  const prompt = `You are a warm, empathetic journal companion. The user asked: "${query}"

Here are their relevant journal entries:

${entrySummaries}

Answer their question naturally and conversationally, drawing on the specific entries. Reference dates and feelings when relevant. Be concise (2-4 sentences). Don't list every entry — synthesize the most meaningful insight.${langNote}`;

  try {
    return await generate(prompt);
  } catch {
    // Fallback if Gemini fails
    const count = entries.length;
    return `I found ${count} ${count === 1 ? "memory" : "memories"} matching your search. The most recent is from ${entries[0].entry_date.split("T")[0]}.`;
  }
}

// ---------------------------------------------------------------------------
// Follow-up question suggestions
// ---------------------------------------------------------------------------

function _generateFollowUps(
  query: string,
  entries: Array<{ mood: string | null; emotion: string | null; entry_date: string }>,
): string[] {
  if (entries.length === 0) return [];

  const suggestions: string[] = [];
  const lower = query.toLowerCase();

  // Date-based follow-ups
  if (!lower.includes("last year") && !lower.match(/\b20\d{2}\b/)) {
    const year = new Date().getFullYear() - 1;
    suggestions.push(`What about in ${year}?`);
  }

  // Mood-based follow-ups
  const moods = [...new Set(entries.map((e) => e.mood).filter(Boolean))];
  if (!lower.includes("happy") && moods.includes("good")) {
    suggestions.push("When was I happiest?");
  }
  if (!lower.includes("anxious") && !lower.includes("stress")) {
    suggestions.push("When did I feel most anxious?");
  }

  // Generic
  if (!lower.includes("proudest") && !lower.includes("proud")) {
    suggestions.push("When did I feel most proud of myself?");
  }

  return suggestions.slice(0, 3);
}
