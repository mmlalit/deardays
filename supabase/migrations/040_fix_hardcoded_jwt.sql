-- Migration 040: Remove hardcoded service-role JWT from pg_cron jobs.
--
-- Migration 034 created 4 cron jobs (weekly_page_gen_run_1..4) whose body
-- contained a hardcoded service-role JWT. This is a CRITICAL security issue:
-- the service-role key is a secret that must never appear in SQL migrations
-- checked into source control.
--
-- Migration 037 created invoke_weekly_page_worker() which reads the edge
-- function URL and anon key from app_config at runtime. This migration
-- replaces the four old jobs with safe equivalents that call that function.
-- The anon key stored in app_config (set by 038) is the Supabase anon key,
-- which is intentionally public — it is not the service-role key.
--
-- After applying this migration, rotate the service-role key in the Supabase
-- dashboard (Settings → API → Service Role Key → Regenerate) since it was
-- committed to source control.
-- ============================================================================

-- Unschedule the old jobs that contained the hardcoded JWT.
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN (
  'weekly_page_gen_run_1',
  'weekly_page_gen_run_2',
  'weekly_page_gen_run_3',
  'weekly_page_gen_run_4'
);

-- Re-create the same schedule windows using the safe wrapper function.
-- invoke_weekly_page_worker() reads URL and anon key from app_config at
-- call time, so no secret is embedded in the cron job body.
SELECT cron.schedule(
  'weekly_page_gen_run_1',
  '5 6 * * 6',
  'SELECT public.invoke_weekly_page_worker(20)'
);

SELECT cron.schedule(
  'weekly_page_gen_run_2',
  '15 6 * * 6',
  'SELECT public.invoke_weekly_page_worker(20)'
);

SELECT cron.schedule(
  'weekly_page_gen_run_3',
  '25 6 * * 6',
  'SELECT public.invoke_weekly_page_worker(20)'
);

SELECT cron.schedule(
  'weekly_page_gen_run_4',
  '35 6 * * 6',
  'SELECT public.invoke_weekly_page_worker(20)'
);
