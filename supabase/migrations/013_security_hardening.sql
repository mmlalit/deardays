-- ============================================================================
-- DearDays: Migration 013 — Security Hardening
--
-- Fixes identified during security audit:
--   1. RPC auth bypass in get_on_this_day_entries
--   2. Weak salt generation in handle_new_user
--   3. Overly broad ai_usage service_role policy
--   4. Missing WITH CHECK on books UPDATE policy
--   5. Missing index on entry_media.user_id
--   6. Webhook auth enforcement (application-level, documented here)
-- ============================================================================


-- ============================================================================
-- 1. FIX: get_on_this_day_entries — enforce auth.uid() check
--    Previously accepted any p_user_id, allowing authenticated users to
--    read another user's entries via the RPC endpoint.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_on_this_day_entries(
  p_user_id UUID,
  p_month_day TEXT  -- format: 'MM-DD'
)
RETURNS SETOF public.journal_entries
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT *
  FROM public.journal_entries
  WHERE user_id = p_user_id
    AND user_id = auth.uid()        -- caller can only query own data
    AND to_char(entry_date, 'MM-DD') = p_month_day
    AND entry_date < CURRENT_DATE   -- exclude today
  ORDER BY entry_date DESC;
$$;


-- ============================================================================
-- 2. FIX: handle_new_user — use cryptographic random salt instead of md5(random())
--    md5(random()::text) has limited entropy. gen_random_bytes(16) provides
--    128 bits of cryptographic randomness.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, encryption_salt)
  VALUES (
    NEW.id,
    encode(gen_random_bytes(16), 'base64')   -- 128-bit cryptographic random salt
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 3. FIX: ai_usage — replace overly broad service_role policy
--    auth.role() = 'service_role' is the wrong check — service_role bypasses
--    RLS entirely. This policy was effectively a no-op but is misleading.
--    Drop it; service_role already bypasses RLS by design. Users should only
--    have SELECT access; INSERT/UPDATE is done via increment_ai_usage() RPC.
-- ============================================================================

DROP POLICY IF EXISTS "Service role full access" ON public.ai_usage;

-- Ensure users can only read, not modify their own usage rows directly.
-- (increment_ai_usage runs as SECURITY DEFINER so it bypasses RLS)
DROP POLICY IF EXISTS "Users can view own usage" ON public.ai_usage;
CREATE POLICY "Users can view own usage"
  ON public.ai_usage FOR SELECT
  USING (auth.uid() = user_id);


-- ============================================================================
-- 4. FIX: books UPDATE policy — add WITH CHECK to prevent user_id reassignment
--    Without WITH CHECK, a user could theoretically UPDATE user_id to another
--    user's ID, transferring ownership of the book.
-- ============================================================================

DROP POLICY IF EXISTS "Users can update own books" ON public.books;
CREATE POLICY "Users can update own books"
  ON public.books FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ============================================================================
-- 5. ADD: Missing index on entry_media.user_id
--    RLS policies filter on user_id for every query; without an index on
--    user_id, these checks require a sequential scan on entry_media.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_entry_media_user_id
  ON public.entry_media (user_id);


-- ============================================================================
-- 6. ADD: Index on check_in_conversations for RLS performance
--    The RLS policy filters on user_id; add a covering index.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_checkin_conversations_user_id
  ON public.check_in_conversations (user_id);


-- ============================================================================
-- 7. ADD: Index on book_exports.user_id for RLS performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_book_exports_user_id
  ON public.book_exports (user_id);


-- ============================================================================
-- 8. ADD: Index on chapters.user_id for RLS performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_chapters_user_id
  ON public.chapters (user_id);


-- ============================================================================
-- 9. FIX: increment_ai_usage — clamp cost to prevent negative-cost injection
--    The p_cost parameter is caller-controlled (from Edge Functions). While
--    Edge Functions set it correctly, hardening the DB function prevents
--    misuse if someone calls the RPC directly.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.increment_ai_usage(
  p_user_id UUID,
  p_function_name TEXT,
  p_cost NUMERIC DEFAULT 0
)
RETURNS VOID AS $$
  INSERT INTO ai_usage (user_id, function_name, call_date, call_count, estimated_cost_usd)
  VALUES (p_user_id, p_function_name, CURRENT_DATE, 1, GREATEST(p_cost, 0))
  ON CONFLICT (user_id, function_name, call_date)
  DO UPDATE SET
    call_count = ai_usage.call_count + 1,
    estimated_cost_usd = ai_usage.estimated_cost_usd + GREATEST(p_cost, 0),
    updated_at = NOW();
$$ LANGUAGE sql SECURITY DEFINER
   SET search_path = public;


-- ============================================================================
-- 10. FIX: Set search_path on all SECURITY DEFINER functions
--     Prevents search_path hijacking (CWE-426). A malicious schema on the
--     search_path could shadow public tables/functions.
-- ============================================================================

ALTER FUNCTION public.update_updated_at()          SET search_path = public;
ALTER FUNCTION public.handle_new_user()            SET search_path = public, auth;
ALTER FUNCTION public.update_streak_on_entry()     SET search_path = public;
ALTER FUNCTION public.get_on_this_day_entries(UUID, TEXT) SET search_path = public;
ALTER FUNCTION public.run_data_retention()         SET search_path = public;
ALTER FUNCTION public.get_daily_ai_cost()          SET search_path = public;
