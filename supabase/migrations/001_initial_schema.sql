-- ============================================================================
-- DearDays: Privacy-First Life Journal
-- Migration 001: Initial Schema
--
-- Design principles:
--   - Zero-knowledge: all journal content is encrypted client-side (AES-256)
--   - Server stores encrypted blobs only, never plaintext
--   - Row Level Security on every table — no cross-user access
--   - Minimal columns, efficient indexing for low cost
-- ============================================================================


-- ============================================================================
-- 1. UTILITY: Auto-update updated_at trigger function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- profiles: extends Supabase auth.users
-- --------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id                     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name           TEXT,
  avatar_url             TEXT,
  encryption_salt        TEXT NOT NULL,              -- used client-side to derive the encryption key
  writing_style          TEXT DEFAULT 'memoir'
                           CHECK (writing_style IN ('memoir', 'diary', 'story')),
  reminder_time          TIME DEFAULT '20:30',
  biometric_enabled      BOOLEAN DEFAULT false,
  trial_started_at       TIMESTAMPTZ DEFAULT now(),
  is_subscribed          BOOLEAN DEFAULT false,
  subscription_plan      TEXT CHECK (subscription_plan IN ('monthly', 'yearly')),
  subscription_expires_at TIMESTAMPTZ,
  created_at             TIMESTAMPTZ DEFAULT now(),
  updated_at             TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User profile extending auth.users. encryption_salt is for client-side key derivation.';

-- --------------------------------------------------------------------------
-- journal_entries: core table — stores encrypted content blobs
-- --------------------------------------------------------------------------
CREATE TABLE public.journal_entries (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  encrypted_content     TEXT NOT NULL,               -- AES-256 encrypted narrative
  encrypted_raw_content TEXT,                        -- original voice transcript or raw text, encrypted
  mood                  TEXT CHECK (mood IN ('great', 'good', 'okay', 'low', 'tough')),
  entry_date            DATE NOT NULL DEFAULT CURRENT_DATE,
  entry_time            TIME DEFAULT CURRENT_TIME,
  location_name         TEXT,                        -- not encrypted; user controls whether to set this
  latitude              DOUBLE PRECISION,
  longitude             DOUBLE PRECISION,
  has_photo             BOOLEAN DEFAULT false,
  has_voice             BOOLEAN DEFAULT false,
  is_ai_polished        BOOLEAN DEFAULT false,
  word_count            INTEGER DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.journal_entries IS 'Core journal entries. Content is encrypted client-side; server never sees plaintext.';

-- --------------------------------------------------------------------------
-- entry_media: photo and voice attachments
-- --------------------------------------------------------------------------
CREATE TABLE public.entry_media (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id           UUID NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
  user_id            UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_type         TEXT NOT NULL CHECK (media_type IN ('photo', 'voice')),
  storage_path       TEXT NOT NULL,                  -- path in Supabase Storage bucket
  encrypted_metadata TEXT,                           -- encrypted caption, duration, etc.
  sort_order         INTEGER DEFAULT 0,
  created_at         TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.entry_media IS 'Media attachments for journal entries. Metadata is encrypted client-side.';

-- --------------------------------------------------------------------------
-- chapters: book-style organisation of entries
-- --------------------------------------------------------------------------
CREATE TABLE public.chapters (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  chapter_number  INTEGER NOT NULL,
  start_date      DATE NOT NULL,
  end_date        DATE,
  entry_count     INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT now(),

  UNIQUE (user_id, chapter_number)
);

COMMENT ON TABLE public.chapters IS 'Book chapters for organising journal entries into printable sections.';

-- --------------------------------------------------------------------------
-- book_exports: track PDF / print orders
-- --------------------------------------------------------------------------
CREATE TABLE public.book_exports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  export_type      TEXT NOT NULL CHECK (export_type IN ('pdf', 'epub', 'softcover', 'hardcover')),
  date_range_start DATE,
  date_range_end   DATE,
  cover_color      TEXT DEFAULT 'sage',
  status           TEXT DEFAULT 'pending'
                     CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  storage_path     TEXT,
  created_at       TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.book_exports IS 'Tracks book export jobs (PDF, ePub, print).';

-- --------------------------------------------------------------------------
-- streaks: engagement tracking (one row per user)
-- --------------------------------------------------------------------------
CREATE TABLE public.streaks (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_streak  INTEGER DEFAULT 0,
  longest_streak  INTEGER DEFAULT 0,
  last_entry_date DATE,
  total_entries   INTEGER DEFAULT 0,
  updated_at      TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.streaks IS 'Per-user writing streak and entry count tracker.';


-- ============================================================================
-- 3. INDEXES
-- ============================================================================

-- Timeline queries: fetch entries for a user ordered by date
CREATE INDEX idx_journal_entries_user_date
  ON public.journal_entries (user_id, entry_date DESC);

-- Mood filtering
CREATE INDEX idx_journal_entries_user_mood
  ON public.journal_entries (user_id, mood);

-- Media lookup by entry
CREATE INDEX idx_entry_media_entry_id
  ON public.entry_media (entry_id);


-- ============================================================================
-- 4. updated_at TRIGGERS
-- ============================================================================

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_journal_entries_updated_at
  BEFORE UPDATE ON public.journal_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER trg_streaks_updated_at
  BEFORE UPDATE ON public.streaks
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


-- ============================================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on every table
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_media     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_exports    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streaks         ENABLE ROW LEVEL SECURITY;

-- ----- profiles (keyed on id = auth.uid()) -----

CREATE POLICY profiles_select ON public.profiles
  FOR SELECT USING (id = auth.uid());

CREATE POLICY profiles_insert ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY profiles_delete ON public.profiles
  FOR DELETE USING (id = auth.uid());

-- ----- journal_entries -----

CREATE POLICY journal_entries_select ON public.journal_entries
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY journal_entries_insert ON public.journal_entries
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY journal_entries_update ON public.journal_entries
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY journal_entries_delete ON public.journal_entries
  FOR DELETE USING (user_id = auth.uid());

-- ----- entry_media -----

CREATE POLICY entry_media_select ON public.entry_media
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY entry_media_insert ON public.entry_media
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY entry_media_update ON public.entry_media
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY entry_media_delete ON public.entry_media
  FOR DELETE USING (user_id = auth.uid());

-- ----- chapters -----

CREATE POLICY chapters_select ON public.chapters
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY chapters_insert ON public.chapters
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY chapters_update ON public.chapters
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY chapters_delete ON public.chapters
  FOR DELETE USING (user_id = auth.uid());

-- ----- book_exports -----

CREATE POLICY book_exports_select ON public.book_exports
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY book_exports_insert ON public.book_exports
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY book_exports_update ON public.book_exports
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY book_exports_delete ON public.book_exports
  FOR DELETE USING (user_id = auth.uid());

-- ----- streaks -----

CREATE POLICY streaks_select ON public.streaks
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY streaks_insert ON public.streaks
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY streaks_update ON public.streaks
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY streaks_delete ON public.streaks
  FOR DELETE USING (user_id = auth.uid());


-- ============================================================================
-- 6. AUTO-CREATE PROFILE ON SIGN-UP
--    Listens to auth.users INSERT and creates a profiles row.
--    The encryption_salt is generated server-side as a random hex string;
--    the client uses it to derive the actual encryption key with the
--    user's passphrase (PBKDF2 / Argon2).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, encryption_salt)
  VALUES (
    NEW.id,
    md5(random()::text) || md5(random()::text)   -- 64-char hex salt (no pgcrypto needed)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================================
-- 7. AUTO-UPDATE STREAK ON NEW JOURNAL ENTRY
--    Upserts the user's streak row whenever a journal entry is inserted.
--    - If the entry is for today and yesterday was the last entry: streak +1
--    - If the entry is for today and today already counted: no change
--    - Otherwise: streak resets to 1
--    Also increments total_entries and updates longest_streak if needed.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_streak_on_entry()
RETURNS TRIGGER AS $$
DECLARE
  v_last_date DATE;
  v_new_streak INTEGER;
BEGIN
  -- Get the user's current streak state
  SELECT last_entry_date INTO v_last_date
  FROM public.streaks
  WHERE user_id = NEW.user_id;

  IF NOT FOUND THEN
    -- First entry ever: create streak row
    INSERT INTO public.streaks (user_id, current_streak, longest_streak, last_entry_date, total_entries)
    VALUES (NEW.user_id, 1, 1, NEW.entry_date, 1);
    RETURN NEW;
  END IF;

  -- Skip if we already counted an entry for this date
  IF v_last_date = NEW.entry_date THEN
    UPDATE public.streaks
    SET total_entries = total_entries + 1
    WHERE user_id = NEW.user_id;
    RETURN NEW;
  END IF;

  -- Determine new streak value
  IF v_last_date = NEW.entry_date - INTERVAL '1 day' THEN
    -- Consecutive day: extend streak
    v_new_streak := (SELECT current_streak FROM public.streaks WHERE user_id = NEW.user_id) + 1;
  ELSE
    -- Streak broken: reset to 1
    v_new_streak := 1;
  END IF;

  UPDATE public.streaks
  SET
    current_streak = v_new_streak,
    longest_streak = GREATEST(longest_streak, v_new_streak),
    last_entry_date = NEW.entry_date,
    total_entries = total_entries + 1
  WHERE user_id = NEW.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_streak_on_entry
  AFTER INSERT ON public.journal_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_streak_on_entry();
