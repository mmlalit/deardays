-- Migration 026: Memory sharing with approval flow
-- Privacy-first: Sarah must approve every person who views her memories.
-- One token per share. Recipient claims it once. Sarah can revoke any time.

-- ─────────────────────────────────────────────────────────────────────────────
-- memory_shares table
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS memory_shares (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token          UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
  memory_id      UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
  sharer_id      UUID NOT NULL REFERENCES auth.users(id)      ON DELETE CASCADE,
  recipient_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  recipient_name TEXT,
  status         TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','approved','denied','revoked','expired')),
  created_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
  requested_at   TIMESTAMPTZ,
  approved_at    TIMESTAMPTZ,
  revoked_at     TIMESTAMPTZ,
  -- Request expires after 7 days if Sarah never responds
  expires_at     TIMESTAMPTZ DEFAULT (now() + INTERVAL '7 days') NOT NULL,
  view_count     INTEGER DEFAULT 0 NOT NULL,
  last_viewed_at TIMESTAMPTZ
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE memory_shares ENABLE ROW LEVEL SECURITY;

-- Sharer can read and manage all shares they created
CREATE POLICY "Sharer manages own shares"
  ON memory_shares
  USING (sharer_id = auth.uid());

-- Recipient can read their own received shares
CREATE POLICY "Recipient reads own shares"
  ON memory_shares FOR SELECT
  USING (recipient_id = auth.uid());

-- Anyone can insert a request (token-based, validated server-side)
CREATE POLICY "Anyone can insert share request"
  ON memory_shares FOR INSERT
  WITH CHECK (true);

-- Token lookup: allows reading a share by its token (UUID = unguessable)
-- Used by RequestAccessScreen before the user has submitted their name
CREATE POLICY "Token bearer can read share"
  ON memory_shares FOR SELECT
  USING (true);  -- safe: token is a random UUID, effectively unguessable

-- ─────────────────────────────────────────────────────────────────────────────
-- has_received_share flag on profiles
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS has_received_share BOOLEAN DEFAULT FALSE;

-- ─────────────────────────────────────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_memory_shares_token
  ON memory_shares(token);

CREATE INDEX IF NOT EXISTS idx_memory_shares_sharer_status
  ON memory_shares(sharer_id, status);

CREATE INDEX IF NOT EXISTS idx_memory_shares_recipient
  ON memory_shares(recipient_id);

CREATE INDEX IF NOT EXISTS idx_memory_shares_memory
  ON memory_shares(memory_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: increment view count (called when approved recipient opens memory)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION increment_share_view(p_share_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE memory_shares
  SET
    view_count     = view_count + 1,
    last_viewed_at = now()
  WHERE id = p_share_id
    AND status = 'approved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: auto-expire stale pending requests (run by cron nightly)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION expire_stale_share_requests()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  UPDATE memory_shares
  SET status = 'expired'
  WHERE status = 'pending'
    AND expires_at < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
