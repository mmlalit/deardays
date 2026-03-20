-- ============================================================
-- Migration 034: book creation_approach + generation_queue unique constraint
-- + cron schedule to invoke ai-weekly-page edge function
-- ============================================================

-- ------------------------------------------------------------
-- 1. Add creation_approach to books
--    'chronological' = auto monthly chapters, continuous context
--    'thematic'      = user-defined chapters, context per chapter
-- ------------------------------------------------------------
ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS creation_approach TEXT NOT NULL DEFAULT 'chronological'
  CHECK (creation_approach IN ('chronological', 'thematic'));

-- ------------------------------------------------------------
-- 2. Add unique constraint to generation_queue so that
--    ON CONFLICT DO NOTHING in enqueue_weekly_page_generation()
--    correctly deduplicates (user, chapter, week) combinations.
-- ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'generation_queue_user_chapter_week_uniq'
  ) THEN
    ALTER TABLE public.generation_queue
      ADD CONSTRAINT generation_queue_user_chapter_week_uniq
      UNIQUE (user_id, chapter_id, week_start);
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- 3. Schedule ai-weekly-page edge function via pg_cron
--    Runs at 06:05 UTC every Saturday — 5 minutes after the
--    enqueue_weekly_page_generation() job populates the queue.
--
--    Runs again at 06:15, 06:25, 06:35 to drain the queue
--    for larger user bases (each invocation processes up to
--    20 items in parallel).
-- ------------------------------------------------------------

SELECT cron.schedule(
  'weekly_page_gen_run_1',
  '5 6 * * 6',
  $$
  SELECT net.http_post(
    url     := 'https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1/ai-weekly-page',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg3NzQ1OCwiZXhwIjoyMDg4NDUzNDU4fQ.L3HYcwCBIgxQm_DqALV_ToUbPqaAcBz8g-LVcgVFu0k"}'::jsonb,
    body    := '{"limit":20}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'weekly_page_gen_run_2',
  '15 6 * * 6',
  $$
  SELECT net.http_post(
    url     := 'https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1/ai-weekly-page',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg3NzQ1OCwiZXhwIjoyMDg4NDUzNDU4fQ.L3HYcwCBIgxQm_DqALV_ToUbPqaAcBz8g-LVcgVFu0k"}'::jsonb,
    body    := '{"limit":20}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'weekly_page_gen_run_3',
  '25 6 * * 6',
  $$
  SELECT net.http_post(
    url     := 'https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1/ai-weekly-page',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg3NzQ1OCwiZXhwIjoyMDg4NDUzNDU4fQ.L3HYcwCBIgxQm_DqALV_ToUbPqaAcBz8g-LVcgVFu0k"}'::jsonb,
    body    := '{"limit":20}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'weekly_page_gen_run_4',
  '35 6 * * 6',
  $$
  SELECT net.http_post(
    url     := 'https://mcmlawztwyrjcwmieciw.supabase.co/functions/v1/ai-weekly-page',
    headers := '{"Content-Type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg3NzQ1OCwiZXhwIjoyMDg4NDUzNDU4fQ.L3HYcwCBIgxQm_DqALV_ToUbPqaAcBz8g-LVcgVFu0k"}'::jsonb,
    body    := '{"limit":20}'::jsonb
  );
  $$
);
