-- ============================================================================
-- DearDays: Migration 014 — Cost Efficiency Enhancements
--
-- 1. Add estimated_tokens column to ai_usage for token-based rate limiting
-- 2. Update increment_ai_usage to accept and track token counts
-- ============================================================================


-- 1. Add estimated_tokens column
ALTER TABLE public.ai_usage
  ADD COLUMN IF NOT EXISTS estimated_tokens INTEGER NOT NULL DEFAULT 0;


-- 2. Update increment_ai_usage to track tokens
CREATE OR REPLACE FUNCTION public.increment_ai_usage(
  p_user_id UUID,
  p_function_name TEXT,
  p_cost NUMERIC DEFAULT 0,
  p_tokens INTEGER DEFAULT 0
)
RETURNS VOID AS $$
  INSERT INTO ai_usage (user_id, function_name, call_date, call_count, estimated_cost_usd, estimated_tokens)
  VALUES (p_user_id, p_function_name, CURRENT_DATE, 1, GREATEST(p_cost, 0), GREATEST(p_tokens, 0))
  ON CONFLICT (user_id, function_name, call_date)
  DO UPDATE SET
    call_count = ai_usage.call_count + 1,
    estimated_cost_usd = ai_usage.estimated_cost_usd + GREATEST(p_cost, 0),
    estimated_tokens = ai_usage.estimated_tokens + GREATEST(p_tokens, 0),
    updated_at = NOW();
$$ LANGUAGE sql SECURITY DEFINER
   SET search_path = public;
