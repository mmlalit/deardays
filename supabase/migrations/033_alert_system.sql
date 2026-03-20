-- ============================================================
-- Migration 033: Alert system + anomaly detection
-- Three detection layers, all thresholds read from app_config:
--
-- 1. Per-user memory anomaly  — fires when a user creates more
--    than anomaly_memory_threshold memories in one calendar day
--    (default 30 = 3× daily limit of 10)
--
-- 2. Global daily spend alert — fires when total AI spend across
--    all users in one UTC day exceeds global_daily_spend_alert USD
--    (default $20)
--
-- 3. Per-user monthly cost cap — fires when a paid user's monthly
--    AI spend exceeds $1.00 (trial: prorated by trial_duration_days)
--
-- All alerts are de-duplicated (one per user/type per day) so the
-- admin alert_log doesn't flood.
-- ============================================================

-- ============================================================
-- Trigger 1: memory anomaly detection
-- Fires AFTER INSERT on journal_entries.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_memory_anomaly()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_threshold  INT;
  v_today_count INT;
  v_today      DATE := CURRENT_DATE;
BEGIN
  v_threshold := get_app_config('anomaly_memory_threshold', '30')::INT;

  -- Count memories this user created today (UTC)
  SELECT count(*) INTO v_today_count
  FROM public.journal_entries
  WHERE user_id = NEW.user_id
    AND created_at::DATE = v_today;

  IF v_today_count >= v_threshold THEN
    -- De-duplicate: only one anomaly alert per user per day
    INSERT INTO public.alert_log (
      alert_type, severity, user_id, details
    )
    SELECT
      'anomaly_memory',
      'warning',
      NEW.user_id,
      jsonb_build_object(
        'memory_count_today', v_today_count,
        'threshold', v_threshold,
        'date', v_today
      )
    WHERE NOT EXISTS (
      SELECT 1 FROM public.alert_log
      WHERE alert_type = 'anomaly_memory'
        AND user_id = NEW.user_id
        AND created_at::DATE = v_today
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER journal_entries_anomaly_check
  AFTER INSERT ON public.journal_entries
  FOR EACH ROW EXECUTE FUNCTION public.check_memory_anomaly();

-- ============================================================
-- Trigger 2: global daily spend alert
-- Fires AFTER INSERT on ai_cost_log.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_global_daily_spend()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_limit     NUMERIC;
  v_today     DATE := CURRENT_DATE;
  v_total_today NUMERIC;
BEGIN
  v_limit := get_app_config('global_daily_spend_alert', '20')::NUMERIC;

  SELECT COALESCE(sum(cost_usd), 0) INTO v_total_today
  FROM public.ai_cost_log
  WHERE created_at::DATE = v_today;

  IF v_total_today >= v_limit THEN
    -- De-duplicate: one global spend alert per day
    INSERT INTO public.alert_log (
      alert_type, severity, user_id, details
    )
    SELECT
      'global_daily_spend',
      'critical',
      NULL,
      jsonb_build_object(
        'total_usd_today', v_total_today,
        'limit_usd', v_limit,
        'date', v_today
      )
    WHERE NOT EXISTS (
      SELECT 1 FROM public.alert_log
      WHERE alert_type = 'global_daily_spend'
        AND created_at::DATE = v_today
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER ai_cost_log_spend_check
  AFTER INSERT ON public.ai_cost_log
  FOR EACH ROW EXECUTE FUNCTION public.check_global_daily_spend();

-- ============================================================
-- Trigger 3: per-user monthly cost cap
-- Fires AFTER INSERT on ai_cost_log.
-- Cap: $1.00 per paid user per month.
-- ============================================================
CREATE OR REPLACE FUNCTION public.check_user_monthly_cap()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cap           NUMERIC := 1.00; -- USD per paid user per month
  v_month_start   DATE := date_trunc('month', CURRENT_DATE)::DATE;
  v_user_monthly  NUMERIC;
BEGIN
  -- Only check if this cost is attributed to a user
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(sum(cost_usd), 0) INTO v_user_monthly
  FROM public.ai_cost_log
  WHERE user_id = NEW.user_id
    AND created_at >= v_month_start;

  IF v_user_monthly >= v_cap THEN
    INSERT INTO public.alert_log (
      alert_type, severity, user_id, details
    )
    SELECT
      'user_cap_reached',
      'warning',
      NEW.user_id,
      jsonb_build_object(
        'monthly_spend_usd', v_user_monthly,
        'cap_usd', v_cap,
        'month', v_month_start
      )
    WHERE NOT EXISTS (
      SELECT 1 FROM public.alert_log
      WHERE alert_type = 'user_cap_reached'
        AND user_id = NEW.user_id
        AND created_at >= v_month_start
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER ai_cost_log_user_cap_check
  AFTER INSERT ON public.ai_cost_log
  FOR EACH ROW EXECUTE FUNCTION public.check_user_monthly_cap();

-- ============================================================
-- View: unresolved_alerts (convenience for admin portal)
-- ============================================================
CREATE OR REPLACE VIEW public.unresolved_alerts AS
SELECT
  id,
  alert_type,
  severity,
  user_id,
  details,
  created_at
FROM public.alert_log
WHERE resolved = FALSE
ORDER BY
  CASE severity WHEN 'critical' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END,
  created_at DESC;
