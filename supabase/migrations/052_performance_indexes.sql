-- Migration 052: Performance indexes for all primary query patterns
-- All indexes use IF NOT EXISTS for idempotency.

-- =============================================================================
-- journal_entries
-- =============================================================================

-- Primary listing: entries by user ordered by date (home screen, timeline)
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_date
  ON public.journal_entries(user_id, entry_date DESC);

-- Chapter filtering: entries belonging to a chapter
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_chapter
  ON public.journal_entries(user_id, chapter_id) WHERE chapter_id IS NOT NULL;

-- Mood queries: mood stats, mood filtering
CREATE INDEX IF NOT EXISTS idx_journal_entries_user_mood
  ON public.journal_entries(user_id, entry_date) WHERE mood IS NOT NULL;

-- Sync: entries updated since last sync timestamp
CREATE INDEX IF NOT EXISTS idx_journal_entries_updated
  ON public.journal_entries(user_id, updated_at DESC);

-- =============================================================================
-- entry_media
-- =============================================================================

-- Media lookup by parent entry
CREATE INDEX IF NOT EXISTS idx_entry_media_entry
  ON public.entry_media(entry_id);

-- =============================================================================
-- check_in_conversations
-- =============================================================================

-- Check-in history by user and date
CREATE INDEX IF NOT EXISTS idx_checkin_user_date
  ON public.check_in_conversations(user_id, date_key DESC);

-- =============================================================================
-- memory_shares
-- =============================================================================

-- Token-based share lookup (used by edge function / share links)
CREATE INDEX IF NOT EXISTS idx_memory_shares_token
  ON public.memory_shares(token) WHERE token IS NOT NULL;

-- Shares sent by a user, ordered by recency
CREATE INDEX IF NOT EXISTS idx_memory_shares_sharer
  ON public.memory_shares(sharer_id, created_at DESC);

-- Shares received by a user
CREATE INDEX IF NOT EXISTS idx_memory_shares_recipient
  ON public.memory_shares(recipient_id) WHERE recipient_id IS NOT NULL;

-- Shares for a specific memory (check if entry has been shared)
CREATE INDEX IF NOT EXISTS idx_memory_shares_memory
  ON public.memory_shares(memory_id);

-- =============================================================================
-- books
-- =============================================================================

-- User's book library ordered by creation
CREATE INDEX IF NOT EXISTS idx_books_user
  ON public.books(user_id, created_at DESC);

-- =============================================================================
-- pages
-- =============================================================================

-- Pages within a book, ordered by week and page number
CREATE INDEX IF NOT EXISTS idx_pages_book_week
  ON public.pages(book_id, week_start, page_number);

-- All pages owned by a user (for sync / cleanup)
CREATE INDEX IF NOT EXISTS idx_pages_user
  ON public.pages(user_id);

-- =============================================================================
-- chapters
-- =============================================================================

-- Chapters by user ordered by number
CREATE INDEX IF NOT EXISTS idx_chapters_user_number
  ON public.chapters(user_id, chapter_number);

-- =============================================================================
-- drafts
-- =============================================================================

-- User's drafts ordered by last update
CREATE INDEX IF NOT EXISTS idx_drafts_user
  ON public.drafts(user_id, updated_at DESC);

-- =============================================================================
-- reflection_cache
-- =============================================================================

-- Reflection lookup by user, period type, and key
CREATE INDEX IF NOT EXISTS idx_reflection_cache_user_period
  ON public.reflection_cache(user_id, period, period_key);

-- =============================================================================
-- remote_config
-- =============================================================================

-- Config lookup by key and platform
CREATE INDEX IF NOT EXISTS idx_remote_config_key
  ON public.remote_config(key, platform);

-- =============================================================================
-- CASCADE delete: entry_media → journal_entries
-- Add ON DELETE CASCADE if the FK exists but lacks it, or add the full FK.
-- =============================================================================

DO $$
DECLARE
  fk_name TEXT;
BEGIN
  -- Find the existing FK constraint name (if any)
  SELECT conname INTO fk_name
  FROM pg_constraint
  WHERE conrelid = 'public.entry_media'::regclass
    AND confrelid = 'public.journal_entries'::regclass
    AND contype = 'f'
  LIMIT 1;

  IF fk_name IS NOT NULL THEN
    -- Drop existing FK and re-create with CASCADE
    EXECUTE format('ALTER TABLE public.entry_media DROP CONSTRAINT %I', fk_name);
    ALTER TABLE public.entry_media
      ADD CONSTRAINT entry_media_entry_id_fkey
      FOREIGN KEY (entry_id) REFERENCES public.journal_entries(id) ON DELETE CASCADE;
    RAISE NOTICE 'Replaced FK % with CASCADE version', fk_name;
  ELSE
    -- No FK exists yet — create it
    ALTER TABLE public.entry_media
      ADD CONSTRAINT entry_media_entry_id_fkey
      FOREIGN KEY (entry_id) REFERENCES public.journal_entries(id) ON DELETE CASCADE;
    RAISE NOTICE 'Created new FK entry_media_entry_id_fkey with CASCADE';
  END IF;
END;
$$;
