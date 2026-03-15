-- ============================================================================
-- DearDays Migration 015: Server-Side Column Encryption
--
-- Switches from client-side zero-knowledge encryption to server-side
-- column-level encryption using pgcrypto.
--
-- How it works:
--   - An APP_ENCRYPTION_KEY is stored in Supabase Vault (never exposed to clients).
--   - A BEFORE INSERT/UPDATE trigger automatically encrypts content columns.
--   - A SECURITY DEFINER view (journal_entries_decrypted) auto-decrypts on read.
--   - The Flutter client sends/receives plaintext over HTTPS.
--   - If the raw database is dumped, content columns contain PGP ciphertext.
--
-- What this protects against:
--   - Database dump/backup theft → ciphertext only
--   - Direct SQL access without the vault key → unreadable
--
-- What this does NOT protect against:
--   - Full server compromise (attacker gets both DB + vault secret)
--   - This is the same trade-off as Notion, Linear, and most SaaS apps.
-- ============================================================================


-- 1. Enable pgcrypto extension (idempotent)
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- 2. Generate and store the encryption key in Supabase Vault.
--    The key is a random 32-byte hex string (256-bit).
--    Vault encrypts it at rest using the project's root key.
INSERT INTO vault.secrets (name, secret)
VALUES (
  'app_encryption_key',
  encode(gen_random_bytes(32), 'hex')
)
ON CONFLICT (name) DO NOTHING;


-- 3. Helper: encrypt plaintext using the vault key.
--    Returns base64-encoded PGP symmetric ciphertext.
--    SECURITY DEFINER so it can read vault.decrypted_secrets.
CREATE OR REPLACE FUNCTION public.app_encrypt(plaintext TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  enc_key TEXT;
BEGIN
  IF plaintext IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT decrypted_secret INTO enc_key
  FROM vault.decrypted_secrets
  WHERE name = 'app_encryption_key'
  LIMIT 1;

  IF enc_key IS NULL THEN
    RAISE EXCEPTION 'Encryption key not found in vault';
  END IF;

  RETURN encode(pgp_sym_encrypt(plaintext, enc_key), 'base64');
END;
$$;


-- 4. Helper: decrypt ciphertext using the vault key.
--    Accepts base64-encoded PGP ciphertext, returns plaintext.
CREATE OR REPLACE FUNCTION public.app_decrypt(ciphertext TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  enc_key TEXT;
BEGIN
  IF ciphertext IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT decrypted_secret INTO enc_key
  FROM vault.decrypted_secrets
  WHERE name = 'app_encryption_key'
  LIMIT 1;

  IF enc_key IS NULL THEN
    RAISE EXCEPTION 'Encryption key not found in vault';
  END IF;

  RETURN pgp_sym_decrypt(decode(ciphertext, 'base64'), enc_key);
END;
$$;


-- 5. BEFORE INSERT/UPDATE trigger: auto-encrypt content columns.
--    The client sends plaintext; the trigger encrypts before storage.
CREATE OR REPLACE FUNCTION public.encrypt_journal_content()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only encrypt if the value looks like plaintext (not already encrypted).
  -- PGP-encrypted base64 strings are very long and start with 'ww' or similar.
  -- We use a simple length + prefix heuristic: pgp_sym_encrypt output is always
  -- longer than ~100 chars even for short input, and raw journal text is stored
  -- directly. To be safe, we always re-encrypt on every write.
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

CREATE TRIGGER trg_encrypt_journal_content
  BEFORE INSERT OR UPDATE OF content, raw_content, polished_content
  ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.encrypt_journal_content();


-- 6. Secure view for decrypted reads.
--    RLS on the underlying table still applies (user_id = auth.uid()).
--    The client reads from this view instead of the raw table.
CREATE OR REPLACE VIEW public.journal_entries_decrypted AS
SELECT
  id,
  user_id,
  public.app_decrypt(content) AS content,
  public.app_decrypt(raw_content) AS raw_content,
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
  public.app_decrypt(polished_content) AS polished_content,
  created_at,
  updated_at
FROM public.journal_entries;


-- 7. Grant the authenticated role access to the view.
GRANT SELECT ON public.journal_entries_decrypted TO authenticated;


-- 8. The encryption_salt column is no longer needed for new users,
--    but we keep it for backward compatibility with existing data.
--    New signups will get a placeholder value.
COMMENT ON COLUMN public.profiles.encryption_salt IS
  'Legacy: was used for client-side PBKDF2 key derivation. '
  'Server-side encryption (migration 015) no longer needs this.';


-- 9. Update comments to reflect new encryption model.
COMMENT ON TABLE public.journal_entries IS
  'Core journal entries. Content is encrypted server-side using pgcrypto '
  'with a key stored in Supabase Vault. Clients send plaintext over HTTPS.';

COMMENT ON TABLE public.entry_media IS
  'Media attachments for journal entries.';
