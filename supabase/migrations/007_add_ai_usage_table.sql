-- Tracks AI API usage per user per day for rate limiting and cost monitoring.
CREATE TABLE IF NOT EXISTS ai_usage (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  function_name TEXT NOT NULL,         -- 'chat', 'polish', 'summarize', etc.
  call_date DATE NOT NULL DEFAULT CURRENT_DATE,
  call_count INT NOT NULL DEFAULT 1,
  estimated_cost_usd NUMERIC(10, 6) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, function_name, call_date)
);

-- Index for fast lookups by user + date
CREATE INDEX idx_ai_usage_user_date ON ai_usage (user_id, call_date);

-- Index for global daily cost queries
CREATE INDEX idx_ai_usage_date_cost ON ai_usage (call_date, estimated_cost_usd);

-- RLS: users can only see their own usage
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own usage"
  ON ai_usage FOR SELECT
  USING (auth.uid() = user_id);

-- Service role can do everything (Edge Functions use service role)
CREATE POLICY "Service role full access"
  ON ai_usage FOR ALL
  USING (auth.role() = 'service_role');

-- Helper: get total cost for today (used by global cap check)
CREATE OR REPLACE FUNCTION get_daily_ai_cost()
RETURNS NUMERIC AS $$
  SELECT COALESCE(SUM(estimated_cost_usd), 0)
  FROM ai_usage
  WHERE call_date = CURRENT_DATE;
$$ LANGUAGE sql SECURITY DEFINER;

-- Upsert: increment call count and add cost for today
CREATE OR REPLACE FUNCTION increment_ai_usage(
  p_user_id UUID,
  p_function_name TEXT,
  p_cost NUMERIC DEFAULT 0
)
RETURNS VOID AS $$
  INSERT INTO ai_usage (user_id, function_name, call_date, call_count, estimated_cost_usd)
  VALUES (p_user_id, p_function_name, CURRENT_DATE, 1, p_cost)
  ON CONFLICT (user_id, function_name, call_date)
  DO UPDATE SET
    call_count = ai_usage.call_count + 1,
    estimated_cost_usd = ai_usage.estimated_cost_usd + p_cost,
    updated_at = NOW();
$$ LANGUAGE sql SECURITY DEFINER;
