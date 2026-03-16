import { corsHeaders, noCacheHeaders } from "../_shared/cors.ts";
import { getUserTier } from "../_shared/user-tier.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";
import { chat, chatStream } from "../_shared/ai-providers.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const { isPremium, userId } = await getUserTier(authHeader);

    const { messages, mood, is_first_checkin, language, stream } = await req.json();

    if (!messages || !Array.isArray(messages)) {
      return new Response(
        JSON.stringify({ error: "messages array required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Combine user messages for token estimation
    const inputText = messages
      .filter((m: { role: string }) => m.role === "user")
      .map((m: { content: string }) => m.content)
      .join("\n");

    // Rate limit check (with token estimation)
    const limit = await checkRateLimit(userId, "chat", isPremium, inputText);
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({ error: limit.reason }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Build system prompt
    const parts: string[] = [
      "You are a warm, empathetic journaling companion for DearDays.",
      "Help users reflect on their day through gentle, supportive conversation.",
      "Ask thoughtful follow-up questions to help them explore their feelings.",
      "Keep responses concise — typically 2-3 sentences.",
      "Never give medical or clinical advice.",
    ];

    if (mood) {
      parts.push(`The user's current mood is: ${mood}. Be sensitive to this.`);
    }
    if (is_first_checkin) {
      parts.push(
        "This is the user's first check-in today. Start with a warm greeting.",
      );
    }
    if (language) {
      parts.push(
        `Default to ${language}, but mirror the user's language if they switch.`,
      );
    }

    const systemPrompt = parts.join("\n");

    // ── Streaming path ────────────────────────────────────────────────
    if (stream) {
      const encoder = new TextEncoder();
      const body = new ReadableStream({
        async start(controller) {
          try {
            for await (const chunk of chatStream(messages, systemPrompt)) {
              controller.enqueue(encoder.encode(`data: ${JSON.stringify({ text: chunk })}\n\n`));
            }
            controller.enqueue(encoder.encode("data: [DONE]\n\n"));
          } catch (err) {
            const msg = err instanceof Error ? err.message : "Stream error";
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ error: msg })}\n\n`));
          } finally {
            controller.close();
          }
        },
      });
      return new Response(body, {
        headers: {
          ...corsHeaders,
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "X-Accel-Buffering": "no",
        },
      });
    }

    // ── Non-streaming path (fallback) ─────────────────────────────────
    const text = await chat(messages, systemPrompt);
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
