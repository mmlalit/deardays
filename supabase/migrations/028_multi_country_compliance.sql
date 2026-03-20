-- ============================================================================
-- DearDays Migration 028: Multi-Country Compliance
--
-- Adds per-country compliance fields, consent audit logging, and a grievance
-- request system for India DPDPA 2023.
--
-- Countries: US, UK, Canada (PIPEDA + Quebec Law 25 + CASL),
--            India (DPDPA 2023), Netherlands/EU (GDPR)
-- ============================================================================


-- ============================================================================
-- 1. COUNTRY & MARKETING CONSENT COLUMNS on profiles
-- ============================================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS country_code        CHAR(2),
  ADD COLUMN IF NOT EXISTS marketing_consent   BOOLEAN   DEFAULT false,
  ADD COLUMN IF NOT EXISTS marketing_consent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS casl_channels       TEXT[]    DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS parental_consent    BOOLEAN   DEFAULT false,
  ADD COLUMN IF NOT EXISTS parental_consent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS terms_version       TEXT,
  ADD COLUMN IF NOT EXISTS privacy_version     TEXT;

COMMENT ON COLUMN public.profiles.country_code
  IS 'ISO 3166-1 alpha-2 country code captured at signup. Determines applicable law (GDPR, CCPA, PIPEDA, DPDPA).';

COMMENT ON COLUMN public.profiles.marketing_consent
  IS 'Explicit marketing consent (CASL for Canada, GDPR Art 6(1)(a) for EU/UK). False = no marketing messages.';

COMMENT ON COLUMN public.profiles.marketing_consent_at
  IS 'Timestamp of most recent marketing consent change for audit purposes.';

COMMENT ON COLUMN public.profiles.casl_channels
  IS 'Canada CASL: channels user has consented to, e.g. {email, push}. Empty = no channels.';

COMMENT ON COLUMN public.profiles.parental_consent
  IS 'India DPDPA 2023: verifiable parental consent for users under 18. Required before account activation.';

COMMENT ON COLUMN public.profiles.parental_consent_at
  IS 'Timestamp parental consent was verified for Indian users under 18.';

COMMENT ON COLUMN public.profiles.terms_version
  IS 'Version/date of Terms of Service the user last accepted, e.g. "2026-03-17".';

COMMENT ON COLUMN public.profiles.privacy_version
  IS 'Version/date of Privacy Policy the user last accepted, e.g. "2026-03-17".';


-- ============================================================================
-- 2. CONSENT AUDIT LOG
--    Immutable append-only log of every consent event.
--    Users cannot update or delete rows — enforced by RLS.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.consent_audit_log (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_type    TEXT        NOT NULL,   -- e.g. 'terms_accepted', 'marketing_opt_in', 'mood_consent_withdrawn'
  event_detail  JSONB       DEFAULT '{}',
  country_code  CHAR(2),
  ip_hash       TEXT,                   -- SHA-256 hash of IP — never store raw IP
  user_agent    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.consent_audit_log
  IS 'Immutable audit trail of all consent events. Required by GDPR Art. 7(1), CASL s.13, DPDPA 2023.';

COMMENT ON COLUMN public.consent_audit_log.event_type
  IS 'One of: terms_accepted, privacy_accepted, marketing_opt_in, marketing_opt_out, mood_consent_given, mood_consent_withdrawn, ai_consent_given, ai_consent_withdrawn, account_deleted, do_not_sell_toggled, parental_consent_given';

COMMENT ON COLUMN public.consent_audit_log.ip_hash
  IS 'SHA-256 hash of the users IP address at time of consent. Never store raw IP.';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_consent_audit_log_user_id
  ON public.consent_audit_log(user_id);

CREATE INDEX IF NOT EXISTS idx_consent_audit_log_created_at
  ON public.consent_audit_log(created_at DESC);

-- RLS: users can read their own log; nobody can insert via client (server only)
ALTER TABLE public.consent_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own consent log"
  ON public.consent_audit_log
  FOR SELECT
  USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE policy for users — all writes go through server-side functions only.


-- ============================================================================
-- 3. GRIEVANCE REQUESTS (India DPDPA 2023)
--    Required: acknowledge within 48h, resolve within 30 days.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.grievance_requests (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  name            TEXT        NOT NULL,
  email           TEXT        NOT NULL,
  country_code    CHAR(2)     DEFAULT 'IN',
  subject         TEXT        NOT NULL,
  description     TEXT        NOT NULL,
  category        TEXT        NOT NULL DEFAULT 'general',  -- general | data_access | data_deletion | data_correction | ai_processing | other
  status          TEXT        NOT NULL DEFAULT 'open',     -- open | acknowledged | in_progress | resolved | closed
  acknowledged_at TIMESTAMPTZ,
  resolved_at     TIMESTAMPTZ,
  resolution_note TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.grievance_requests
  IS 'India DPDPA 2023 grievance mechanism. Must acknowledge within 48h, resolve within 30 days.';

COMMENT ON COLUMN public.grievance_requests.category
  IS 'general | data_access | data_deletion | data_correction | ai_processing | other';

COMMENT ON COLUMN public.grievance_requests.status
  IS 'open | acknowledged | in_progress | resolved | closed';

CREATE INDEX IF NOT EXISTS idx_grievance_requests_user_id
  ON public.grievance_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_grievance_requests_status
  ON public.grievance_requests(status);

CREATE INDEX IF NOT EXISTS idx_grievance_requests_created_at
  ON public.grievance_requests(created_at DESC);

-- updated_at trigger
CREATE OR REPLACE FUNCTION public.set_grievance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_grievance_updated_at ON public.grievance_requests;
CREATE TRIGGER trg_grievance_updated_at
  BEFORE UPDATE ON public.grievance_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_grievance_updated_at();

-- RLS: users can submit and view their own requests; admins manage all
ALTER TABLE public.grievance_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own grievance requests"
  ON public.grievance_requests
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can submit grievance requests"
  ON public.grievance_requests
  FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);


-- ============================================================================
-- 4. RPC: log_consent_event
--    Called server-side to record consent changes with tamper-proof timestamps.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.log_consent_event(
  p_user_id     UUID,
  p_event_type  TEXT,
  p_detail      JSONB    DEFAULT '{}',
  p_country     CHAR(2)  DEFAULT NULL,
  p_ip_hash     TEXT     DEFAULT NULL,
  p_user_agent  TEXT     DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.consent_audit_log (
    user_id, event_type, event_detail, country_code, ip_hash, user_agent
  )
  VALUES (
    p_user_id, p_event_type, p_detail, p_country, p_ip_hash, p_user_agent
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.log_consent_event
  IS 'Server-side only. Appends an immutable consent event to consent_audit_log.';


-- ============================================================================
-- 5. RPC: check_stale_grievances
--    Scheduled via pg_cron to flag requests approaching SLA deadlines.
--    Acknowledgement SLA: 48 hours. Resolution SLA: 30 days.
--
--    Example cron:
--    SELECT cron.schedule('grievance-sla-check', '0 */6 * * *',
--           'SELECT public.check_stale_grievances()');
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_stale_grievances()
RETURNS TABLE(id UUID, email TEXT, hours_open NUMERIC, sla_breach TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT
    gr.id,
    gr.email,
    ROUND(EXTRACT(EPOCH FROM (now() - gr.created_at)) / 3600, 1) AS hours_open,
    CASE
      WHEN gr.acknowledged_at IS NULL AND gr.created_at < now() - INTERVAL '48 hours'
        THEN 'ACKNOWLEDGEMENT_OVERDUE'
      WHEN gr.resolved_at IS NULL AND gr.created_at < now() - INTERVAL '28 days'
        THEN 'RESOLUTION_DUE_SOON'
      WHEN gr.resolved_at IS NULL AND gr.created_at < now() - INTERVAL '30 days'
        THEN 'RESOLUTION_OVERDUE'
      ELSE 'OK'
    END AS sla_breach
  FROM public.grievance_requests gr
  WHERE gr.status NOT IN ('resolved', 'closed')
    AND (
      gr.acknowledged_at IS NULL AND gr.created_at < now() - INTERVAL '48 hours'
      OR gr.resolved_at IS NULL AND gr.created_at < now() - INTERVAL '28 days'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.check_stale_grievances
  IS 'Returns grievance requests approaching or past DPDPA SLA deadlines. Run every 6 hours via pg_cron.';
