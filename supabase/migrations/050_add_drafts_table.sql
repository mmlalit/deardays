-- Draft entries sync table
-- Mirrors Hive local draft storage so drafts survive reinstalls
-- and sync across devices. Local-first: Hive is always written first,
-- Supabase upsert fires in the background.

create table if not exists public.drafts (
  id                  text        primary key,
  user_id             uuid        not null references auth.users(id) on delete cascade,
  type                text        not null,   -- 'text', 'review', 'voice', 'checkin'
  raw_text            text        not null,
  saved_at            timestamptz not null,
  entry_date          timestamptz not null,
  cleaned_text        text,
  polished_text       text,
  generated_title     text,
  mood                text,
  location_name       text,
  attached_photo_path text,
  is_voice            boolean     not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- RLS
alter table public.drafts enable row level security;

create policy "Users manage own drafts"
  on public.drafts
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Index for fetching user's drafts sorted by recency
create index if not exists idx_drafts_user_saved
  on public.drafts(user_id, saved_at desc);
