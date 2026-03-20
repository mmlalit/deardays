-- Migration 027: Family Shared Books
-- Enables multiple family members to contribute entries to a shared book.
--
-- Design principles:
--   - Minimal changes to existing tables (add book_type column only)
--   - Family entries are SEPARATE from personal journal_entries (different privacy model)
--   - Shared-key E2E encryption: book key stored once per member, encrypted with their personal key
--   - Owner controls membership; contributors can only delete their own entries
--   - Invite via unguessable token (same pattern as memory_shares from migration 026)
-- ============================================================================


-- ============================================================================
-- 1. EXTEND books TABLE
-- ============================================================================

ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS book_type TEXT NOT NULL DEFAULT 'personal'
    CHECK (book_type IN ('personal', 'family'));

-- user_id on books becomes "owner_id" semantically for family books.
-- No rename needed — owner is always the creator.

COMMENT ON COLUMN public.books.book_type IS
  'personal = solo book (default). family = shared book with multiple contributors.';


-- ============================================================================
-- 2. book_members: who has access to a family book
-- ============================================================================

CREATE TABLE public.book_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id    UUID NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'contributor'
               CHECK (role IN ('owner', 'contributor', 'viewer')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (book_id, user_id)
);

COMMENT ON TABLE public.book_members IS
  'Membership table for family books. Owner is auto-inserted on book creation.
   Contributor can add entries. Viewer can read only.';

CREATE INDEX idx_book_members_book ON public.book_members(book_id);
CREATE INDEX idx_book_members_user ON public.book_members(user_id);


-- ============================================================================
-- 3. book_invites: pending invitations (token-based, same pattern as memory_shares)
-- ============================================================================

CREATE TABLE public.book_invites (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id        UUID NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  invited_by     UUID NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  token          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(), -- unguessable link token
  invitee_email  TEXT,                  -- optional; for email-targeted invites
  role           TEXT NOT NULL DEFAULT 'contributor'
                   CHECK (role IN ('contributor', 'viewer')),
  status         TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
  expires_at     TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '7 days',
  accepted_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  accepted_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.book_invites IS
  'Invite links for joining a family book. Token is a UUID — effectively unguessable.
   One token per invite. Accepting auto-inserts into book_members.';

CREATE INDEX idx_book_invites_token ON public.book_invites(token);
CREATE INDEX idx_book_invites_book  ON public.book_invites(book_id);
CREATE INDEX idx_book_invites_email ON public.book_invites(invitee_email) WHERE invitee_email IS NOT NULL;


-- ============================================================================
-- 4. book_shared_keys: E2E encryption for family books
--    Each member stores the book's AES key encrypted with their personal key.
--    Client decrypts book_key with personal key → uses book_key to read entries.
-- ============================================================================

CREATE TABLE public.book_shared_keys (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id        UUID NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  encrypted_key  TEXT NOT NULL,  -- book's AES-256 key, wrapped with user's personal key
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (book_id, user_id)
);

COMMENT ON TABLE public.book_shared_keys IS
  'Per-member copy of the family book encryption key, wrapped with the member personal key.
   Server never sees the plaintext book key. When a new member joins, the owner
   re-encrypts the book key for them and inserts a row here.';

CREATE INDEX idx_book_shared_keys_book_user ON public.book_shared_keys(book_id, user_id);


-- ============================================================================
-- 5. family_entries: entries contributed to a family book
--    Deliberately separate from journal_entries (different privacy scope).
-- ============================================================================

CREATE TABLE public.family_entries (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id        UUID NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  author_id      UUID NOT NULL REFERENCES auth.users(id)   ON DELETE CASCADE,
  content        TEXT NOT NULL,   -- encrypted with book's shared key
  raw_content    TEXT,            -- original voice transcript, encrypted
  mood           TEXT CHECK (mood IN ('great', 'good', 'okay', 'low', 'tough')),
  entry_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  entry_time     TIME DEFAULT CURRENT_TIME,
  location_name  TEXT,
  has_photo      BOOLEAN DEFAULT false,
  has_voice      BOOLEAN DEFAULT false,
  reaction_count INTEGER DEFAULT 0,  -- denormalised for fast feed rendering
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.family_entries IS
  'Journal entries contributed to a family book. Encrypted with the shared book key.
   Author can edit/delete their own entries; book owner can delete any entry.';

CREATE INDEX idx_family_entries_book_date ON public.family_entries(book_id, entry_date DESC);
CREATE INDEX idx_family_entries_author    ON public.family_entries(author_id);

CREATE TRIGGER trg_family_entries_updated_at
  BEFORE UPDATE ON public.family_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();


-- ============================================================================
-- 6. entry_reactions: hearts / reactions on family entries (one per user per entry)
-- ============================================================================

CREATE TABLE public.entry_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id   UUID NOT NULL REFERENCES public.family_entries(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL DEFAULT '❤️',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (entry_id, user_id)  -- one reaction per user per entry
);

COMMENT ON TABLE public.entry_reactions IS
  'Reactions (hearts etc.) on family_entries. Limited to one per user per entry.';

CREATE INDEX idx_entry_reactions_entry ON public.entry_reactions(entry_id);

-- Auto-update the denormalised reaction_count on family_entries
CREATE OR REPLACE FUNCTION public.sync_reaction_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.family_entries SET reaction_count = reaction_count + 1 WHERE id = NEW.entry_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.family_entries SET reaction_count = GREATEST(reaction_count - 1, 0) WHERE id = OLD.entry_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_sync_reaction_count
  AFTER INSERT OR DELETE ON public.entry_reactions
  FOR EACH ROW EXECUTE FUNCTION public.sync_reaction_count();


-- ============================================================================
-- 7. book_activity: lightweight notification feed for family book events
-- ============================================================================

CREATE TABLE public.book_activity (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id      UUID NOT NULL REFERENCES public.books(id)       ON DELETE CASCADE,
  actor_id     UUID NOT NULL REFERENCES auth.users(id)         ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES auth.users(id)         ON DELETE CASCADE,
  type         TEXT NOT NULL
                 CHECK (type IN ('new_entry', 'new_member', 'reaction', 'invite_accepted')),
  entry_id     UUID REFERENCES public.family_entries(id) ON DELETE CASCADE,
  is_read      BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.book_activity IS
  'Activity feed rows pushed to each family book member on notable events.
   One row per recipient — fan-out on write. Pruned by cron after 90 days.';

CREATE INDEX idx_book_activity_recipient_read
  ON public.book_activity(recipient_id, is_read, created_at DESC);

CREATE INDEX idx_book_activity_book
  ON public.book_activity(book_id);


-- ============================================================================
-- 8. ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.book_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_invites     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_shared_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_entries   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entry_reactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_activity    ENABLE ROW LEVEL SECURITY;

-- Helper: is the current user a member of the given book?
CREATE OR REPLACE FUNCTION public.is_book_member(p_book_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.book_members
    WHERE book_id = p_book_id AND user_id = auth.uid()
  );
$$;

-- Helper: is the current user the owner of the given book?
CREATE OR REPLACE FUNCTION public.is_book_owner(p_book_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.book_members
    WHERE book_id = p_book_id AND user_id = auth.uid() AND role = 'owner'
  );
$$;

-- ----- book_members -----
CREATE POLICY bm_select ON public.book_members FOR SELECT
  USING (public.is_book_member(book_id));           -- all members see the member list

CREATE POLICY bm_insert ON public.book_members FOR INSERT
  WITH CHECK (public.is_book_owner(book_id));       -- only owner can add members

CREATE POLICY bm_delete ON public.book_members FOR DELETE
  USING (
    public.is_book_owner(book_id)                   -- owner removes anyone
    OR user_id = auth.uid()                         -- or member leaves themselves
  );

-- ----- book_invites -----
CREATE POLICY bi_select_member ON public.book_invites FOR SELECT
  USING (public.is_book_member(book_id));           -- members see all pending invites

CREATE POLICY bi_select_token ON public.book_invites FOR SELECT
  USING (true);                                     -- token is UUID — safe to expose by token lookup

CREATE POLICY bi_insert ON public.book_invites FOR INSERT
  WITH CHECK (public.is_book_member(book_id));      -- any member can invite

CREATE POLICY bi_update ON public.book_invites FOR UPDATE
  USING (public.is_book_member(book_id) OR accepted_by = auth.uid());

-- ----- book_shared_keys -----
CREATE POLICY bsk_select ON public.book_shared_keys FOR SELECT
  USING (user_id = auth.uid());                     -- each user sees only their own wrapped key

CREATE POLICY bsk_insert ON public.book_shared_keys FOR INSERT
  WITH CHECK (public.is_book_owner(book_id));       -- owner distributes keys to new members

CREATE POLICY bsk_delete ON public.book_shared_keys FOR DELETE
  USING (public.is_book_owner(book_id));

-- ----- family_entries -----
CREATE POLICY fe_select ON public.family_entries FOR SELECT
  USING (public.is_book_member(book_id));           -- all members read all entries

CREATE POLICY fe_insert ON public.family_entries FOR INSERT
  WITH CHECK (
    author_id = auth.uid()
    AND public.is_book_member(book_id)
    AND EXISTS (
      SELECT 1 FROM public.book_members
      WHERE book_id = family_entries.book_id
        AND user_id = auth.uid()
        AND role IN ('owner', 'contributor')        -- viewers cannot write
    )
  );

CREATE POLICY fe_update ON public.family_entries FOR UPDATE
  USING (author_id = auth.uid());                   -- author edits own entries only

CREATE POLICY fe_delete ON public.family_entries FOR DELETE
  USING (
    author_id = auth.uid()                          -- author deletes own
    OR public.is_book_owner(book_id)                -- or owner moderates
  );

-- ----- entry_reactions -----
CREATE POLICY er_select ON public.entry_reactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.family_entries fe
      WHERE fe.id = entry_id AND public.is_book_member(fe.book_id)
    )
  );

CREATE POLICY er_insert ON public.entry_reactions FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.family_entries fe
      WHERE fe.id = entry_id AND public.is_book_member(fe.book_id)
    )
  );

CREATE POLICY er_delete ON public.entry_reactions FOR DELETE
  USING (user_id = auth.uid());                     -- only remove your own reaction

-- ----- book_activity -----
CREATE POLICY ba_select ON public.book_activity FOR SELECT
  USING (recipient_id = auth.uid());                -- each user sees only their own notifications

CREATE POLICY ba_insert ON public.book_activity FOR INSERT
  WITH CHECK (actor_id = auth.uid());

CREATE POLICY ba_update ON public.book_activity FOR UPDATE
  USING (recipient_id = auth.uid());                -- mark-as-read


-- ============================================================================
-- 9. TRIGGER: auto-insert owner into book_members when a family book is created
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_add_book_owner()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.book_type = 'family' THEN
    INSERT INTO public.book_members (book_id, user_id, role)
    VALUES (NEW.id, NEW.user_id, 'owner')
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_add_book_owner
  AFTER INSERT ON public.books
  FOR EACH ROW EXECUTE FUNCTION public.auto_add_book_owner();


-- ============================================================================
-- 10. HELPER RPCs
-- ============================================================================

-- Accept an invite by token — inserts into book_members + marks invite accepted.
-- Call this from the Flutter client after the user taps the invite link.
CREATE OR REPLACE FUNCTION public.accept_book_invite(p_token UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invite  public.book_invites%ROWTYPE;
  v_book    public.books%ROWTYPE;
BEGIN
  SELECT * INTO v_invite
  FROM public.book_invites
  WHERE token = p_token AND status = 'pending' AND expires_at > now();

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invite_invalid_or_expired');
  END IF;

  -- Add member (idempotent)
  INSERT INTO public.book_members (book_id, user_id, role)
  VALUES (v_invite.book_id, auth.uid(), v_invite.role)
  ON CONFLICT (book_id, user_id) DO NOTHING;

  -- Mark invite accepted
  UPDATE public.book_invites
  SET status = 'accepted', accepted_by = auth.uid(), accepted_at = now()
  WHERE id = v_invite.id;

  SELECT * INTO v_book FROM public.books WHERE id = v_invite.book_id;

  RETURN jsonb_build_object(
    'ok',      true,
    'book_id', v_invite.book_id,
    'title',   v_book.title
  );
END;
$$;

-- Expire stale pending invites (run by nightly cron alongside expire_stale_share_requests)
CREATE OR REPLACE FUNCTION public.expire_stale_book_invites()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count INTEGER;
BEGIN
  UPDATE public.book_invites SET status = 'expired'
  WHERE status = 'pending' AND expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Prune old activity rows (> 90 days) — call from cron
CREATE OR REPLACE FUNCTION public.prune_old_book_activity()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count INTEGER;
BEGIN
  DELETE FROM public.book_activity WHERE created_at < now() - INTERVAL '90 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
