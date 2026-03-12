import { corsHeaders, noCacheHeaders } from "../_shared/cors.ts";
import { getUserTier } from "../_shared/user-tier.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";
import {
  claudeGenerate,
  geminiGenerate,
} from "../_shared/ai-providers.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const { isPremium, userId } = await getUserTier(authHeader);

    const { text: rawText, style, language } = await req.json();

    if (!rawText || typeof rawText !== "string") {
      return new Response(
        JSON.stringify({ error: "text field required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Rate limit check (with token estimation)
    const limit = await checkRateLimit(userId, "polish", isPremium, rawText);
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({ error: limit.reason }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const writingStyle = style || "memoir";

    const systemPrompt = [
      `You are a literary writer crafting a personal ${writingStyle}.`,
      "Transform the raw journal entries below into beautiful, polished prose.",
      "Maintain the original meaning, emotions, and personal details exactly.",
      "Elevate the language while keeping the author's authentic voice.",
      "Use paragraphs to separate distinct ideas or moments.",
      "Do NOT add fictional events, names, or details that weren't in the original.",
      "Do NOT include titles, headers, or meta-commentary — just the prose.",
      language
        ? `Write in ${language}.`
        : "",
    ]
      .filter(Boolean)
      .join("\n");

    let text: string;

    if (isPremium) {
      text = await claudeGenerate(rawText, systemPrompt);
    } else {
      text = await geminiGenerate(rawText, systemPrompt);
    }

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
