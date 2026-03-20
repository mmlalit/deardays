-- ============================================================
-- Migration 031: Logging & monitoring tables
-- ai_cost_log      — per-call AI spend tracking
-- job_run_log      — Saturday + Friday job execution history
-- alert_log        — anomaly and spend alerts
-- notifications_log — push notifications sent to users
-- ============================================================

-- ------------------------------------------------------------
-- ai_cost_log
-- Inserted after every AI API call. Used for per-user caps
-- and global daily spend monitoring.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_cost_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  prompt_type     TEXT NOT NULL,  -- e.g. 'lightPolish', 'weeklyPage', 'checkin'
  model           TEXT NOT NULL,  -- e.g. 'claude-haiku-4-5', 'claude-sonnet-4-6'
  input_tokens    INT NOT NULL DEFAULT 0,
  output_tokens   INT NOT NULL DEFAULT 0,
  cost_usd        NUMERIC(10, 6) NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ai_cost_log ENABLE ROW LEVEL SECURITY;

-- Users can see their own cost log; service_role writes
CREATE POLICY "ai_cost_log_owner_read" ON public.ai_cost_log
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS ai_cost_log_user_date_idx
  ON public.ai_cost_log (user_id, created_at);

CREATE INDEX IF NOT EXISTS ai_cost_log_date_idx
  ON public.ai_cost_log (created_at);

-- ------------------------------------------------------------
-- job_run_log
-- One row per job execution (Saturday page gen, Friday reminder).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.job_run_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name        TEXT NOT NULL,  -- 'saturday_page_gen' | 'friday_reminder'
  started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at     TIMESTAMPTZ,
  status          TEXT NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'completed', 'failed')),
  users_processed INT NOT NULL DEFAULT 0,
  pages_generated INT NOT NULL DEFAULT 0,
  errors          INT NOT NULL DEFAULT 0,
  error_details   JSONB,
  cost_usd        NUMERIC(10, 4) NOT NULL DEFAULT 0
);

ALTER TABLE public.job_run_log ENABLE ROW LEVEL SECURITY;
-- Only service_role reads/writes (no user policy needed)

CREATE INDEX IF NOT EXISTS job_run_log_name_date_idx
  ON public.job_run_log (job_name, started_at DESC);

-- ------------------------------------------------------------
-- alert_log
-- Anomaly and spend alerts for admin monitoring.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alert_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type    TEXT NOT NULL,  -- 'anomaly_memory' | 'daily_spend' | 'user_cap_reached'
  severity      TEXT NOT NULL DEFAULT 'warning'
                  CHECK (severity IN ('info', 'warning', 'critical')),
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  details       JSONB NOT NULL DEFAULT '{}',
  resolved      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.alert_log ENABLE ROW LEVEL SECURITY;
-- Admin-only via service_role; no user policy

CREATE INDEX IF NOT EXISTS alert_log_type_date_idx
  ON public.alert_log (alert_type, created_at DESC);

CREATE INDEX IF NOT EXISTS alert_log_unresolved_idx
  ON public.alert_log (resolved, created_at DESC)
  WHERE resolved = FALSE;

-- ------------------------------------------------------------
-- notifications_log
-- Record of every push notification sent to users.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,  -- 'weekly_story_ready' | 'friday_reminder' | 'milestone'
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  delivered       BOOLEAN,          -- NULL = unknown, true/false = FCM/APNs receipt
  opened          BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE public.notifications_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_log_owner" ON public.notifications_log
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS notifications_log_user_idx
  ON public.notifications_log (user_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS notifications_log_type_date_idx
  ON public.notifications_log (notification_type, sent_at DESC);
