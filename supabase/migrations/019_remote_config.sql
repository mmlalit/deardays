-- Remote config table for feature flags (fallback when PostHog is unavailable).
--
-- Usage: FeatureFlags reads from this table when PostHog is not configured
-- or unreachable. Supports per-platform overrides.

CREATE TABLE IF NOT EXISTS remote_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key TEXT NOT NULL,
  value TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'flutter',
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(key, platform)
);

-- Index for the lookup pattern used by FeatureFlags.refresh()
CREATE INDEX idx_remote_config_platform ON remote_config(platform);

-- RLS: only authenticated users can read, no client writes
ALTER TABLE remote_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read remote config"
  ON remote_config FOR SELECT
  TO authenticated
  USING (true);

-- Seed default values for all feature flags
INSERT INTO remote_config (key, value, platform, description) VALUES
  ('ai_streaming', 'false', 'flutter', 'AI response streaming (word-by-word display)'),
  ('ai_checkin', 'true', 'flutter', 'AI-powered check-in conversations'),
  ('ai_polish', 'true', 'flutter', 'AI polish on journal entries'),
  ('book_generation', 'true', 'flutter', 'Book/chapter generation'),
  ('voice_recording', 'true', 'flutter', 'Voice recording and transcription'),
  ('share_cards', 'true', 'flutter', 'Share card generation'),
  ('weekly_summary', 'true', 'flutter', 'Weekly AI summary/reflection'),
  ('on_this_day', 'true', 'flutter', 'On This Day feature'),
  ('new_onboarding', 'false', 'flutter', 'New onboarding flow (A/B test)'),
  ('paywall_v2', 'false', 'flutter', 'Paywall v2 (A/B test)'),
  ('min_app_version', '1.0.0', 'flutter', 'Minimum required app version — force-update below this')
ON CONFLICT (key, platform) DO NOTHING;
