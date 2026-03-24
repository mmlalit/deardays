-- ============================================================
-- Migration 047: Monthly and yearly summary cron jobs
--
-- Monthly summary (≤ 100 words):
--   Runs 1st of each month at 07:00 UTC.
--   Reads weekly summaries from the previous month,
--   invokes ai-monthly-summary edge function.
--
-- Yearly summary (≤ 200 words):
--   Runs 1st January at 08:00 UTC.
--   Reads monthly summaries from the previous year,
--   invokes ai-yearly-summary edge function.
--
-- Both use a queue table (summary_queue) so the pg_cron
-- function stays within the 30s execution limit.
-- ============================================================

-- ============================================================
-- Queue table for monthly / yearly summary jobs
-- ============================================================

CREATE TABLE IF NOT EXISTS public.summary_queue (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  period_type  TEXT        NOT NULL CHECK (period_type IN ('monthly', 'yearly')),
  period_start DATE        NOT NULL,
  status       TEXT        NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'processing', 'done', 'failed')),
  retry_count  INT         NOT NULL DEFAULT 0,
  error_detail TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT summary_queue_unique UNIQUE (user_id, period_type, period_start)
);

ALTER TABLE public.summary_queue ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS summary_queue_status_idx
  ON public.summary_queue (status, created_at);

DROP TRIGGER IF EXISTS summary_queue_updated_at ON public.summary_queue;
CREATE TRIGGER summary_queue_updated_at
  BEFORE UPDATE ON public.summary_queue
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- Monthly enqueue function
-- Runs 1st of each month at 07:00 UTC.
-- Enqueues one row per user who has at least 2 weekly summaries
-- from the previous month.
-- ============================================================

CREATE OR REPLACE FUNCTION public.enqueue_monthly_summary()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_month_start DATE;
  v_job_id      UUID;
BEGIN
  -- First day of the previous month
  v_month_start := date_trunc('month', CURRENT_DATE - INTERVAL '1 day')::DATE;

  INSERT INTO public.job_run_log (job_name, started_at, status)
  VALUES ('monthly_summary_gen', NOW(), 'running')
  RETURNING id INTO v_job_id;

  -- Enqueue one row per user who has ≥ 2 weekly summaries in that month
  INSERT INTO public.summary_queue (user_id, period_type, period_start)
  SELECT ss.user_id, 'monthly', v_month_start
  FROM public.story_summaries ss
  WHERE ss.period_type  = 'weekly'
    AND ss.period_start >= v_month_start
    AND ss.period_start <  v_month_start + INTERVAL '1 month'
  GROUP BY ss.user_id
  HAVING count(*) >= 2
  ON CONFLICT (user_id, period_type, period_start) DO NOTHING;

  UPDATE public.job_run_log
  SET status = 'completed', finished_at = NOW()
  WHERE id = v_job_id;

EXCEPTION WHEN OTHERS THEN
  UPDATE public.job_run_log
  SET status = 'failed',
      finished_at = NOW(),
      error_details = jsonb_build_object('error', SQLERRM)
  WHERE id = v_job_id;
  RAISE;
END;
$$;

-- ============================================================
-- Yearly enqueue function
-- Runs 1st January at 08:00 UTC.
-- Enqueues one row per user who has at least 3 monthly summaries
-- from the previous year.
-- ============================================================

CREATE OR REPLACE FUNCTION public.enqueue_yearly_summary()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_year_start DATE;
  v_job_id     UUID;
BEGIN
  -- First day of the previous year
  v_year_start := make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1, 1, 1);

  INSERT INTO public.job_run_log (job_name, started_at, status)
  VALUES ('yearly_summary_gen', NOW(), 'running')
  RETURNING id INTO v_job_id;

  -- Enqueue one row per user who has ≥ 3 monthly summaries in that year
  INSERT INTO public.summary_queue (user_id, period_type, period_start)
  SELECT ss.user_id, 'yearly', v_year_start
  FROM public.story_summaries ss
  WHERE ss.period_type  = 'monthly'
    AND ss.period_start >= v_year_start
    AND ss.period_start <  v_year_start + INTERVAL '1 year'
  GROUP BY ss.user_id
  HAVING count(*) >= 3
  ON CONFLICT (user_id, period_type, period_start) DO NOTHING;

  UPDATE public.job_run_log
  SET status = 'completed', finished_at = NOW()
  WHERE id = v_job_id;

EXCEPTION WHEN OTHERS THEN
  UPDATE public.job_run_log
  SET status = 'failed',
      finished_at = NOW(),
      error_details = jsonb_build_object('error', SQLERRM)
  WHERE id = v_job_id;
  RAISE;
END;
$$;

-- ============================================================
-- Schedule the cron jobs
-- ============================================================

-- 1st of each month at 07:00 UTC
SELECT cron.schedule(
  'monthly_summary_gen',
  '0 7 1 * *',
  'SELECT public.enqueue_monthly_summary()'
);

-- 1st January at 08:00 UTC
SELECT cron.schedule(
  'yearly_summary_gen',
  '0 8 1 1 *',
  'SELECT public.enqueue_yearly_summary()'
);
