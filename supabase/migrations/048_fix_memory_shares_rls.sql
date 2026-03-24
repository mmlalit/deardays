-- Migration 048: Fix memory_shares RLS — remove public SELECT policy
-- The USING(true) policy allowed any unauthenticated caller to read all share rows.
-- Token validation is now handled by the Edge Function using service-role client.

-- Remove the overly permissive policy
DROP POLICY IF EXISTS "Token bearer can read share" ON public.memory_shares;

-- Create a secure token lookup function (SECURITY DEFINER, validates token server-side)
CREATE OR REPLACE FUNCTION public.get_share_by_token(p_token UUID)
RETURNS TABLE (
  id UUID, token UUID, memory_id UUID, sharer_id UUID,
  recipient_id UUID, recipient_name TEXT, status TEXT,
  created_at TIMESTAMPTZ, expires_at TIMESTAMPTZ, view_count INTEGER
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT ms.id, ms.token, ms.memory_id, ms.sharer_id,
         ms.recipient_id, ms.recipient_name, ms.status,
         ms.created_at, ms.expires_at, ms.view_count
  FROM memory_shares ms
  WHERE ms.token = p_token
    AND ms.expires_at > now()
    AND ms.status IN ('pending', 'approved');
END;
$$;

-- Allow unauthenticated callers to invoke this function (token is unguessable UUID)
GRANT EXECUTE ON FUNCTION public.get_share_by_token(UUID) TO anon, authenticated;
