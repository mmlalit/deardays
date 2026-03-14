-- Migration 023: Helper RPC for the generate-reflections Edge Function.
--
-- get_active_users_since(since_date) → returns distinct user_ids that have
-- at least one journal entry on or after since_date.
-- Called by the service-role cron; returns no PII beyond user UUIDs.

CREATE OR REPLACE FUNCTION get_active_users_since(since_date DATE)
RETURNS TABLE (user_id UUID)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT DISTINCT je.user_id
  FROM journal_entries je
  WHERE je.entry_date >= since_date;
$$;

-- Only callable by service_role (cron) and postgres.
REVOKE ALL ON FUNCTION get_active_users_since(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_active_users_since(DATE) TO service_role;
