-- Migration 057: Add encrypted_location column for E2E location privacy
--
-- When E2E encryption is enabled, latitude/longitude are stored as an
-- encrypted JSON blob in this column, and the plaintext lat/lng columns
-- are set to NULL. On read, the client decrypts and restores the values.
--
-- Column format (plaintext before encryption): {"lat": 40.7128, "lng": -74.0060}

ALTER TABLE journal_entries
  ADD COLUMN IF NOT EXISTS encrypted_location TEXT;

COMMENT ON COLUMN journal_entries.encrypted_location IS
  'E2E encrypted JSON {lat,lng} — populated only when is_client_encrypted=true';
