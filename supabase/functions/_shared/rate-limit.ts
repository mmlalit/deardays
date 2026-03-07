import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Per-user daily rate limits
// ---------------------------------------------------------------------------

const RATE_LIMITS: Record<string, { free: number; paid: number }> = {
  chat:       { free: 100, paid: 500 },
  polish:     { free: 10,  paid: 50 },
  summarize:  { free: 5,   paid: 20 },
  themes:     { free: 5,   paid: 20 },
  transcribe: { free: 0,   paid: 30 },
  prompt:     { free: 10,  paid: 50 },
};

// Estimated cost per call in USD (used for global cap tracking)
const COST_PER_CALL: Record<string, { free: number; paid: number }> = {
  chat:       { free: 0.0001, paid: 0.0001 },   // Gemini Flash
  polish:     { free: 0.0001, paid: 0.003  },   // Gemini free / Claude paid
  summarize:  { free: 0.0001, paid: 0.0001 },   // Gemini Flash
  themes:     { free: 0.0001, paid: 0.0001 },   // Gemini Flash
  transcribe: { free: 0,      paid: 0.001  },   // Whisper
  prompt:     { free: 0.0001, paid: 0.0001 },   // Gemini Flash
};

// Global daily cost cap (default $10/day, override with DAILY_COST_CAP_USD env var)
function getDailyCostCap(): number {
  const cap = Deno.env.get("DAILY_COST_CAP_USD");
  return cap ? parseFloat(cap) : 10.0;
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
 */
export async function checkRateLimit(
  userId: string,
  functionName: string,
  isPremium: boolean,
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

  // 1. Check global daily cost cap
  const { data: costData } = await supabase.rpc("get_daily_ai_cost");
  const dailyCost = typeof costData === "number" ? costData : 0;

  if (dailyCost >= getDailyCostCap()) {
    return {
      allowed: false,
      reason: "Daily AI budget reached. Please try again tomorrow.",
      currentCount: 0,
      limit: dailyLimit,
    };
  }

  // 2. Check per-user daily limit
  const today = new Date().toISOString().split("T")[0];

  const { data: usage } = await supabase
    .from("ai_usage")
    .select("call_count")
    .eq("user_id", userId)
    .eq("function_name", functionName)
    .eq("call_date", today)
    .single();

  const currentCount = usage?.call_count ?? 0;

  if (currentCount >= dailyLimit) {
    return {
      allowed: false,
      reason: `Daily limit reached (${dailyLimit}/${functionName}). Resets at midnight UTC.`,
      currentCount,
      limit: dailyLimit,
    };
  }

  // 3. Increment usage counter
  const costPerCall = isPremium
    ? COST_PER_CALL[functionName].paid
    : COST_PER_CALL[functionName].free;

  await supabase.rpc("increment_ai_usage", {
    p_user_id: userId,
    p_function_name: functionName,
    p_cost: costPerCall,
  });

  return {
    allowed: true,
    currentCount: currentCount + 1,
    limit: dailyLimit,
  };
}
