// ---------------------------------------------------------------------------
// Configurable AI provider layer
//
// Set these Supabase secrets to control which model is used:
//
//   AI_PROVIDER      = "openai" | "gemini" | "claude"   (default: "openai")
//   AI_MODEL         = e.g. "gpt-4o-mini", "gemini-2.5-flash", "claude-haiku-4-5-20251001"
//   AI_EMBED_MODEL   = e.g. "text-embedding-3-small", "text-embedding-004"
//
// All edge functions call the generic generate() / chat() / embed() exports.
// Switching provider = update one secret + redeploy. No code changes needed.
// ---------------------------------------------------------------------------

const AI_PROVIDER   = (Deno.env.get("AI_PROVIDER")    ?? "openai").toLowerCase();
const AI_MODEL      = Deno.env.get("AI_MODEL")         ?? "gpt-4o-mini";
const AI_EMBED_MODEL = Deno.env.get("AI_EMBED_MODEL")  ?? "text-embedding-3-small";

// ---------------------------------------------------------------------------
// Public API — use these in all edge functions
// ---------------------------------------------------------------------------

/// Single-turn generation (structured tasks: tagging, polish, prompts, summaries)
export async function generate(
  prompt: string,
  systemPrompt?: string,
  maxTokens = 2048,
): Promise<string> {
  if (AI_PROVIDER === "gemini") return _geminiGenerate(prompt, systemPrompt, maxTokens);
  if (AI_PROVIDER === "claude") return _claudeGenerate(prompt, systemPrompt, maxTokens);
  return _openaiGenerate(prompt, systemPrompt, maxTokens);
}

/// Multi-turn conversation (check-in chat, memory search summary)
export async function chat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): Promise<string> {
  if (AI_PROVIDER === "gemini") return _geminiChat(messages, systemPrompt, maxTokens);
  if (AI_PROVIDER === "claude") return _claudeGenerate(
    messages.map(m => `${m.role}: ${m.content}`).join("\n"),
    systemPrompt,
    maxTokens,
  );
  return _openaiChat(messages, systemPrompt, maxTokens);
}

/// Streaming multi-turn conversation — yields tokens as they arrive.
/// Provider-agnostic: switching AI_PROVIDER requires no code changes.
export async function* chatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): AsyncGenerator<string> {
  if (AI_PROVIDER === "gemini") yield* _geminiChatStream(messages, systemPrompt, maxTokens);
  else if (AI_PROVIDER === "claude") yield* _claudeChatStream(messages, systemPrompt, maxTokens);
  else yield* _openaiChatStream(messages, systemPrompt, maxTokens);
}

/// Semantic embedding for vector search
export async function embed(text: string): Promise<number[]> {
  if (AI_PROVIDER === "gemini") return _geminiEmbed(text);
  return _openaiEmbed(text);
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

async function _openaiCall(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number,
): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model: AI_MODEL, messages, temperature: 0.3, max_tokens: maxTokens }),
  });
  if (!res.ok) throw new Error(`OpenAI error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

async function _openaiGenerate(prompt: string, systemPrompt?: string, maxTokens = 1024): Promise<string> {
  const messages: Array<{ role: string; content: string }> = [];
  if (systemPrompt) messages.push({ role: "system", content: systemPrompt });
  messages.push({ role: "user", content: prompt });
  return _openaiCall(messages, maxTokens);
}

async function _openaiChat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): Promise<string> {
  const full: Array<{ role: string; content: string }> = [];
  if (systemPrompt) full.push({ role: "system", content: systemPrompt });
  for (const m of messages) {
    full.push({ role: m.role === "assistant" ? "assistant" : "user", content: m.content });
  }
  return _openaiCall(full, maxTokens);
}

async function _openaiEmbed(text: string): Promise<number[]> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const res = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model: AI_EMBED_MODEL, input: text }),
  });
  if (!res.ok) throw new Error(`OpenAI embed error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const values = data.data?.[0]?.embedding as number[] | undefined;
  if (!values?.length) throw new Error("OpenAI embed: empty response");
  return values;
}

// ---------------------------------------------------------------------------
// Gemini
// ---------------------------------------------------------------------------

async function _geminiGenerate(prompt: string, systemPrompt?: string, maxTokens = 1024): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL}:generateContent?key=${apiKey}`;
  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens: maxTokens },
  };
  if (systemPrompt) body.system_instruction = { parts: [{ text: systemPrompt }] };
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Gemini error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

async function _geminiChat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL}:generateContent?key=${apiKey}`;
  const contents = messages.map(m => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }));
  const body: Record<string, unknown> = {
    contents,
    generationConfig: { maxOutputTokens: maxTokens },
  };
  if (systemPrompt) body.system_instruction = { parts: [{ text: systemPrompt }] };
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Gemini error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

async function _geminiEmbed(text: string): Promise<number[]> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const embedModel = AI_EMBED_MODEL || "text-embedding-004";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${embedModel}:embedContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: `models/${embedModel}`,
      content: { parts: [{ text }] },
    }),
  });
  if (!res.ok) throw new Error(`Gemini embed error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const values = data.embedding?.values as number[] | undefined;
  if (!values?.length) throw new Error("Gemini embed: empty response");
  return values;
}

// ---------------------------------------------------------------------------
// Claude
// ---------------------------------------------------------------------------

async function _claudeGenerate(prompt: string, systemPrompt?: string, maxTokens = 1024): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: AI_MODEL,
      max_tokens: maxTokens,
      ...(systemPrompt ? { system: systemPrompt } : {}),
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`Claude error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.content?.[0]?.text ?? "";
}

// ---------------------------------------------------------------------------
// Streaming implementations (one per provider)
// All yield raw text chunks; the edge function wraps them in SSE.
// ---------------------------------------------------------------------------

async function* _openaiChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): AsyncGenerator<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const full: Array<{ role: string; content: string }> = [];
  if (systemPrompt) full.push({ role: "system", content: systemPrompt });
  for (const m of messages) full.push({ role: m.role === "assistant" ? "assistant" : "user", content: m.content });

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
    body: JSON.stringify({ model: AI_MODEL, messages: full, temperature: 0.3, max_tokens: maxTokens, stream: true }),
  });
  if (!res.ok) throw new Error(`OpenAI error ${res.status}: ${await res.text()}`);

  yield* _readSseStream(res.body!, (parsed) => parsed.choices?.[0]?.delta?.content);
}

async function* _geminiChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): AsyncGenerator<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${AI_MODEL}:streamGenerateContent?key=${apiKey}&alt=sse`;
  const contents = messages.map(m => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: m.content }],
  }));
  const body: Record<string, unknown> = { contents, generationConfig: { maxOutputTokens: maxTokens } };
  if (systemPrompt) body.system_instruction = { parts: [{ text: systemPrompt }] };

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Gemini error ${res.status}: ${await res.text()}`);

  yield* _readSseStream(res.body!, (parsed) => parsed.candidates?.[0]?.content?.parts?.[0]?.text);
}

async function* _claudeChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
): AsyncGenerator<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: AI_MODEL,
      max_tokens: maxTokens,
      stream: true,
      ...(systemPrompt ? { system: systemPrompt } : {}),
      messages: messages.map(m => ({ role: m.role === "assistant" ? "assistant" : "user", content: m.content })),
    }),
  });
  if (!res.ok) throw new Error(`Claude error ${res.status}: ${await res.text()}`);

  yield* _readSseStream(res.body!, (parsed) => {
    if (parsed.type === "content_block_delta" && parsed.delta?.type === "text_delta") {
      return parsed.delta.text;
    }
    return undefined;
  });
}

/// Shared SSE reader — reads a raw HTTP body line-by-line and yields text
/// chunks extracted by the provider-specific `extract` function.
async function* _readSseStream(
  body: ReadableStream<Uint8Array>,
  extract: (parsed: Record<string, unknown>) => string | undefined,
): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed === "data: [DONE]") continue;
      if (trimmed.startsWith("data: ")) {
        try {
          const parsed = JSON.parse(trimmed.slice(6)) as Record<string, unknown>;
          const text = extract(parsed);
          if (text) yield text;
        } catch { /* partial JSON — skip */ }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// OpenAI Whisper — transcription always uses OpenAI regardless of AI_PROVIDER
// ---------------------------------------------------------------------------

export async function whisperTranscribe(
  audioData: Uint8Array,
  filename: string,
): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const formData = new FormData();
  formData.append("file", new Blob([audioData]), filename);
  formData.append("model", "whisper-1");
  const res = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: formData,
  });
  if (!res.ok) throw new Error(`Whisper error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.text ?? "";
}
