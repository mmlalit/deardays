-- ============================================================
-- Migration 037: Scalable queue drainer
--
-- Adds the missing pieces to make ai-weekly-page scale to 10k users:
--
--  1. Unique constraint on generation_queue so ON CONFLICT DO NOTHING works
--  2. pg_net extension for HTTP calls from SQL
--  3. Every-5-minute pg_cron on Saturdays that calls ai-weekly-page
--     to drain the queue progressively (20 items × 5 concurrent = no thundering herd)
--  4. Hourly auto-retry: reset failed rows (retry_count < 3) back to pending
--  5. Daily cleanup: delete done/failed rows older than 30 days
--
-- Setup required AFTER this migration:
--   In the Supabase dashboard → Settings → Database → app_config, set:
--     edge_function_url  = 'https://<project-ref>.supabase.co/functions/v1'
--     edge_anon_key      = '<your-anon-key>'   (safe to store — anon key is public)
-- ============================================================

-- ── 1. Unique constraint (backs ON CONFLICT DO NOTHING in enqueuer) ──────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'generation_queue_unique_week'
  ) THEN
    ALTER TABLE public.generation_queue
      ADD CONSTRAINT generation_queue_unique_week
      UNIQUE (user_id, chapter_id, week_start);
  END IF;
END;
$$;

-- ── 2. pg_net for HTTP calls from SQL ────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── 3. Helper: invoke ai-weekly-page edge function ───────────────────────────
-- Reads URL and anon key from app_config (set by operator post-deploy).
-- Uses the anon key — edge function is protected by JWT auth internally.
-- Returns the pg_net request id (for debugging), or NULL if not configured.
CREATE OR REPLACE FUNCTION public.invoke_weekly_page_worker(batch_limit INT DEFAULT 20)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_url     TEXT;
  v_key     TEXT;
  v_req_id  BIGINT;
BEGIN
  v_url := get_app_config('edge_function_url', NULL);
  v_key := get_app_config('edge_anon_key', NULL);

  -- Skip silently if not configured (dev / CI environments)
  IF v_url IS NULL OR v_key IS NULL THEN
    RETURN NULL;
  END IF;

  -- Only call if there are pending items — avoids wasted HTTP calls
  IF NOT EXISTS (SELECT 1 FROM public.generation_queue WHERE status = 'pending' LIMIT 1) THEN
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url     := v_url || '/ai-weekly-page',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object('limit', batch_limit)
  ) INTO v_req_id;

  RETURN v_req_id;
END;
$$;

-- ── 4. Saturday queue-drainer: every 5 min, 06:05–22:55 UTC ─────────────────
-- Processes 20 items per call. At 5 concurrent AI calls ~10s each = ~40s/batch.
-- 10,000 users ÷ 20 items/call = 500 calls × 5 min apart = queue drains by ~18:25 UTC.
-- (Realistically most users have 0–1 page/week so it drains much faster.)
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'saturday_drain_queue';
SELECT cron.schedule(
  'saturday_drain_queue',
  '*/5 6-22 * * 6',
  'SELECT public.invoke_weekly_page_worker(20)'
);

-- ── 5. Hourly auto-retry (Saturdays 07:00–22:00) ────────────────────────────
-- Resets transiently-failed items (network glitch, AI timeout) back to pending.
-- Only retries items with retry_count < 3 to avoid infinite loops on hard failures.
CREATE OR REPLACE FUNCTION public.retry_failed_queue_items()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE public.generation_queue
  SET    status     = 'pending',
         updated_at = NOW()
  WHERE  status      = 'failed'
    AND  retry_count < 3
    -- Only retry items from this week (don't resurface stale failures)
    AND  week_start  >= date_trunc('week', CURRENT_DATE - INTERVAL '1 day')::DATE;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'saturday_retry_failed';
SELECT cron.schedule(
  'saturday_retry_failed',
  '0 7-22 * * 6',
  'SELECT public.retry_failed_queue_items()'
);

-- ── 6. Daily cleanup: remove old done/failed rows ────────────────────────────
CREATE OR REPLACE FUNCTION public.cleanup_old_queue_rows()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT;
BEGIN
  DELETE FROM public.generation_queue
  WHERE  status IN ('done', 'failed')
    AND  created_at < NOW() - INTERVAL '30 days';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'daily_queue_cleanup';
SELECT cron.schedule(
  'daily_queue_cleanup',
  '0 3 * * *',
  'SELECT public.cleanup_old_queue_rows()'
);

-- ── 7. app_config: seed placeholder keys (operator must update values) ────────
INSERT INTO public.app_config (key, value, description) VALUES
  ('edge_function_url', '', 'Base URL for Supabase edge functions, e.g. https://<ref>.supabase.co/functions/v1'),
  ('edge_anon_key',     '', 'Supabase anon key used to invoke edge functions from pg_cron')
ON CONFLICT (key) DO NOTHING;

-- ── 8. Index: fast pending queue lookup used by invoke_weekly_page_worker ─────
CREATE INDEX IF NOT EXISTS generation_queue_pending_idx
  ON public.generation_queue (status, created_at)
  WHERE status = 'pending';
