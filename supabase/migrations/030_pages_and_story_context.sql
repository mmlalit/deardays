-- ============================================================
-- Migration 030: pages + story_context tables
-- pages      — generated book pages (one or more per week per chapter)
-- story_context — continuity handoff between weekly page generations
-- ============================================================

-- ------------------------------------------------------------
-- pages
-- Each row = one rendered page in the book.
-- source = 'weekly_job' | 'manual' (future: user-triggered regen)
-- status = 'draft' (individual memory stories, pre-Saturday)
--        | 'published' (woven narrative from Saturday job)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chapter_id    UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  book_id       UUID NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,

  -- Week this page belongs to (Monday of the week, UTC)
  week_start    DATE NOT NULL,

  -- Page ordering within the chapter
  page_number   INT NOT NULL,

  -- The rendered narrative text (HTML or plain paragraphs)
  content       TEXT NOT NULL,

  word_count    INT NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published')),
  source        TEXT NOT NULL DEFAULT 'weekly_job' CHECK (source IN ('weekly_job', 'manual')),

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (chapter_id, week_start, page_number)
);

-- ------------------------------------------------------------
-- story_context
-- Stores the narrative handoff from the last page of each week
-- so the next Saturday job can maintain continuity.
-- One row per (user, chapter) — upserted after each job run.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.story_context (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chapter_id    UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,

  -- Last 2-3 sentences of the most recent page
  last_line     TEXT NOT NULL DEFAULT '',

  -- JSON arrays for continuity context
  people        JSONB NOT NULL DEFAULT '[]',   -- ["Mum", "Jake", ...]
  active_threads JSONB NOT NULL DEFAULT '[]',  -- ["job interview", "holiday planning", ...]

  -- Which week this context was generated from
  last_week_start DATE,

  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (user_id, chapter_id)
);

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_context ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pages_owner" ON public.pages
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "story_context_owner" ON public.story_context
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Indexes
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS pages_user_chapter_idx  ON public.pages (user_id, chapter_id, week_start);
CREATE INDEX IF NOT EXISTS pages_book_number_idx   ON public.pages (book_id, page_number);
CREATE INDEX IF NOT EXISTS story_context_chapter_idx ON public.story_context (chapter_id);

-- ------------------------------------------------------------
-- Auto-update updated_at
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER pages_updated_at
  BEFORE UPDATE ON public.pages
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER story_context_updated_at
  BEFORE UPDATE ON public.story_context
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
