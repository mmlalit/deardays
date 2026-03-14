-- Migration 022: Reflection cache table
-- Stores AI-generated weekly/monthly/yearly reflections per user.
-- Re-used on every screen open; AI re-runs only when the period_key changes.
--
-- period_key format:
--   weekly  → ISO week: '2026-W11'
--   monthly → '2026-03'
--   yearly  → '2026'

CREATE TABLE IF NOT EXISTS reflection_cache (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  period        TEXT        NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly')),
  period_key    TEXT        NOT NULL,
  summary       TEXT,
  themes        JSONB       NOT NULL DEFAULT '[]'::jsonb,
  generated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_reflection_user_period UNIQUE (user_id, period, period_key)
);

CREATE INDEX IF NOT EXISTS idx_reflection_cache_lookup
  ON reflection_cache (user_id, period, period_key);

ALTER TABLE reflection_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reflection_cache_select_own"
  ON reflection_cache FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "reflection_cache_insert_own"
  ON reflection_cache FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reflection_cache_update_own"
  ON reflection_cache FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "reflection_cache_delete_own"
  ON reflection_cache FOR DELETE
  USING (auth.uid() = user_id);

-- Service-role policy used by the Edge Function cron job.
-- The Edge Function runs as service_role and pre-generates reflections
-- for all active users, so it needs to bypass RLS.
CREATE POLICY "reflection_cache_service_role_all"
  ON reflection_cache FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
