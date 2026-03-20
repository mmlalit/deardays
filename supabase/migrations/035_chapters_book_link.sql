-- ============================================================
-- Migration 035: chapters.book_id + fixed weekly job query
--
-- Adds book_id to chapters so:
--   thematic books  → selected chapters get book_id set by the Flutter app
--   chronological books → one auto-chapter "My Story" is created with book_id
--
-- Also replaces enqueue_weekly_page_generation() with a version that
-- uses the proper chapter → book relationship instead of a cartesian join.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Add book_id to chapters
-- ------------------------------------------------------------
ALTER TABLE public.chapters
  ADD COLUMN IF NOT EXISTS book_id UUID REFERENCES public.books(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS chapters_book_idx ON public.chapters (book_id);

-- ------------------------------------------------------------
-- 2. Replace enqueue_weekly_page_generation() with a corrected version
--    that queries via chapters.book_id rather than a user-level join.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enqueue_weekly_page_generation()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_min_memories   INT;
  v_week_start     DATE;
  v_job_id         UUID;
BEGIN
  v_min_memories := public.get_app_config('minimum_memories_for_page', '3')::INT;

  -- Monday of the week that just completed (Saturday job runs after Sunday ends)
  v_week_start := date_trunc('week', CURRENT_DATE - INTERVAL '1 day')::DATE;

  INSERT INTO public.job_run_log (job_name, started_at, status)
  VALUES ('saturday_page_gen', NOW(), 'running')
  RETURNING id INTO v_job_id;

  -- ── Thematic books ──────────────────────────────────────────────────────────
  -- Entries are tagged with chapter_id; the chapter links to a thematic book.
  INSERT INTO public.generation_queue (
    user_id, chapter_id, book_id, week_start, memory_ids
  )
  SELECT
    je.user_id,
    je.chapter_id,
    c.book_id,
    v_week_start,
    array_agg(je.id ORDER BY je.entry_date) AS memory_ids
  FROM public.journal_entries je
  JOIN public.chapters c
    ON c.id = je.chapter_id
   AND c.book_id IS NOT NULL
  JOIN public.books b
    ON b.id = c.book_id
   AND b.creation_approach = 'thematic'
  WHERE je.entry_date >= v_week_start
    AND je.entry_date <  v_week_start + INTERVAL '7 days'
  GROUP BY je.user_id, je.chapter_id, c.book_id
  HAVING count(*) >= v_min_memories
  ON CONFLICT (user_id, chapter_id, week_start) DO NOTHING;

  -- ── Chronological books ─────────────────────────────────────────────────────
  -- All entries for the user this week (regardless of chapter_id) are swept
  -- into the single auto-chapter that belongs to the chronological book.
  -- If the user has multiple chronological books, each gets its own queue row.
  INSERT INTO public.generation_queue (
    user_id, chapter_id, book_id, week_start, memory_ids
  )
  SELECT
    je.user_id,
    c.id       AS chapter_id,   -- the auto-chapter for this chronological book
    b.id       AS book_id,
    v_week_start,
    array_agg(je.id ORDER BY je.entry_date) AS memory_ids
  FROM public.journal_entries je
  JOIN public.books b
    ON b.user_id = je.user_id
   AND b.creation_approach = 'chronological'
  -- The auto-chapter is the single chapter whose book_id = this book
  JOIN public.chapters c
    ON c.book_id = b.id
  WHERE je.entry_date >= v_week_start
    AND je.entry_date <  v_week_start + INTERVAL '7 days'
  GROUP BY je.user_id, c.id, b.id
  HAVING count(*) >= v_min_memories
  ON CONFLICT (user_id, chapter_id, week_start) DO NOTHING;

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
