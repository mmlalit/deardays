import { corsHeaders, shortCacheHeaders } from "../_shared/cors.ts";
import { getUserTier } from "../_shared/user-tier.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";
import { generate } from "../_shared/ai-providers.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const { isPremium, userId } = await getUserTier(authHeader);

    // Rate limit check
    const limit = await checkRateLimit(userId, "prompt", isPremium);
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({ error: limit.reason }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const systemPrompt = [
      "Generate a single creative journaling prompt.",
      "Make it thought-provoking but not heavy.",
      "Help the person reflect on their day, feelings, or personal growth.",
      "Keep it to 1-2 sentences.",
      "Return ONLY the prompt text — no quotes, no labels, no explanation.",
    ].join("\n");

    const text = await generate(
      "Give me a journaling prompt for today.",
      systemPrompt,
    );

    return new Response(
      JSON.stringify({ text: text.trim() }),
      { headers: shortCacheHeaders },
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
