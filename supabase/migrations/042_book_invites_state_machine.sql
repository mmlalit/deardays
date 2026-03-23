-- Migration 042: Enforce valid status transitions on book_invites via
-- CHECK constraint + BEFORE UPDATE trigger.
--
-- Without this, any UPDATE could set status to an arbitrary string or
-- skip required fields (e.g. accepted_at when status='accepted').
-- ============================================================================

-- 1. Add CHECK constraint for valid status values.
ALTER TABLE public.book_invites
  DROP CONSTRAINT IF EXISTS book_invites_status_check;

ALTER TABLE public.book_invites
  ADD CONSTRAINT book_invites_status_check
  CHECK (status IN ('pending', 'accepted', 'expired', 'revoked'));

-- 2. Trigger function: enforce valid transitions and required fields.
CREATE OR REPLACE FUNCTION public.enforce_book_invite_state_machine()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Guard: only enforce on actual status changes.
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  -- Valid transitions:
  --   pending  → accepted | expired | revoked
  --   accepted → revoked
  --   expired  → (no further transitions)
  --   revoked  → (no further transitions)
  IF OLD.status = 'pending' AND NEW.status NOT IN ('accepted', 'expired', 'revoked') THEN
    RAISE EXCEPTION 'book_invites: invalid transition % → %', OLD.status, NEW.status;
  END IF;
  IF OLD.status = 'accepted' AND NEW.status != 'revoked' THEN
    RAISE EXCEPTION 'book_invites: invalid transition % → %', OLD.status, NEW.status;
  END IF;
  IF OLD.status IN ('expired', 'revoked') THEN
    RAISE EXCEPTION 'book_invites: terminal status % cannot be changed', OLD.status;
  END IF;

  -- Required fields for each target status.
  IF NEW.status = 'accepted' AND NEW.accepted_by IS NULL THEN
    RAISE EXCEPTION 'book_invites: accepted_by must be set when status=accepted';
  END IF;
  IF NEW.status = 'accepted' AND NEW.accepted_at IS NULL THEN
    NEW.accepted_at := now();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_book_invite_state_machine ON public.book_invites;
CREATE TRIGGER trg_book_invite_state_machine
  BEFORE UPDATE ON public.book_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_book_invite_state_machine();
