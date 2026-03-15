-- Server-side mood aggregation RPCs to eliminate unbounded row fetching.
--
-- Previously the client fetched ALL mood rows and counted in Dart.
-- At scale (10K+ entries per user), this wastes bandwidth and memory.
-- These RPCs do the COUNT on Postgres where it belongs.

-- 1. Overall mood distribution for the current user.
CREATE OR REPLACE FUNCTION get_mood_stats(p_user_id UUID)
RETURNS TABLE(mood TEXT, count BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT je.mood, COUNT(*) AS count
  FROM journal_entries je
  WHERE je.user_id = p_user_id
    AND je.mood IS NOT NULL
  GROUP BY je.mood;
$$;

-- 2. Mood distribution within a date range.
CREATE OR REPLACE FUNCTION get_mood_stats_by_range(
  p_user_id UUID,
  p_start DATE,
  p_end DATE
)
RETURNS TABLE(mood TEXT, count BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT je.mood, COUNT(*) AS count
  FROM journal_entries je
  WHERE je.user_id = p_user_id
    AND je.entry_date >= p_start
    AND je.entry_date <= p_end
    AND je.mood IS NOT NULL
  GROUP BY je.mood;
$$;

-- 3. Fix chapters index to match query ordering (chapter_number, not created_at).
CREATE INDEX IF NOT EXISTS idx_chapters_user_number
  ON chapters(user_id, chapter_number ASC);
