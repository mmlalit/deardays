-- Check-in conversations sync table
-- Mirrors the Hive local storage so conversations survive reinstalls
-- and sync across devices.

create table if not exists public.check_in_conversations (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  date_key    text        not null,        -- "YYYY-MM-DD", e.g. "2026-03-09"
  mood        text,
  sections    jsonb       not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique(user_id, date_key)
);

-- Only the owner can read/write their own conversations
alter table public.check_in_conversations enable row level security;

create policy "Users manage own conversations"
  on public.check_in_conversations
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Index for fast lookups by user + date
create index if not exists idx_checkin_conversations_user_date
  on public.check_in_conversations(user_id, date_key desc);
