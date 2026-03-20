-- ============================================================
-- Migration 029: app_config table
-- Global configuration values editable without code deploy.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Only service_role can write; authenticated users can read
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_config_read" ON public.app_config
  FOR SELECT TO authenticated USING (true);

-- Seeds -----------------------------------------------------------

INSERT INTO public.app_config (key, value, description) VALUES
  ('daily_memory_limit',          '10',   'Max memories a single user can create per calendar day'),
  ('minimum_memories_for_page',   '3',    'Min memories in a week before Saturday job generates a page'),
  ('words_per_page',              '275',  'Target word count per book page before splitting at paragraph boundary'),
  ('anomaly_memory_threshold',    '30',   'Memories created by one user in one day that triggers anomaly alert (default 3× daily limit)'),
  ('global_daily_spend_alert',    '20',   'USD: total AI spend across all users in one day that triggers alert'),
  ('trial_duration_days',         '15',   'Free trial length in days before paywall'),
  ('weekly_job_batch_size',       '50',   'Number of users processed per batch in Saturday page generation job'),
  ('weekly_job_batch_delay_ms',   '200',  'Milliseconds delay between batches in Saturday job'),
  ('weekly_job_user_timeout_sec', '30',   'Per-user timeout in seconds during Saturday page generation')
ON CONFLICT (key) DO NOTHING;

-- Auto-update updated_at on change
CREATE OR REPLACE FUNCTION public.app_config_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER app_config_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.app_config_updated_at();
