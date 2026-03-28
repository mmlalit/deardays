-- ============================================================================
-- Migration 052: Performance indexes for load testing / production readiness
--
-- Load test results (2026-03-28, 1000 VUs):
--   - Timeline reads p95: 7s → target < 500ms
--   - Search p95: 7.3s → target < 1s
--   - All endpoints p50 ~1.4s → target < 300ms
--
-- These indexes address the top bottlenecks.
-- ============================================================================

-- 1. Covering index for timeline reads
--    Query: SELECT id,content,mood,entry_date,has_photo,has_voice,word_count
--           FROM journal_entries WHERE user_id=X ORDER BY entry_date DESC LIMIT 20
--    INCLUDE columns let Postgres answer from the index without touching the heap.
CREATE INDEX IF NOT EXISTS idx_entries_timeline_cover
  ON journal_entries(user_id, entry_date DESC)
  INCLUDE (id, content, mood, has_photo, has_voice, word_count);

-- 2. Trigram index for keyword search (ilike '%keyword%')
--    Without this, ilike does a sequential scan on every row.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_entries_content_trgm
  ON journal_entries
  USING gin (content gin_trgm_ops);

-- 3. Covering index for profile reads
--    Query: SELECT id,display_name,writing_style,is_subscribed,reminder_time
--           FROM profiles WHERE id=X
--    PK already covers id, but INCLUDE avoids heap fetch for common columns.
CREATE INDEX IF NOT EXISTS idx_profiles_cover
  ON profiles(id)
  INCLUDE (display_name, writing_style, is_subscribed, reminder_time);

-- 4. Covering index for chapters list
--    Query: SELECT id,title,color,created_at FROM chapters WHERE user_id=X ORDER BY created_at
CREATE INDEX IF NOT EXISTS idx_chapters_user_cover
  ON chapters(user_id, created_at ASC)
  INCLUDE (id, title, color);

-- 5. Refresh table statistics so the query planner uses these new indexes
ANALYZE journal_entries;
ANALYZE profiles;
ANALYZE chapters;
