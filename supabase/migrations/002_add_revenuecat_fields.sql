-- ============================================================================
-- DearDays: Migration 002 — Add RevenueCat integration fields
-- ============================================================================

-- Store the RevenueCat customer ID for webhook matching.
-- This is the same as the Supabase user ID (auth.uid()) but stored explicitly
-- so the webhook Edge Function can query by it.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS revenuecat_customer_id TEXT;

-- Index for webhook lookups by RevenueCat customer ID.
CREATE INDEX IF NOT EXISTS idx_profiles_revenuecat_customer_id
  ON public.profiles (revenuecat_customer_id);

-- Allow the service_role (used by Edge Functions) to update subscription fields.
-- RLS policies already allow users to update their own profile.
-- The webhook uses the service_role key which bypasses RLS.
