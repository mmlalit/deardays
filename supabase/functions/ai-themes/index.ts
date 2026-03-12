import { corsHeaders, noCacheHeaders } from "../_shared/cors.ts";
import { getUserTier } from "../_shared/user-tier.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";
import { geminiGenerate } from "../_shared/ai-providers.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const { isPremium, userId } = await getUserTier(authHeader);

    const { entries } = await req.json();

    if (!entries || !Array.isArray(entries) || entries.length === 0) {
      return new Response(
        JSON.stringify({ error: "entries array required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Combine entries for token estimation
    const inputText = entries.join("\n");

    // Rate limit check (with token estimation)
    const limit = await checkRateLimit(userId, "themes", isPremium, inputText);
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({ error: limit.reason }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const systemPrompt = [
      "Analyze the following journal entries and identify 3-5 recurring themes or patterns.",
      "Return ONLY a valid JSON array of short theme strings.",
      'Example: ["Personal Growth", "Work Stress", "Gratitude"]',
      "No explanation, no markdown — just the JSON array.",
    ].join("\n");

    const prompt = entries
      .map((e: string, i: number) => `Entry ${i + 1}:\n${e}`)
      .join("\n\n");

    const raw = await geminiGenerate(prompt, systemPrompt);

    const jsonMatch = raw.match(/\[[\s\S]*?\]/);
    const themes: string[] = jsonMatch ? JSON.parse(jsonMatch[0]) : [];

    return new Response(
      JSON.stringify({ themes }),
      { headers: noCacheHeaders },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal error";
    const status = message === "Unauthorized" ? 401 : 500;
    return new Response(
      JSON.stringify({ error: message }),
      { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
