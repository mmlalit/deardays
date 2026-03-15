-- Migration 018: Server-side AI credit enforcement
--
-- Previously, AI credits were tracked only in Hive (client-side), making them
-- trivially bypassable by clearing app data. This migration adds server-side
-- tracking so the Edge Functions can enforce limits independently.

-- AI usage tracking table (one row per user per month)
CREATE TABLE IF NOT EXISTS ai_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  month TEXT NOT NULL,  -- format: '2026-03'
  polish_used INTEGER DEFAULT 0 NOT NULL,
  summary_used INTEGER DEFAULT 0 NOT NULL,
  chat_used INTEGER DEFAULT 0 NOT NULL,
  themes_used INTEGER DEFAULT 0 NOT NULL,
  transcription_used INTEGER DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  UNIQUE(user_id, month)
);

-- RLS: users can only read/write their own usage
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own usage"
  ON ai_usage FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own usage"
  ON ai_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own usage"
  ON ai_usage FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_ai_usage_user_month
  ON ai_usage(user_id, month);

-- Function to check and consume an AI credit.
-- Returns true if the operation was allowed, false if limit exceeded.
-- Called by Edge Functions before processing AI requests.
CREATE OR REPLACE FUNCTION check_and_consume_credit(
  p_user_id UUID,
  p_operation TEXT,  -- 'polish', 'summary', 'chat', 'themes', 'transcription'
  p_tier TEXT DEFAULT 'free'  -- 'free', 'premium', 'ultra'
) RETURNS BOOLEAN AS $$
DECLARE
  v_month TEXT;
  v_current INTEGER;
  v_limit INTEGER;
  v_column TEXT;
BEGIN
  v_month := to_char(now(), 'YYYY-MM');
  v_column := p_operation || '_used';

  -- Determine limit based on tier
  v_limit := CASE
    WHEN p_tier = 'ultra' THEN -1  -- unlimited
    WHEN p_tier = 'premium' THEN
      CASE p_operation
        WHEN 'polish' THEN 100
        WHEN 'summary' THEN -1
        WHEN 'chat' THEN -1
        WHEN 'themes' THEN -1
        WHEN 'transcription' THEN 50
        ELSE 0
      END
    ELSE  -- free
      CASE p_operation
        WHEN 'polish' THEN 5
        WHEN 'summary' THEN 3
        WHEN 'chat' THEN 10
        WHEN 'themes' THEN 5
        WHEN 'transcription' THEN 10
        ELSE 0
      END
  END;

  -- Unlimited: always allow
  IF v_limit = -1 THEN
    -- Still track usage for analytics
    INSERT INTO ai_usage (user_id, month)
    VALUES (p_user_id, v_month)
    ON CONFLICT (user_id, month) DO NOTHING;

    EXECUTE format('UPDATE ai_usage SET %I = %I + 1, updated_at = now() WHERE user_id = $1 AND month = $2', v_column, v_column)
    USING p_user_id, v_month;

    RETURN true;
  END IF;

  -- Ensure row exists for this month
  INSERT INTO ai_usage (user_id, month)
  VALUES (p_user_id, v_month)
  ON CONFLICT (user_id, month) DO NOTHING;

  -- Check current usage
  EXECUTE format('SELECT %I FROM ai_usage WHERE user_id = $1 AND month = $2', v_column)
  INTO v_current
  USING p_user_id, v_month;

  IF v_current >= v_limit THEN
    RETURN false;  -- Limit exceeded
  END IF;

  -- Consume the credit
  EXECUTE format('UPDATE ai_usage SET %I = %I + 1, updated_at = now() WHERE user_id = $1 AND month = $2', v_column, v_column)
  USING p_user_id, v_month;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current usage (called by the client to sync local state)
CREATE OR REPLACE FUNCTION get_ai_usage(p_user_id UUID)
RETURNS TABLE(
  operation TEXT,
  used INTEGER,
  tier_limit INTEGER
) AS $$
DECLARE
  v_month TEXT;
  v_tier TEXT;
  v_row ai_usage%ROWTYPE;
BEGIN
  v_month := to_char(now(), 'YYYY-MM');

  -- Derive tier from is_subscribed boolean
  SELECT CASE WHEN COALESCE(is_subscribed, false) THEN 'premium' ELSE 'free' END
  INTO v_tier
  FROM profiles WHERE id = p_user_id;

  -- Default to free if profile not found
  IF v_tier IS NULL THEN
    v_tier := 'free';
  END IF;

  -- Get or create usage row
  INSERT INTO ai_usage (user_id, month)
  VALUES (p_user_id, v_month)
  ON CONFLICT (user_id, month) DO NOTHING;

  SELECT * INTO v_row FROM ai_usage WHERE user_id = p_user_id AND month = v_month;

  -- Return usage for each operation
  RETURN QUERY
  SELECT 'polish'::TEXT, v_row.polish_used,
    CASE WHEN v_tier = 'ultra' THEN -1 WHEN v_tier = 'premium' THEN 100 ELSE 5 END;
  RETURN QUERY
  SELECT 'summary'::TEXT, v_row.summary_used,
    CASE WHEN v_tier IN ('ultra','premium') THEN -1 ELSE 3 END;
  RETURN QUERY
  SELECT 'chat'::TEXT, v_row.chat_used,
    CASE WHEN v_tier IN ('ultra','premium') THEN -1 ELSE 10 END;
  RETURN QUERY
  SELECT 'themes'::TEXT, v_row.themes_used,
    CASE WHEN v_tier IN ('ultra','premium') THEN -1 ELSE 5 END;
  RETURN QUERY
  SELECT 'transcription'::TEXT, v_row.transcription_used,
    CASE WHEN v_tier = 'ultra' THEN -1 WHEN v_tier = 'premium' THEN 50 ELSE 10 END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
