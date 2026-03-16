import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Per-user daily rate limits
// ---------------------------------------------------------------------------

const RATE_LIMITS: Record<string, { free: number; paid: number }> = {
  chat:       { free: 100, paid: 500 },
  polish:     { free: 10,  paid: 20 },
  summarize:  { free: 5,   paid: 20 },
  themes:     { free: 5,   paid: 20 },
  transcribe: { free: 0,   paid: 30 },
  prompt:     { free: 10,  paid: 50 },
};

// Estimated cost per call in USD (used for global cap tracking).
// Based on actual token pricing: Gemini Flash ($0.0375/M in + $0.15/M out),
// Claude Sonnet ($3/M in + $15/M out), Whisper ($0.006/min avg).
const COST_PER_CALL: Record<string, { free: number; paid: number }> = {
  chat:       { free: 0.0005, paid: 0.0005 },   // Gemini Flash (~600 tokens avg)
  polish:     { free: 0.0005, paid: 0.005  },   // Gemini free / Claude paid (~1500 tokens)
  summarize:  { free: 0.0008, paid: 0.0008 },   // Gemini Flash (~800 tokens, multi-entry)
  themes:     { free: 0.0008, paid: 0.0008 },   // Gemini Flash (~800 tokens, multi-entry)
  transcribe: { free: 0,      paid: 0.006  },   // Whisper ($0.006/min avg)
  prompt:     { free: 0.0003, paid: 0.0003 },   // Gemini Flash (~300 tokens, short)
};

// Per-user daily token budgets (approximate input tokens).
// Prevents a small number of very long requests from consuming disproportionate cost.
const TOKEN_LIMITS: Record<string, { free: number; paid: number }> = {
  chat:       { free: 50_000,  paid: 200_000 },
  polish:     { free: 20_000,  paid: 80_000  },
  summarize:  { free: 15_000,  paid: 60_000  },
  themes:     { free: 15_000,  paid: 60_000  },
  transcribe: { free: 0,       paid: 100_000 },
  prompt:     { free: 5_000,   paid: 20_000  },
};

// Maximum input characters per single request (prevents abuse with huge payloads).
const MAX_INPUT_CHARS: Record<string, number> = {
  chat:       8_000,   // ~2000 tokens per message
  polish:     20_000,  // ~5000 tokens
  summarize:  40_000,  // multi-entry, ~10000 tokens
  themes:     40_000,
  transcribe: 0,       // binary, not text
  prompt:     0,       // no user text input
};

// Global daily cost cap (default $10/day, override with DAILY_COST_CAP_USD env var)
function getDailyCostCap(): number {
  const cap = Deno.env.get("DAILY_COST_CAP_USD");
  return cap ? parseFloat(cap) : 10.0;
}

/** Rough token estimate: ~4 chars per token for English text. */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

interface RateLimitResult {
  allowed: boolean;
  reason?: string;
  currentCount: number;
  limit: number;
}

/**
 * Checks rate limits and tracks usage. Returns whether the request is allowed.
 * Uses the service role client to bypass RLS.
 *
 * @param inputText Optional user-supplied text for this request. Used to:
 *   (a) reject single requests that exceed MAX_INPUT_CHARS, and
 *   (b) estimate token cost so the per-user daily token budget is enforced.
 */
export async function checkRateLimit(
  userId: string,
  functionName: string,
  isPremium: boolean,
  inputText?: string,
): Promise<RateLimitResult> {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const limits = RATE_LIMITS[functionName];
  if (!limits) {
    return { allowed: false, reason: "Unknown function", currentCount: 0, limit: 0 };
  }

  const dailyLimit = isPremium ? limits.paid : limits.free;

  // 0. Reject oversized single requests
  const maxChars = MAX_INPUT_CHARS[functionName] ?? 0;
  if (inputText && maxChars > 0 && inputText.length > maxChars) {
    return {
      allowed: false,
      reason: `Input too long (${inputText.length} chars, max ${maxChars}). Please shorten your text.`,
      currentCount: 0,
      limit: dailyLimit,
    };
  }

  // 1 + 2. Fetch global cost cap and per-user usage in parallel
  const today = new Date().toISOString().split("T")[0];
  const [{ data: costData }, { data: usage }] = await Promise.all([
    supabase.rpc("get_daily_ai_cost"),
    supabase
      .from("ai_usage")
      .select("call_count, estimated_tokens")
      .eq("user_id", userId)
      .eq("function_name", functionName)
      .eq("call_date", today)
      .single(),
  ]);

  const dailyCost = typeof costData === "number" ? costData : 0;

  if (dailyCost >= getDailyCostCap()) {
    return {
      allowed: false,
      reason: "Daily AI budget reached. Please try again tomorrow.",
      currentCount: 0,
      limit: dailyLimit,
    };
  }

  const currentCount = usage?.call_count ?? 0;

  if (currentCount >= dailyLimit) {
    return {
      allowed: false,
      reason: `Daily limit reached (${dailyLimit}/${functionName}). Resets at midnight UTC.`,
      currentCount,
      limit: dailyLimit,
    };
  }

  // 3. Check per-user daily token budget
  const tokenLimits = TOKEN_LIMITS[functionName];
  if (tokenLimits && inputText) {
    const currentTokens = (usage as Record<string, unknown>)?.estimated_tokens as number ?? 0;
    const requestTokens = estimateTokens(inputText);
    const tokenBudget = isPremium ? tokenLimits.paid : tokenLimits.free;

    if (currentTokens + requestTokens > tokenBudget) {
      return {
        allowed: false,
        reason: `Daily token budget reached for ${functionName}. Try shorter text or wait until tomorrow.`,
        currentCount,
        limit: dailyLimit,
      };
    }
  }

  // 4. Increment usage counter with cost and token estimate
  const costPerCall = isPremium
    ? COST_PER_CALL[functionName].paid
    : COST_PER_CALL[functionName].free;

  const tokenEstimate = inputText ? estimateTokens(inputText) : 0;

  await supabase.rpc("increment_ai_usage", {
    p_user_id: userId,
    p_function_name: functionName,
    p_cost: costPerCall,
    p_tokens: tokenEstimate,
  });

  return {
    allowed: true,
    currentCount: currentCount + 1,
    limit: dailyLimit,
  };
}
