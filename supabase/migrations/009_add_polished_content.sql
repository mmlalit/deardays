-- ============================================================================
-- DearDays: Migration 009 — Add polished_content column
-- ============================================================================
-- Stores the AI literary narrative separately from the light-polished content.
--
-- Three-tier content model:
--   raw_content      → exactly what the user typed/spoke
--   content          → light polish (grammar, spelling, readability)
--   polished_content → full AI literary narrative for the Book

ALTER TABLE public.journal_entries
  ADD COLUMN IF NOT EXISTS polished_content TEXT;

COMMENT ON COLUMN public.journal_entries.polished_content IS
  'AI-generated literary narrative (memoir/poetic style). NULL if not yet polished.';
