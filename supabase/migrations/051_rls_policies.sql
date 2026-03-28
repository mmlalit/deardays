-- Migration 051: Comprehensive RLS policies for all tables
-- Idempotent: uses DROP POLICY IF EXISTS + CREATE POLICY, and checks before enabling RLS.

-- =============================================================================
-- 1. updated_at trigger function (shared across tables)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 2. Enable RLS on all tables
-- =============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_in_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memory_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reflection_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remote_config ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 3. profiles
-- =============================================================================

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_delete_own" ON public.profiles;
CREATE POLICY "profiles_delete_own" ON public.profiles
  FOR DELETE USING (auth.uid() = id);

-- =============================================================================
-- 4. journal_entries
-- =============================================================================

DROP POLICY IF EXISTS "journal_entries_select_own" ON public.journal_entries;
CREATE POLICY "journal_entries_select_own" ON public.journal_entries
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "journal_entries_insert_own" ON public.journal_entries;
CREATE POLICY "journal_entries_insert_own" ON public.journal_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "journal_entries_update_own" ON public.journal_entries;
CREATE POLICY "journal_entries_update_own" ON public.journal_entries
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "journal_entries_delete_own" ON public.journal_entries;
CREATE POLICY "journal_entries_delete_own" ON public.journal_entries
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 5. entry_media (ownership via parent journal_entries row)
-- =============================================================================

DROP POLICY IF EXISTS "entry_media_select_own" ON public.entry_media;
CREATE POLICY "entry_media_select_own" ON public.entry_media
  FOR SELECT USING (
    auth.uid() = (SELECT user_id FROM public.journal_entries WHERE id = entry_media.entry_id)
  );

DROP POLICY IF EXISTS "entry_media_insert_own" ON public.entry_media;
CREATE POLICY "entry_media_insert_own" ON public.entry_media
  FOR INSERT WITH CHECK (
    auth.uid() = (SELECT user_id FROM public.journal_entries WHERE id = entry_media.entry_id)
  );

DROP POLICY IF EXISTS "entry_media_delete_own" ON public.entry_media;
CREATE POLICY "entry_media_delete_own" ON public.entry_media
  FOR DELETE USING (
    auth.uid() = (SELECT user_id FROM public.journal_entries WHERE id = entry_media.entry_id)
  );

DROP POLICY IF EXISTS "entry_media_update_own" ON public.entry_media;
CREATE POLICY "entry_media_update_own" ON public.entry_media
  FOR UPDATE USING (
    auth.uid() = (SELECT user_id FROM public.journal_entries WHERE id = entry_media.entry_id)
  );

-- =============================================================================
-- 6. check_in_conversations
-- =============================================================================

DROP POLICY IF EXISTS "checkin_select_own" ON public.check_in_conversations;
CREATE POLICY "checkin_select_own" ON public.check_in_conversations
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "checkin_insert_own" ON public.check_in_conversations;
CREATE POLICY "checkin_insert_own" ON public.check_in_conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "checkin_update_own" ON public.check_in_conversations;
CREATE POLICY "checkin_update_own" ON public.check_in_conversations
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "checkin_delete_own" ON public.check_in_conversations;
CREATE POLICY "checkin_delete_own" ON public.check_in_conversations
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 7. memory_shares
-- =============================================================================

DROP POLICY IF EXISTS "memory_shares_select" ON public.memory_shares;
CREATE POLICY "memory_shares_select" ON public.memory_shares
  FOR SELECT USING (
    auth.uid() = sharer_id
    OR auth.uid() = recipient_id
    OR (status = 'pending' AND recipient_id IS NULL)
  );

DROP POLICY IF EXISTS "memory_shares_insert_sharer" ON public.memory_shares;
CREATE POLICY "memory_shares_insert_sharer" ON public.memory_shares
  FOR INSERT WITH CHECK (auth.uid() = sharer_id);

DROP POLICY IF EXISTS "memory_shares_update" ON public.memory_shares;
DROP POLICY IF EXISTS "memory_shares_update_sharer" ON public.memory_shares;
CREATE POLICY "memory_shares_update_sharer" ON public.memory_shares
  FOR UPDATE USING (auth.uid() = sharer_id)
  WITH CHECK (auth.uid() = sharer_id);

-- Security-definer function for claiming shares (recipients cannot UPDATE directly)
CREATE OR REPLACE FUNCTION claim_share(p_share_id UUID, p_recipient_name TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.memory_shares
  SET recipient_id = auth.uid(),
      recipient_name = p_recipient_name,
      status = 'requested',
      requested_at = now()
  WHERE id = p_share_id
    AND status = 'pending'
    AND recipient_id IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Share not available for claiming';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP POLICY IF EXISTS "memory_shares_delete_sharer" ON public.memory_shares;
CREATE POLICY "memory_shares_delete_sharer" ON public.memory_shares
  FOR DELETE USING (auth.uid() = sharer_id);

-- =============================================================================
-- 8. books
-- =============================================================================

DROP POLICY IF EXISTS "books_select_own" ON public.books;
CREATE POLICY "books_select_own" ON public.books
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "books_insert_own" ON public.books;
CREATE POLICY "books_insert_own" ON public.books
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "books_update_own" ON public.books;
CREATE POLICY "books_update_own" ON public.books
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "books_delete_own" ON public.books;
CREATE POLICY "books_delete_own" ON public.books
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 9. pages
-- =============================================================================

DROP POLICY IF EXISTS "pages_select_own" ON public.pages;
CREATE POLICY "pages_select_own" ON public.pages
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "pages_insert_own" ON public.pages;
CREATE POLICY "pages_insert_own" ON public.pages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "pages_update_own" ON public.pages;
CREATE POLICY "pages_update_own" ON public.pages
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "pages_delete_own" ON public.pages;
CREATE POLICY "pages_delete_own" ON public.pages
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 10. chapters
-- =============================================================================

DROP POLICY IF EXISTS "chapters_select_own" ON public.chapters;
CREATE POLICY "chapters_select_own" ON public.chapters
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "chapters_insert_own" ON public.chapters;
CREATE POLICY "chapters_insert_own" ON public.chapters
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "chapters_update_own" ON public.chapters;
CREATE POLICY "chapters_update_own" ON public.chapters
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "chapters_delete_own" ON public.chapters;
CREATE POLICY "chapters_delete_own" ON public.chapters
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 11. drafts
-- =============================================================================

DROP POLICY IF EXISTS "drafts_select_own" ON public.drafts;
CREATE POLICY "drafts_select_own" ON public.drafts
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "drafts_insert_own" ON public.drafts;
CREATE POLICY "drafts_insert_own" ON public.drafts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "drafts_update_own" ON public.drafts;
CREATE POLICY "drafts_update_own" ON public.drafts
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "drafts_delete_own" ON public.drafts;
CREATE POLICY "drafts_delete_own" ON public.drafts
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 12. reflection_cache
-- =============================================================================

DROP POLICY IF EXISTS "reflection_cache_select_own" ON public.reflection_cache;
CREATE POLICY "reflection_cache_select_own" ON public.reflection_cache
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "reflection_cache_insert_own" ON public.reflection_cache;
CREATE POLICY "reflection_cache_insert_own" ON public.reflection_cache
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reflection_cache_update_own" ON public.reflection_cache;
CREATE POLICY "reflection_cache_update_own" ON public.reflection_cache
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reflection_cache_delete_own" ON public.reflection_cache;
CREATE POLICY "reflection_cache_delete_own" ON public.reflection_cache
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================================
-- 13. remote_config (read-only for authenticated users)
-- =============================================================================

DROP POLICY IF EXISTS "remote_config_select_authenticated" ON public.remote_config;
CREATE POLICY "remote_config_select_authenticated" ON public.remote_config
  FOR SELECT USING (auth.role() = 'authenticated');

-- No INSERT/UPDATE/DELETE policies — only service role can modify.

-- =============================================================================
-- 14. updated_at triggers
-- =============================================================================

DROP TRIGGER IF EXISTS set_updated_at ON public.journal_entries;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.journal_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at ON public.check_in_conversations;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.check_in_conversations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at ON public.books;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.books
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at ON public.pages;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.pages
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at ON public.drafts;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.drafts
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- reflection_cache uses generated_at, not updated_at — no trigger needed here.

DROP TRIGGER IF EXISTS set_updated_at ON public.profiles;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- 16. Unique constraint on chapters(user_id, chapter_number)
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chapters_user_id_chapter_number_key'
  ) THEN
    ALTER TABLE public.chapters
      ADD CONSTRAINT chapters_user_id_chapter_number_key UNIQUE (user_id, chapter_number);
  END IF;
END;
$$;
