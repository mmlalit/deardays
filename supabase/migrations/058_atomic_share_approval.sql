-- Migration 058: Atomic share approval RPC
--
-- Replaces the two-step share approval (update memory_shares + update profiles)
-- with a single atomic transaction to prevent race conditions.

CREATE OR REPLACE FUNCTION approve_share_request(
  p_share_id UUID,
  p_sharer_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient_id UUID;
BEGIN
  -- Update share status and get recipient_id in one step
  UPDATE memory_shares
  SET status = 'approved',
      approved_at = NOW()
  WHERE id = p_share_id
    AND sharer_id = p_sharer_id
  RETURNING recipient_id INTO v_recipient_id;

  IF v_recipient_id IS NULL THEN
    RAISE EXCEPTION 'Share not found or not owned by current user';
  END IF;

  -- Flag recipient's profile atomically in the same transaction
  UPDATE profiles
  SET has_received_share = TRUE
  WHERE id = v_recipient_id;
END;
$$;

-- Deny doesn't need the profile update, but wrap in RPC for consistency
CREATE OR REPLACE FUNCTION deny_share_request(
  p_share_id UUID,
  p_sharer_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE memory_shares
  SET status = 'denied'
  WHERE id = p_share_id
    AND sharer_id = p_sharer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Share not found or not owned by current user';
  END IF;
END;
$$;
