-- ============================================================================
-- DearDays: Migration 003 — Add preferred language field
-- ============================================================================

-- Store the user's preferred language for AI responses.
-- Defaults to NULL which means "system default / auto-detect".
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS preferred_language TEXT;
