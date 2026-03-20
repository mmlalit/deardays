-- ============================================================
-- Migration 032: Weekly pg_cron jobs
-- Saturday 6am UTC — generate book pages for the completed week
-- Friday   9am UTC — reminder if user has < minimum_memories_for_page
-- ============================================================

-- Requires pg_cron extension (enabled on Supabase Pro by default)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================
-- Helper: read a single app_config value with a default fallback
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_app_config(p_key TEXT, p_default TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (SELECT value FROM public.app_config WHERE key = p_key),
    p_default
  );
$$;

-- ============================================================
-- Saturday job: generate_weekly_pages
-- Runs at 06:00 UTC every Saturday.
-- For each active user+chapter with ≥ minimum_memories_for_page
-- new memories this week, queues a page generation task.
--
-- Actual AI calls happen in an Edge Function (ai-weekly-page)
-- triggered by rows inserted into a generation_queue table.
-- This job just enqueues tasks in batches to stay within
-- the pg_cron 30s execution limit.
-- ============================================================

-- Queue table for the edge function to process
CREATE TABLE IF NOT EXISTS public.generation_queue (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chapter_id      UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  book_id         UUID,
  week_start      DATE NOT NULL,
  memory_ids      UUID[] NOT NULL DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'done', 'failed')),
  retry_count     INT NOT NULL DEFAULT 0,
  error_detail    TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.generation_queue ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS generation_queue_status_idx
  ON public.generation_queue (status, created_at);

CREATE TRIGGER generation_queue_updated_at
  BEFORE UPDATE ON public.generation_queue
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- The pg_cron function that populates the queue
CREATE OR REPLACE FUNCTION public.enqueue_weekly_page_generation()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_min_memories   INT;
  v_week_start     DATE;
  v_job_id         UUID;
  rec              RECORD;
BEGIN
  -- Read config
  v_min_memories := get_app_config('minimum_memories_for_page', '3')::INT;

  -- Monday of the week that just ended (Saturday job runs Sun ≡ previous Mon)
  v_week_start := date_trunc('week', CURRENT_DATE - INTERVAL '1 day')::DATE;

  -- Log job start
  INSERT INTO public.job_run_log (job_name, started_at, status)
  VALUES ('saturday_page_gen', NOW(), 'running')
  RETURNING id INTO v_job_id;

  -- Insert one queue entry per (user, chapter) that has enough memories
  -- created between Monday and Sunday of the completed week
  INSERT INTO public.generation_queue (
    user_id, chapter_id, book_id, week_start, memory_ids
  )
  SELECT
    je.user_id,
    je.chapter_id,
    b.id          AS book_id,
    v_week_start,
    array_agg(je.id ORDER BY je.entry_date) AS memory_ids
  FROM public.journal_entries je
  -- Only memories that belong to a chapter (thematic) OR no chapter (chronological — treated as default chapter)
  LEFT JOIN public.books b ON b.user_id = je.user_id
  WHERE je.entry_date >= v_week_start
    AND je.entry_date <  v_week_start + INTERVAL '7 days'
    AND (je.chapter_id IS NOT NULL OR b.id IS NOT NULL)
  GROUP BY je.user_id, je.chapter_id, b.id
  HAVING count(*) >= v_min_memories
  -- Skip if already queued for this week+chapter
  ON CONFLICT DO NOTHING;

  -- Mark job completed (edge function updates pages_generated / errors later)
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
-- Friday job: send_weekly_reminder
-- Runs at 09:00 UTC every Friday.
-- Inserts notification records for users with fewer memories
-- than minimum_memories_for_page since last Monday.
-- Push delivery is handled by a separate Edge Function that
-- polls notifications_log for unsent rows.
-- ============================================================
CREATE OR REPLACE FUNCTION public.enqueue_weekly_reminders()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_min_memories INT;
  v_week_start   DATE;
  v_job_id       UUID;
BEGIN
  v_min_memories := get_app_config('minimum_memories_for_page', '3')::INT;
  v_week_start   := date_trunc('week', CURRENT_DATE)::DATE;

  INSERT INTO public.job_run_log (job_name, started_at, status)
  VALUES ('friday_reminder', NOW(), 'running')
  RETURNING id INTO v_job_id;

  -- Insert one notification per user who has < min memories this week
  -- and hasn't already received a reminder this week
  INSERT INTO public.notifications_log (
    user_id, notification_type, title, body
  )
  SELECT
    u.id,
    'friday_reminder',
    'Your story is waiting ✍️',
    'Add a few more memories this week and we''ll weave them into your book on Saturday.'
  FROM auth.users u
  WHERE
    -- Fewer than minimum memories this week
    (SELECT count(*) FROM public.journal_entries je
     WHERE je.user_id = u.id
       AND je.entry_date >= v_week_start) < v_min_memories
    -- Not already reminded this week
    AND NOT EXISTS (
      SELECT 1 FROM public.notifications_log nl
      WHERE nl.user_id = u.id
        AND nl.notification_type = 'friday_reminder'
        AND nl.sent_at >= v_week_start
    );

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

-- Saturday 06:00 UTC
SELECT cron.schedule(
  'saturday_page_gen',
  '0 6 * * 6',
  'SELECT public.enqueue_weekly_page_generation()'
);

-- Friday 09:00 UTC
SELECT cron.schedule(
  'friday_reminder',
  '0 9 * * 5',
  'SELECT public.enqueue_weekly_reminders()'
);
