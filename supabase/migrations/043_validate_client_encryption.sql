-- Migration 043: Add a trigger to validate that client-encrypted content
-- is valid base64 before storage.
--
-- If a client sets is_client_encrypted=true but sends plaintext or malformed
-- base64, the data would be silently stored unencrypted — a data-integrity bug.
-- This trigger catches that at the DB layer.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_client_encrypted_content()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only check rows marked as client-encrypted.
  IF NEW.is_client_encrypted IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  -- content must be non-null and at least 24 chars (12-byte IV + some ciphertext, base64).
  -- We cannot verify the base64 alphabet exhaustively in plpgsql without extensions,
  -- but a minimum-length check catches common mistakes.
  IF NEW.content IS NULL OR length(NEW.content) < 24 THEN
    RAISE EXCEPTION
      'journal_entries: is_client_encrypted=true but content appears invalid '
      '(too short or null). Expected base64-encoded AES-GCM ciphertext.';
  END IF;

  -- The content must not look like readable plaintext (heuristic: valid base64
  -- consists only of A-Z, a-z, 0-9, +, /, = characters).
  -- This catches the most common bug: client forgot to encrypt before saving.
  IF NEW.content ~ '[^A-Za-z0-9+/=]' THEN
    RAISE EXCEPTION
      'journal_entries: is_client_encrypted=true but content contains '
      'non-base64 characters. Ensure content is AES-GCM encrypted.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_client_encrypted ON public.journal_entries;
CREATE TRIGGER trg_validate_client_encrypted
  BEFORE INSERT OR UPDATE OF content, is_client_encrypted
  ON public.journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_client_encrypted_content();
