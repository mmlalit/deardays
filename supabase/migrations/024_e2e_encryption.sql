-- Migration 024: Opt-in client-side end-to-end encryption.
--
-- Adds fields to track E2E state on the profile, and an is_client_encrypted
-- flag on journal_entries so the server-side trigger knows to skip its own
-- encryption layer when the client has already encrypted the content.
--
-- Security model:
--   - When e2e_enabled = TRUE, the Flutter client derives a key from the
--     user's passphrase (PBKDF2 + HMAC-SHA256, 100k iterations) and encrypts
--     content client-side using AES-256-GCM before sending to Supabase.
--   - is_client_encrypted = TRUE tells the server trigger to store the content
--     as-is (ciphertext already applied) rather than double-encrypting.
--   - The journal_entries_decrypted view returns raw content for client-
--     encrypted rows — the Flutter client decrypts locally.
--   - e2e_salt is a random 16-byte base64 string; it is NOT secret. It is
--     stored here so the client can re-derive the key on any device.
--   - e2e_consent_given_at records when the user acknowledged the
--     no-recovery warning. e2e_enabled_at records when migration completed.

-- 1. Profile columns for E2E state
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS e2e_enabled          BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS e2e_salt             TEXT,
  ADD COLUMN IF NOT EXISTS e2e_consent_given_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS e2e_enabled_at       TIMESTAMPTZ;

-- 2. Flag on journal_entries: set TRUE by the client when it sends ciphertext.
ALTER TABLE public.journal_entries
  ADD COLUMN IF NOT EXISTS is_client_encrypted BOOLEAN NOT NULL DEFAULT FALSE;

-- 3. Update the encrypt trigger to skip client-encrypted rows.
CREATE OR REPLACE FUNCTION public.encrypt_journal_content()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If the client already encrypted the content, skip server-side encryption.
  -- Applying app_encrypt() to ciphertext would produce double-encrypted garbage.
  IF NEW.is_client_encrypted THEN
    RETURN NEW;
  END IF;

  NEW.content := public.app_encrypt(NEW.content);

  IF NEW.raw_content IS NOT NULL THEN
    NEW.raw_content := public.app_encrypt(NEW.raw_content);
  END IF;

  IF NEW.polished_content IS NOT NULL THEN
    NEW.polished_content := public.app_encrypt(NEW.polished_content);
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Update the decrypted view to pass through content for client-encrypted rows.
-- Must DROP first: CREATE OR REPLACE cannot reorder or insert columns mid-list.
DROP VIEW IF EXISTS public.journal_entries_decrypted;

CREATE VIEW public.journal_entries_decrypted AS
SELECT
  id,
  user_id,
  CASE
    WHEN is_client_encrypted THEN content
    ELSE public.app_decrypt(content)
  END AS content,
  CASE
    WHEN is_client_encrypted THEN raw_content
    ELSE public.app_decrypt(raw_content)
  END AS raw_content,
  mood,
  entry_date,
  entry_time,
  location_name,
  latitude,
  longitude,
  has_photo,
  has_voice,
  is_ai_polished,
  is_milestone,
  milestone_type,
  word_count,
  CASE
    WHEN is_client_encrypted THEN polished_content
    ELSE public.app_decrypt(polished_content)
  END AS polished_content,
  created_at,
  updated_at,
  -- New columns added after existing ones to satisfy CREATE OR REPLACE rules.
  is_client_encrypted,
  chapter_id
FROM public.journal_entries;

GRANT SELECT ON public.journal_entries_decrypted TO authenticated;

COMMENT ON COLUMN public.profiles.e2e_enabled IS
  'TRUE when the user has opted into client-side E2E encryption. '
  'Content columns in journal_entries will have is_client_encrypted=TRUE.';

COMMENT ON COLUMN public.profiles.e2e_salt IS
  'Random 16-byte base64 salt used for PBKDF2 key derivation. '
  'Not secret — safe to store in plaintext.';

COMMENT ON COLUMN public.profiles.e2e_consent_given_at IS
  'Timestamp when the user acknowledged the no-recovery risk warning.';

COMMENT ON COLUMN public.profiles.e2e_enabled_at IS
  'Timestamp when the E2E migration of existing entries completed.';

COMMENT ON COLUMN public.journal_entries.is_client_encrypted IS
  'TRUE when the Flutter client has AES-256-GCM encrypted the content '
  'columns before upload. The server trigger skips encryption for these rows.';
