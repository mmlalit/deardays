-- Add milestone fields to journal_entries
-- Allows entries to be flagged as life milestones with a type label.

alter table public.journal_entries
  add column if not exists is_milestone boolean not null default false,
  add column if not exists milestone_type text;

-- Index for quickly fetching milestones
create index if not exists idx_journal_entries_milestone
  on public.journal_entries(user_id)
  where is_milestone = true;
