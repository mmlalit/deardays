-- Migration 021: Link journal entries to chapters + seed default chapters
-- Adds chapter_id FK on journal_entries and provides an RPC to seed defaults.

-- 1. Add chapter_id column to journal_entries
ALTER TABLE journal_entries ADD COLUMN IF NOT EXISTS chapter_id UUID REFERENCES chapters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_entries_chapter ON journal_entries(chapter_id);

-- 2. RPC: seed 4 default chapters for a user (no-op if they already have chapters)
CREATE OR REPLACE FUNCTION seed_default_chapters(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only seed if user has zero chapters
  IF EXISTS (SELECT 1 FROM chapters WHERE user_id = p_user_id LIMIT 1) THEN
    RETURN;
  END IF;

  INSERT INTO chapters (user_id, title, chapter_number, start_date, created_at)
  VALUES
    (p_user_id, 'Family',          1, CURRENT_DATE, now()),
    (p_user_id, 'Career',          2, CURRENT_DATE, now()),
    (p_user_id, 'Travel',          3, CURRENT_DATE, now()),
    (p_user_id, 'Personal Growth', 4, CURRENT_DATE, now());
END;
$$;

-- 3. RPC: get entry counts per chapter for a user
CREATE OR REPLACE FUNCTION get_chapter_entry_counts(p_user_id UUID)
RETURNS TABLE(chapter_id UUID, entry_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT je.chapter_id, COUNT(*) AS entry_count
  FROM journal_entries je
  WHERE je.user_id = p_user_id
    AND je.chapter_id IS NOT NULL
  GROUP BY je.chapter_id;
$$;
