-- Migration 044: Add missing performance indexes and optimize existing ones.
--
-- G5-M4: The timeline filter queries (by chapter_id, mood, or tag) require
-- full-index scans on idx_journal_entries_user_date when filtering is applied.
-- Partial composite indexes speed up the most common filter combinations.
-- ============================================================================

-- Index for chapter-filtered timeline (book reading screen, chapter detail).
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_chapter
  ON public.journal_entries (user_id, chapter_id, entry_date DESC)
  WHERE chapter_id IS NOT NULL;

-- Index for mood-filtered timeline (common filter in the UI).
-- Replaces the separate idx_journal_entries_user_mood from 001_initial_schema.sql
-- with a composite that also covers the sort column.
DROP INDEX IF EXISTS idx_journal_entries_user_mood;
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_mood_date
  ON public.journal_entries (user_id, mood, entry_date DESC)
  WHERE mood IS NOT NULL;

-- Index to accelerate the generation_queue worker poll query.
-- The worker queries: WHERE status='pending' AND week_start >= X ORDER BY priority, week_start
CREATE INDEX IF NOT EXISTS idx_generation_queue_pending
  ON public.generation_queue (status, priority DESC, week_start)
  WHERE status = 'pending';

COMMENT ON INDEX idx_journal_entries_user_chapter
  IS 'Covers chapter-filtered timeline queries (book reader, chapter detail screen).';
COMMENT ON INDEX idx_journal_entries_user_mood_date
  IS 'Covers mood-filtered timeline queries; replaces idx_journal_entries_user_mood.';
COMMENT ON INDEX idx_generation_queue_pending
  IS 'Covers the weekly page worker poll: pending items ordered by priority + week.';
