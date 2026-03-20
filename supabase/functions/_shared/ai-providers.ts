// ---------------------------------------------------------------------------
// Configurable AI provider layer
//
// Global defaults via Supabase secrets:
//   AI_PROVIDER      = "openai" | "gemini" | "claude" | "groq"  (default: "openai")
//   AI_MODEL         = e.g. "gpt-4o-mini", "gemini-2.5-flash"
//   AI_EMBED_MODEL   = e.g. "text-embedding-3-small", "text-embedding-004"
//   GROQ_MODEL       = e.g. "llama-3.1-8b-instant"  (default: "llama-3.1-8b-instant")
//
// Per-call override:
//   Pass a CallOptions object as the last argument to generate() / chat() /
//   chatStream() / embed(). The PROVIDERS presets cover all routing decisions
//   so edge functions never need to hard-code model strings.
//
//   import { generate, PROVIDERS } from "../_shared/ai-providers.ts";
//   await generate(prompt, system, 2048, PROVIDERS.QUALITY);
//
// Routing strategy (see PROVIDERS below for details):
//   FAST         → Groq llama-3.2-3b  — tagging, titles, themes, cover queries
//   CHAT         → Groq llama-3.1-8b  — check-in chat, search, reflections
//   QUALITY      → OpenAI gpt-4o-mini — memoir polish (quality-critical)
//   POLISH_CLEAN → Gemini 2.5 Flash   — clean polish (near-quality, cheaper)
//   BACKGROUND   → Gemini 1.5 Flash   — weekly/story cron jobs (batch, cheap)
// ---------------------------------------------------------------------------

// Deno runtime globals — provided by the edge runtime, not in standard TS lib.
// This declaration silences IDE errors; the real Deno object is injected at runtime.
declare const Deno: {
  env: { get(key: string): string | undefined };
};

// ---------------------------------------------------------------------------
// Rate-limit error
// ---------------------------------------------------------------------------

export class RateLimitError extends Error {
  readonly retryAfterSeconds: number;
  constructor(provider: string, retryAfter = 60) {
    super(`${provider} rate limit (429) — retry after ${retryAfter}s`);
    this.name = "RateLimitError";
    this.retryAfterSeconds = retryAfter;
  }
}

// ---------------------------------------------------------------------------
// Per-call override type
// ---------------------------------------------------------------------------

export interface CallOptions {
  provider?: string;
  model?: string;
}

// ---------------------------------------------------------------------------
// Preset routing table — use these in edge functions instead of hard-coding
// ---------------------------------------------------------------------------

export const PROVIDERS = {
  /** Groq llama-3.2-3b — tagging, titles, themes, cover queries (~$0.06/M) */
  FAST:         { provider: "groq",   model: "llama-3.2-3b-preview"    } as CallOptions,
  /** Groq llama-3.1-8b — chat, search answer, reflections (~$0.05/$0.08) */
  CHAT:         { provider: "groq",   model: "llama-3.1-8b-instant"    } as CallOptions,
  /** OpenAI gpt-4o-mini — memoir polish, quality-critical user-facing text */
  QUALITY:      { provider: "openai", model: "gpt-4o-mini"             } as CallOptions,
  /** Gemini 2.5 Flash — clean polish (near-quality, 30% cheaper than QUALITY) */
  POLISH_CLEAN: { provider: "gemini", model: "gemini-2.5-flash"        } as CallOptions,
  /** Gemini 1.5 Flash — weekly/story batch cron jobs (background, ~$0.075/$0.30) */
  BACKGROUND:   { provider: "gemini", model: "gemini-1.5-flash"        } as CallOptions,
} as const;

// ---------------------------------------------------------------------------
// Global env-driven defaults
// ---------------------------------------------------------------------------

const AI_PROVIDER    = (Deno.env.get("AI_PROVIDER")    ?? "openai").toLowerCase();
const AI_MODEL       =  Deno.env.get("AI_MODEL")         ?? "gpt-4o-mini";
const AI_EMBED_MODEL =  Deno.env.get("AI_EMBED_MODEL")  ?? "text-embedding-3-small";
const GROQ_MODEL     =  Deno.env.get("GROQ_MODEL")      ?? "llama-3.1-8b-instant";

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/** Single-turn generation (structured tasks: tagging, polish, prompts, summaries) */
export async function generate(
  prompt: string,
  systemPrompt?: string,
  maxTokens = 2048,
  opts?: CallOptions,
): Promise<string> {
  const provider = (opts?.provider ?? AI_PROVIDER).toLowerCase();
  const model    = opts?.model;
  if (provider === "gemini") return _geminiGenerate(prompt, systemPrompt, maxTokens, model);
  if (provider === "claude") return _claudeGenerate(prompt, systemPrompt, maxTokens, model);
  if (provider === "groq")   return _groqGenerate(prompt, systemPrompt, maxTokens, model);
  return _openaiGenerate(prompt, systemPrompt, maxTokens, model);
}

/** Multi-turn conversation (check-in chat, memory search summary) */
export async function chat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  opts?: CallOptions,
): Promise<string> {
  const provider = (opts?.provider ?? AI_PROVIDER).toLowerCase();
  const model    = opts?.model;
  if (provider === "gemini") return _geminiChat(messages, systemPrompt, maxTokens, model);
  if (provider === "claude") return _claudeGenerate(
    messages.map(m => `${m.role}: ${m.content}`).join("\n"),
    systemPrompt, maxTokens, model,
  );
  if (provider === "groq")   return _groqChat(messages, systemPrompt, maxTokens, model);
  return _openaiChat(messages, systemPrompt, maxTokens, model);
}

/** Streaming multi-turn conversation — yields tokens as they arrive */
export async function* chatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  opts?: CallOptions,
): AsyncGenerator<string> {
  const provider = (opts?.provider ?? AI_PROVIDER).toLowerCase();
  const model    = opts?.model;
  if (provider === "gemini") yield* _geminiChatStream(messages, systemPrompt, maxTokens, model);
  else if (provider === "claude") yield* _claudeChatStream(messages, systemPrompt, maxTokens, model);
  else if (provider === "groq")   yield* _groqChatStream(messages, systemPrompt, maxTokens, model);
  else yield* _openaiChatStream(messages, systemPrompt, maxTokens, model);
}

/** Semantic embedding for vector search (OpenAI / Gemini only — Groq has no embed API) */
export async function embed(text: string, opts?: CallOptions): Promise<number[]> {
  const provider = (opts?.provider ?? AI_PROVIDER).toLowerCase();
  const model    = opts?.model;
  if (provider === "gemini") return _geminiEmbed(text, model);
  return _openaiEmbed(text, model);
}

// ---------------------------------------------------------------------------
// OpenAI
// ---------------------------------------------------------------------------

async function _openaiCall(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number,
  model: string,
): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model, messages, temperature: 0.3, max_tokens: maxTokens }),
  });
  if (res.status === 429) {
    throw new RateLimitError("OpenAI", parseInt(res.headers.get("retry-after") ?? "60"));
  }
  if (!res.ok) throw new Error(`OpenAI error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

async function _openaiGenerate(
  prompt: string,
  systemPrompt?: string,
  maxTokens = 1024,
  model?: string,
): Promise<string> {
  const messages: Array<{ role: string; content: string }> = [];
  if (systemPrompt) messages.push({ role: "system", content: systemPrompt });
  messages.push({ role: "user", content: prompt });
  return _openaiCall(messages, maxTokens, model ?? AI_MODEL);
}

async function _openaiChat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
): Promise<string> {
  const full: Array<{ role: string; content: string }> = [];
  if (systemPrompt) full.push({ role: "system", content: systemPrompt });
  for (const m of messages) {
    full.push({ role: m.role === "assistant" ? "assistant" : "user", content: m.content });
  }
  return _openaiCall(full, maxTokens, model ?? AI_MODEL);
}

async function _openaiEmbed(text: string, model?: string): Promise<number[]> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const res = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model: model ?? AI_EMBED_MODEL, input: text }),
  });
  if (res.status === 429) throw new RateLimitError("OpenAI", parseInt(res.headers.get("retry-after") ?? "60"));
  if (!res.ok) throw new Error(`OpenAI embed error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const values = data.data?.[0]?.embedding as number[] | undefined;
  if (!values?.length) throw new Error("OpenAI embed: empty response");
  return values;
}

// ---------------------------------------------------------------------------
// Groq (OpenAI-compatible API — text generation only, no embeddings)
// ---------------------------------------------------------------------------

async function _groqCall(
  messages: Array<{ role: string; content: string }>,
  maxTokens: number,
  model: string,
): Promise<string> {
  const apiKey = Deno.env.get("GROQ_API_KEY") ?? "";
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model, messages, temperature: 0.3, max_tokens: maxTokens }),
  });
  if (res.status === 429) {
    throw new RateLimitError("Groq", parseInt(res.headers.get("retry-after") ?? "60"));
  }
  if (!res.ok) throw new Error(`Groq error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

async function _groqGenerate(
  prompt: string,
  systemPrompt?: string,
  maxTokens = 1024,
  model?: string,
): Promise<string> {
  const messages: Array<{ role: string; content: string }> = [];
  if (systemPrompt) messages.push({ role: "system", content: systemPrompt });
  messages.push({ role: "user", content: prompt });
  return _groqCall(messages, maxTokens, model ?? GROQ_MODEL);
}

async function _groqChat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
): Promise<string> {
  const full: Array<{ role: string; content: string }> = [];
  if (systemPrompt) full.push({ role: "system", content: systemPrompt });
  for (const m of messages) {
    full.push({ role: m.role === "assistant" ? "assistant" : "user", content: m.content });
  }
  return _groqCall(full, maxTokens, model ?? GROQ_MODEL);
}

// ---------------------------------------------------------------------------
// Gemini
// ---------------------------------------------------------------------------

async function _geminiGenerate(
  prompt: string,
  systemPrompt?: string,
  maxTokens = 1024,
  model?: string,
): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const m = model ?? AI_MODEL;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${apiKey}`;
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
  if (res.status === 429) throw new RateLimitError("Gemini", parseInt(res.headers.get("retry-after") ?? "60"));
  if (!res.ok) throw new Error(`Gemini error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

async function _geminiChat(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const m = model ?? AI_MODEL;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:generateContent?key=${apiKey}`;
  const contents = messages.map(msg => ({
    role: msg.role === "assistant" ? "model" : "user",
    parts: [{ text: msg.content }],
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
  if (res.status === 429) throw new RateLimitError("Gemini", parseInt(res.headers.get("retry-after") ?? "60"));
  if (!res.ok) throw new Error(`Gemini error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
}

async function _geminiEmbed(text: string, model?: string): Promise<number[]> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const embedModel = model ?? AI_EMBED_MODEL ?? "text-embedding-004";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${embedModel}:embedContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: `models/${embedModel}`,
      content: { parts: [{ text }] },
    }),
  });
  if (res.status === 429) throw new RateLimitError("Gemini", parseInt(res.headers.get("retry-after") ?? "60"));
  if (!res.ok) throw new Error(`Gemini embed error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const values = data.embedding?.values as number[] | undefined;
  if (!values?.length) throw new Error("Gemini embed: empty response");
  return values;
}

// ---------------------------------------------------------------------------
// Claude
// ---------------------------------------------------------------------------

async function _claudeGenerate(
  prompt: string,
  systemPrompt?: string,
  maxTokens = 1024,
  model?: string,
): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: model ?? AI_MODEL,
      max_tokens: maxTokens,
      ...(systemPrompt ? { system: systemPrompt } : {}),
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (res.status === 429) throw new RateLimitError("Claude", parseInt(res.headers.get("retry-after") ?? "60"));
  if (!res.ok) throw new Error(`Claude error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.content?.[0]?.text ?? "";
}

// ---------------------------------------------------------------------------
// Streaming implementations
// ---------------------------------------------------------------------------

async function* _openaiChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
): AsyncGenerator<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const full: Array<{ role: string; content: string }> = [];
  if (systemPrompt) full.push({ role: "system", content: systemPrompt });
  for (const m of messages) full.push({ role: m.role === "assistant" ? "assistant" : "user", content: m.content });

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
    body: JSON.stringify({ model: model ?? AI_MODEL, messages: full, temperature: 0.3, max_tokens: maxTokens, stream: true }),
  });
  if (!res.ok) throw new Error(`OpenAI error ${res.status}: ${await res.text()}`);
  yield* _readSseStream(res.body!, (parsed) => {
    type Choice = { delta?: { content?: string } };
    return (parsed.choices as Choice[] | undefined)?.[0]?.delta?.content;
  });
}

async function* _groqChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
): AsyncGenerator<string> {
  const apiKey = Deno.env.get("GROQ_API_KEY") ?? "";
  const full: Array<{ role: string; content: string }> = [];
  if (systemPrompt) full.push({ role: "system", content: systemPrompt });
  for (const m of messages) full.push({ role: m.role === "assistant" ? "assistant" : "user", content: m.content });

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
    body: JSON.stringify({ model: model ?? GROQ_MODEL, messages: full, temperature: 0.3, max_tokens: maxTokens, stream: true }),
  });
  if (!res.ok) throw new Error(`Groq error ${res.status}: ${await res.text()}`);
  yield* _readSseStream(res.body!, (parsed) => {
    type Choice = { delta?: { content?: string } };
    return (parsed.choices as Choice[] | undefined)?.[0]?.delta?.content;
  });
}

async function* _geminiChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
): AsyncGenerator<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const m = model ?? AI_MODEL;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${m}:streamGenerateContent?key=${apiKey}&alt=sse`;
  const contents = messages.map(msg => ({
    role: msg.role === "assistant" ? "model" : "user",
    parts: [{ text: msg.content }],
  }));
  const body: Record<string, unknown> = { contents, generationConfig: { maxOutputTokens: maxTokens } };
  if (systemPrompt) body.system_instruction = { parts: [{ text: systemPrompt }] };

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Gemini error ${res.status}: ${await res.text()}`);
  yield* _readSseStream(res.body!, (parsed) => {
    type Part = { text?: string };
    type Candidate = { content?: { parts?: Part[] } };
    return (parsed.candidates as Candidate[] | undefined)?.[0]?.content?.parts?.[0]?.text;
  });
}

async function* _claudeChatStream(
  messages: Array<{ role: string; content: string }>,
  systemPrompt?: string,
  maxTokens = 200,
  model?: string,
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
      model: model ?? AI_MODEL,
      max_tokens: maxTokens,
      stream: true,
      ...(systemPrompt ? { system: systemPrompt } : {}),
      messages: messages.map(m => ({ role: m.role === "assistant" ? "assistant" : "user", content: m.content })),
    }),
  });
  if (!res.ok) throw new Error(`Claude error ${res.status}: ${await res.text()}`);
  yield* _readSseStream(res.body!, (parsed) => {
    type Delta = { type?: string; text?: string };
    const delta = parsed.delta as Delta | undefined;
    if (parsed.type === "content_block_delta" && delta?.type === "text_delta") {
      return delta.text;
    }
    return undefined;
  });
}

/** Shared SSE reader — provider-agnostic line-by-line stream parser */
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
// Whisper transcription
// Prefers Groq (3× cheaper, same accuracy) when GROQ_API_KEY is set.
// Falls back to OpenAI whisper-1 otherwise.
// ---------------------------------------------------------------------------

export async function whisperTranscribe(
  audioData: Uint8Array,
  filename: string,
): Promise<string> {
  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (groqKey) return _groqWhisperTranscribe(audioData, filename, groqKey);
  return _openaiWhisperTranscribe(audioData, filename);
}

async function _groqWhisperTranscribe(
  audioData: Uint8Array,
  filename: string,
  apiKey: string,
): Promise<string> {
  const formData = new FormData();
  formData.append("file", new Blob([audioData as Uint8Array<ArrayBuffer>]), filename);
  formData.append("model", "whisper-large-v3-turbo"); // $0.00185/min vs OpenAI $0.006/min
  const res = await fetch("https://api.groq.com/openai/v1/audio/transcriptions", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: formData,
  });
  if (!res.ok) throw new Error(`Groq Whisper error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data.text ?? "";
}

async function _openaiWhisperTranscribe(
  audioData: Uint8Array,
  filename: string,
): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const formData = new FormData();
  formData.append("file", new Blob([audioData as Uint8Array<ArrayBuffer>]), filename);
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
