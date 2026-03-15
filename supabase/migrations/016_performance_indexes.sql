-- Migration 016: Performance indexes for scale
-- These indexes are critical for sub-200ms query times at 100K+ users.

-- Timeline pagination: user's entries sorted by date (the most frequent query)
CREATE INDEX IF NOT EXISTS idx_entries_user_date
  ON journal_entries(user_id, entry_date DESC);

-- Sync & incremental backup: find entries changed since last sync
CREATE INDEX IF NOT EXISTS idx_entries_user_updated
  ON journal_entries(user_id, updated_at DESC);

-- On This Day feature: find entries matching a specific month+day
CREATE INDEX IF NOT EXISTS idx_entries_anniversary
  ON journal_entries(user_id, EXTRACT(MONTH FROM entry_date), EXTRACT(DAY FROM entry_date));

-- Mood filtering: timeline filtered by mood
CREATE INDEX IF NOT EXISTS idx_entries_user_mood
  ON journal_entries(user_id, mood, entry_date DESC);

-- Media lookup by entry (JOIN queries on detail view)
CREATE INDEX IF NOT EXISTS idx_media_entry
  ON entry_media(entry_id);

-- Media lookup by user (user's media gallery)
CREATE INDEX IF NOT EXISTS idx_media_user
  ON entry_media(user_id, created_at DESC);

-- Chapter membership lookup
CREATE INDEX IF NOT EXISTS idx_chapters_user
  ON chapters(user_id, created_at DESC);

-- Books by user
CREATE INDEX IF NOT EXISTS idx_books_user
  ON books(user_id, created_at DESC);

-- Streak lookup (one per user, queried on every app open)
CREATE INDEX IF NOT EXISTS idx_streaks_user
  ON streaks(user_id);

-- Idempotency: prevent duplicate sync operations (see sync_queue changes)
-- This unique partial index allows the server to reject duplicate writes.
CREATE UNIQUE INDEX IF NOT EXISTS idx_entries_idempotency
  ON journal_entries(id, user_id);
