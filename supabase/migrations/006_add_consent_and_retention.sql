-- ============================================================================
-- DearDays Migration 006: Consent Columns, Age Gate & Data Retention
--
-- Compliance: GDPR, CCPA/CPRA, India DPDPA 2023, COPPA
-- ============================================================================


-- ============================================================================
-- 1. CONSENT & AGE COLUMNS on profiles
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS consent_given_at       TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS health_consent_given_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS date_of_birth          DATE,
  ADD COLUMN IF NOT EXISTS do_not_sell             BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS consent_withdrawn_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS account_deleted_at      TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.consent_given_at
  IS 'Timestamp when user accepted Terms + Privacy Policy (GDPR Art 7 record of consent).';

COMMENT ON COLUMN public.profiles.health_consent_given_at
  IS 'Separate consent for health/mood data processing (GDPR Art 9 special category).';

COMMENT ON COLUMN public.profiles.date_of_birth
  IS 'Used for age verification: 13+ US/EU (COPPA), 18+ India (DPDPA).';

COMMENT ON COLUMN public.profiles.do_not_sell
  IS 'CCPA/CPRA "Do Not Sell or Share My Personal Information" toggle.';

COMMENT ON COLUMN public.profiles.consent_withdrawn_at
  IS 'If set, user has withdrawn consent. Data processing must stop.';

COMMENT ON COLUMN public.profiles.account_deleted_at
  IS 'Soft-delete timestamp. Data purged after 30 days per retention policy.';


-- ============================================================================
-- 2. DATA RETENTION: Auto-purge soft-deleted accounts after 30 days
--    and expired subscriptions after 12 months of inactivity.
--
--    Schedule this function via pg_cron or Supabase Edge Function cron.
--    Example: SELECT cron.schedule('daily-retention', '0 3 * * *',
--             'SELECT public.run_data_retention()');
-- ============================================================================

CREATE OR REPLACE FUNCTION public.run_data_retention()
RETURNS void AS $$
BEGIN
  -- 1. Purge accounts soft-deleted more than 30 days ago
  --    CASCADE on profiles FK will delete journal_entries, entry_media,
  --    chapters, book_exports, streaks automatically.
  DELETE FROM public.profiles
  WHERE account_deleted_at IS NOT NULL
    AND account_deleted_at < now() - INTERVAL '30 days';

  -- 2. Purge encrypted data for expired subscriptions inactive > 12 months
  --    (keeps the profile row so user can re-subscribe, but removes content)
  DELETE FROM public.journal_entries
  WHERE user_id IN (
    SELECT id FROM public.profiles
    WHERE is_subscribed = false
      AND consent_withdrawn_at IS NULL
      AND account_deleted_at IS NULL
      AND subscription_expires_at IS NOT NULL
      AND subscription_expires_at < now() - INTERVAL '12 months'
      AND trial_started_at < now() - INTERVAL '12 months'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.run_data_retention()
  IS 'Enforces data retention policy: 30-day purge for deleted accounts, 12-month purge for expired subscriptions.';
