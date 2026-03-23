-- Migration 041: Add advisory lock to run_data_retention() to prevent
-- concurrent execution when pg_cron fires overlapping runs.
--
-- Without the lock, two simultaneous cron invocations could both attempt
-- to DELETE the same profile rows, causing foreign-key constraint races or
-- double-delete errors.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.run_data_retention()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Acquire a session-level advisory lock keyed on this function.
  -- pg_try_advisory_lock returns false immediately if the lock is held,
  -- so overlapping cron invocations skip silently rather than queuing.
  IF NOT pg_try_advisory_lock(hashtext('run_data_retention')) THEN
    RAISE NOTICE 'run_data_retention: already running, skipping this invocation';
    RETURN;
  END IF;

  BEGIN
    -- 1. Purge accounts soft-deleted more than 30 days ago.
    --    CASCADE on profiles FK deletes journal_entries, entry_media,
    --    chapters, book_exports, streaks automatically.
    DELETE FROM public.profiles
    WHERE account_deleted_at IS NOT NULL
      AND account_deleted_at < now() - INTERVAL '30 days';

    -- 2. Purge encrypted data for expired subscriptions inactive > 12 months
    --    (keeps the profile row so user can re-subscribe, but removes content).
    DELETE FROM public.journal_entries
    WHERE user_id IN (
      SELECT id FROM public.profiles
      WHERE is_subscribed            = false
        AND consent_withdrawn_at    IS NULL
        AND account_deleted_at      IS NULL
        AND subscription_expires_at IS NOT NULL
        AND subscription_expires_at < now() - INTERVAL '12 months'
        AND trial_started_at        < now() - INTERVAL '12 months'
    );
  EXCEPTION WHEN OTHERS THEN
    -- Always release the lock, even on error.
    PERFORM pg_advisory_unlock(hashtext('run_data_retention'));
    RAISE;
  END;

  PERFORM pg_advisory_unlock(hashtext('run_data_retention'));
END;
$$;

COMMENT ON FUNCTION public.run_data_retention()
  IS 'Enforces data retention policy: 30-day purge for deleted accounts, '
     '12-month purge for expired subscriptions. Uses advisory lock to '
     'prevent concurrent execution.';
