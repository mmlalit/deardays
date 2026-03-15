-- Migration 025: Memory Tagging
-- Adds AI-generated semantic metadata and vector embeddings to journal entries
-- for conversational search. All columns are nullable and populated asynchronously
-- by the ai-tag edge function after entry creation.

-- ----------------------------------------------------------------
-- 0. Enable pgvector extension (required for vector type and HNSW index)
-- ----------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS vector;

-- ----------------------------------------------------------------
-- 1. Extend journal_entries with tagging columns
-- ----------------------------------------------------------------

ALTER TABLE public.journal_entries
  ADD COLUMN IF NOT EXISTS sentiment_score  FLOAT,        -- -1.0 (very negative) to 1.0 (very positive)
  ADD COLUMN IF NOT EXISTS emotion          TEXT,         -- primary emotion: joy, sadness, anxiety, gratitude, anger, neutral, etc.
  ADD COLUMN IF NOT EXISTS tags             TEXT[],       -- general topic tags, e.g. ['work', 'family', 'travel']
  ADD COLUMN IF NOT EXISTS people           TEXT[],       -- people mentioned, e.g. ['Mom', 'John']
  ADD COLUMN IF NOT EXISTS activities       TEXT[],       -- activities, e.g. ['hiking', 'cooking', 'reading']
  ADD COLUMN IF NOT EXISTS extracted_locations TEXT[],   -- locations extracted from text (distinct from GPS location_name)
  ADD COLUMN IF NOT EXISTS topics           TEXT[],       -- abstract topics, e.g. ['loss', 'ambition', 'connection']
  ADD COLUMN IF NOT EXISTS embedding        vector(1536),  -- OpenAI text-embedding-3-small (1536-dim)
  ADD COLUMN IF NOT EXISTS tags_generated   BOOLEAN NOT NULL DEFAULT FALSE; -- true after ai-tag runs

-- ----------------------------------------------------------------
-- 2. Indexes for fast filtered queries
-- ----------------------------------------------------------------

-- GIN index for array containment queries (@> operator)
CREATE INDEX IF NOT EXISTS idx_journal_entries_tags
  ON public.journal_entries USING GIN (tags);

CREATE INDEX IF NOT EXISTS idx_journal_entries_people
  ON public.journal_entries USING GIN (people);

CREATE INDEX IF NOT EXISTS idx_journal_entries_activities
  ON public.journal_entries USING GIN (activities);

CREATE INDEX IF NOT EXISTS idx_journal_entries_emotion
  ON public.journal_entries (user_id, emotion)
  WHERE emotion IS NOT NULL;

-- HNSW index for fast approximate nearest-neighbor vector search
-- m=16, ef_construction=64 are good defaults for moderate dataset sizes
CREATE INDEX IF NOT EXISTS idx_journal_entries_embedding
  ON public.journal_entries USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Composite index for filtering untagged entries (used by the tagging backfill)
CREATE INDEX IF NOT EXISTS idx_journal_entries_tags_generated
  ON public.journal_entries (user_id, tags_generated)
  WHERE tags_generated = FALSE;

-- ----------------------------------------------------------------
-- 3. RPC: vector similarity search
-- Returns entry IDs ordered by cosine similarity to the query embedding.
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.search_entries_by_embedding(
  p_user_id     UUID,
  p_embedding   vector(1536),
  p_limit       INT DEFAULT 20,
  p_threshold   FLOAT DEFAULT 0.65
)
RETURNS TABLE (id UUID, similarity FLOAT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    je.id,
    1 - (je.embedding <=> p_embedding) AS similarity
  FROM public.journal_entries je
  WHERE je.user_id = p_user_id
    AND je.embedding IS NOT NULL
    AND 1 - (je.embedding <=> p_embedding) >= p_threshold
  ORDER BY je.embedding <=> p_embedding
  LIMIT p_limit;
END;
$$;

-- ----------------------------------------------------------------
-- 4. RPC: SQL filter search (mood / emotion / year / tags / people)
-- Used as the fast pre-filter before optional vector reranking.
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.search_entries_by_filters(
  p_user_id         UUID,
  p_mood            TEXT     DEFAULT NULL,
  p_emotion         TEXT     DEFAULT NULL,
  p_year            INT      DEFAULT NULL,
  p_tags            TEXT[]   DEFAULT NULL,
  p_people          TEXT[]   DEFAULT NULL,
  p_activities      TEXT[]   DEFAULT NULL,
  p_start_date      DATE     DEFAULT NULL,
  p_end_date        DATE     DEFAULT NULL,
  p_limit           INT      DEFAULT 50
)
RETURNS TABLE (id UUID, entry_date DATE, mood TEXT, emotion TEXT, sentiment_score FLOAT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    je.id,
    je.entry_date::DATE,
    je.mood,
    je.emotion,
    je.sentiment_score
  FROM public.journal_entries je
  WHERE je.user_id = p_user_id
    AND (p_mood        IS NULL OR je.mood     = p_mood)
    AND (p_emotion     IS NULL OR je.emotion  = p_emotion)
    AND (p_year        IS NULL OR EXTRACT(YEAR FROM je.entry_date) = p_year)
    AND (p_tags        IS NULL OR je.tags     @> p_tags)
    AND (p_people      IS NULL OR je.people   @> p_people)
    AND (p_activities  IS NULL OR je.activities @> p_activities)
    AND (p_start_date  IS NULL OR je.entry_date >= p_start_date)
    AND (p_end_date    IS NULL OR je.entry_date <= p_end_date)
  ORDER BY je.entry_date DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.search_entries_by_embedding TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_entries_by_filters   TO authenticated;
