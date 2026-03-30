-- ============================================================================
-- Migration 056: Daily story pages + needs_refresh cascade
--
-- Adds granularity column to pages table (daily/weekly/monthly/yearly).
-- Adds needs_refresh flag for smart regeneration (only dirty pages).
-- Adds date column for daily pages (specific date, not week_start).
-- Adds highlights/mood/people JSONB columns for story metadata.
-- Creates trigger to mark pages needs_refresh on entry mutations.
-- Creates cron functions for daily/weekly/monthly/yearly story generation.
-- ============================================================================

-- 1. Add new columns to pages table
ALTER TABLE public.pages
  ADD COLUMN IF NOT EXISTS granularity TEXT NOT NULL DEFAULT 'weekly'
    CHECK (granularity IN ('daily', 'weekly', 'monthly', 'yearly')),
  ADD COLUMN IF NOT EXISTS needs_refresh BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS page_date DATE,
  ADD COLUMN IF NOT EXISTS highlights JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS mood_summary TEXT,
  ADD COLUMN IF NOT EXISTS people JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS entry_ids JSONB NOT NULL DEFAULT '[]';

-- 2. Make chapter_id nullable (daily pages may not belong to a chapter)
ALTER TABLE public.pages
  ALTER COLUMN chapter_id DROP NOT NULL;

-- 3. Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_pages_granularity
  ON public.pages (user_id, granularity, page_date DESC);

CREATE INDEX IF NOT EXISTS idx_pages_needs_refresh
  ON public.pages (needs_refresh)
  WHERE needs_refresh = true;

CREATE INDEX IF NOT EXISTS idx_pages_daily_lookup
  ON public.pages (user_id, granularity, page_date)
  WHERE granularity = 'daily';

-- 4. Unique constraint for daily pages (one set of pages per user per day)
-- A day can have multiple pages (>250 words splits), so we use page_number.
CREATE UNIQUE INDEX IF NOT EXISTS idx_pages_daily_unique
  ON public.pages (user_id, granularity, page_date, page_number)
  WHERE granularity = 'daily' AND page_date IS NOT NULL;

-- 5. Function to mark daily page as needs_refresh when entries change
CREATE OR REPLACE FUNCTION public.mark_daily_page_dirty()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_entry_date DATE;
  v_user_id UUID;
  v_week_start DATE;
  v_month_start DATE;
BEGIN
  -- Get the entry date and user_id from the affected row
  IF TG_OP = 'DELETE' THEN
    v_entry_date := OLD.entry_date::DATE;
    v_user_id := OLD.user_id;
  ELSE
    v_entry_date := NEW.entry_date::DATE;
    v_user_id := NEW.user_id;
  END IF;

  -- Calculate week and month start for cascade
  v_week_start := date_trunc('week', v_entry_date)::DATE;
  v_month_start := date_trunc('month', v_entry_date)::DATE;

  -- Mark daily page dirty
  UPDATE public.pages
  SET needs_refresh = true, updated_at = NOW()
  WHERE user_id = v_user_id
    AND granularity = 'daily'
    AND page_date = v_entry_date;

  -- Mark weekly page dirty
  UPDATE public.pages
  SET needs_refresh = true, updated_at = NOW()
  WHERE user_id = v_user_id
    AND granularity = 'weekly'
    AND week_start = v_week_start;

  -- Mark monthly page dirty
  UPDATE public.pages
  SET needs_refresh = true, updated_at = NOW()
  WHERE user_id = v_user_id
    AND granularity = 'monthly'
    AND page_date = v_month_start;

  -- Mark yearly page dirty
  UPDATE public.pages
  SET needs_refresh = true, updated_at = NOW()
  WHERE user_id = v_user_id
    AND granularity = 'yearly'
    AND EXTRACT(YEAR FROM page_date) = EXTRACT(YEAR FROM v_entry_date);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- 6. Triggers on journal_entries for auto-dirty marking
DROP TRIGGER IF EXISTS trg_mark_daily_dirty_insert ON public.journal_entries;
CREATE TRIGGER trg_mark_daily_dirty_insert
  AFTER INSERT ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.mark_daily_page_dirty();

DROP TRIGGER IF EXISTS trg_mark_daily_dirty_update ON public.journal_entries;
CREATE TRIGGER trg_mark_daily_dirty_update
  AFTER UPDATE ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.mark_daily_page_dirty();

DROP TRIGGER IF EXISTS trg_mark_daily_dirty_delete ON public.journal_entries;
CREATE TRIGGER trg_mark_daily_dirty_delete
  AFTER DELETE ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.mark_daily_page_dirty();

-- 7. Function to get entries for daily story generation
CREATE OR REPLACE FUNCTION public.get_entries_for_daily_story(
  p_user_id UUID,
  p_date DATE
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  raw_content TEXT,
  mood TEXT,
  location_name TEXT,
  entry_time TEXT,
  has_photo BOOLEAN,
  has_voice BOOLEAN,
  word_count INT,
  media JSONB
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    je.id,
    je.content,
    je.raw_content,
    je.mood,
    je.location_name,
    TO_CHAR(je.entry_date, 'HH24:MI') AS entry_time,
    je.has_photo,
    je.has_voice,
    je.word_count,
    COALESCE(
      (SELECT jsonb_agg(jsonb_build_object(
        'storage_path', em.storage_path,
        'media_type', em.media_type
      )) FROM entry_media em WHERE em.entry_id = je.id),
      '[]'::jsonb
    ) AS media
  FROM journal_entries je
  WHERE je.user_id = p_user_id
    AND je.entry_date::DATE = p_date
    AND je.deleted_at IS NULL
  ORDER BY je.entry_date ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_entries_for_daily_story(UUID, DATE) TO authenticated;

-- 8. Function to get daily pages for weekly story generation
CREATE OR REPLACE FUNCTION public.get_daily_pages_for_week(
  p_user_id UUID,
  p_week_start DATE
)
RETURNS TABLE (
  page_date DATE,
  content TEXT,
  highlights JSONB,
  mood_summary TEXT,
  people JSONB,
  word_count INT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    p.page_date,
    string_agg(p.content, E'\n\n' ORDER BY p.page_number) AS content,
    (SELECT highlights FROM public.pages p2
     WHERE p2.user_id = p_user_id AND p2.granularity = 'daily'
       AND p2.page_date = p.page_date AND p2.page_number = 0
     LIMIT 1) AS highlights,
    (SELECT mood_summary FROM public.pages p2
     WHERE p2.user_id = p_user_id AND p2.granularity = 'daily'
       AND p2.page_date = p.page_date AND p2.page_number = 0
     LIMIT 1) AS mood_summary,
    (SELECT people FROM public.pages p2
     WHERE p2.user_id = p_user_id AND p2.granularity = 'daily'
       AND p2.page_date = p.page_date AND p2.page_number = 0
     LIMIT 1) AS people,
    SUM(p.word_count)::INT AS word_count
  FROM public.pages p
  WHERE p.user_id = p_user_id
    AND p.granularity = 'daily'
    AND p.page_date >= p_week_start
    AND p.page_date < p_week_start + INTERVAL '7 days'
  GROUP BY p.page_date
  ORDER BY p.page_date;
$$;

GRANT EXECUTE ON FUNCTION public.get_daily_pages_for_week(UUID, DATE) TO authenticated;

-- 9. Helper: find users needing daily story generation
-- Used by the ai-daily-story Edge Function cron trigger.
CREATE OR REPLACE FUNCTION public.get_users_needing_daily_story(p_date DATE)
RETURNS TABLE (user_id UUID)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  -- Users who have entries on this date but no daily page yet
  SELECT DISTINCT je.user_id
  FROM journal_entries je
  WHERE je.entry_date::DATE = p_date
    AND je.deleted_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM pages p
      WHERE p.user_id = je.user_id
        AND p.granularity = 'daily'
        AND p.page_date = p_date
        AND p.needs_refresh = false
    )
  UNION
  -- Users whose daily page needs refresh
  SELECT DISTINCT p.user_id
  FROM pages p
  WHERE p.granularity = 'daily'
    AND p.page_date = p_date
    AND p.needs_refresh = true;
$$;

GRANT EXECUTE ON FUNCTION public.get_users_needing_daily_story(DATE) TO service_role;

-- 10. pg_cron schedule for daily story generation
-- Runs at 00:05 UTC daily. The Edge Function processes all pending users.
-- Note: pg_cron must be enabled in Supabase dashboard (Database → Extensions).
DO $$
BEGIN
  -- Daily stories at midnight
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.schedule(
      'generate-daily-stories',
      '5 0 * * *',  -- 00:05 UTC daily
      $cron$
      SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/ai-daily-story',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body := '{}'::jsonb
      );
      $cron$
    );
  END IF;
END;
$$;

-- 11. Update source CHECK constraint to include new values
ALTER TABLE public.pages DROP CONSTRAINT IF EXISTS pages_source_check;
ALTER TABLE public.pages ADD CONSTRAINT pages_source_check
  CHECK (source IN ('weekly_job', 'manual', 'daily_cron', 'weekly_cron', 'monthly_cron', 'yearly_cron'));

-- 12. Refresh statistics
ANALYZE public.pages;