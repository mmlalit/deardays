-- Migration 045: Add input validation to check_and_consume_credit() to
-- prevent unknown operation names reaching the EXECUTE format() call.
--
-- Previously, any p_operation value passed through to EXECUTE format('%I', ...)
-- which would try to SELECT/UPDATE a column that doesn't exist, causing a
-- runtime ERROR rather than a clean application-level rejection.
-- ============================================================================

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
  -- Validate p_operation before any dynamic SQL to avoid unknown-column errors.
  IF p_operation NOT IN ('polish', 'summary', 'chat', 'themes', 'transcription') THEN
    RAISE EXCEPTION 'check_and_consume_credit: invalid operation ''%''. '
      'Allowed values: polish, summary, chat, themes, transcription', p_operation;
  END IF;

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

COMMENT ON FUNCTION check_and_consume_credit(UUID, TEXT, TEXT)
  IS 'Checks and consumes an AI credit. Validates p_operation against the '
     'allowed set before any dynamic SQL to prevent runtime column errors.';
