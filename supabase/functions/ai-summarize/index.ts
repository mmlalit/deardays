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

    const { entries, period, language } = await req.json();

    if (!entries || !Array.isArray(entries) || entries.length === 0) {
      return new Response(
        JSON.stringify({ error: "entries array required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Combine entries for token estimation
    const inputText = entries.join("\n");

    // Rate limit check (with token estimation)
    const limit = await checkRateLimit(userId, "summarize", isPremium, inputText);
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({ error: limit.reason }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const timePeriod = period || "weekly";

    const systemPrompt = [
      `Summarize the following journal entries from the past ${timePeriod} period.`,
      "Highlight key themes, emotions, and notable events.",
      "Be warm and reflective in tone.",
      "Keep it concise — 3-5 sentences.",
      language ? `Write in ${language}.` : "",
    ]
      .filter(Boolean)
      .join("\n");

    const prompt = entries
      .map((e: string, i: number) => `Entry ${i + 1}:\n${e}`)
      .join("\n\n");

    const text = await geminiGenerate(prompt, systemPrompt);

    return new Response(
      JSON.stringify({ text }),
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
