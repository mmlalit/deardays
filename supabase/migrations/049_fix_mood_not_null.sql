-- Migration 049: Backfill and constrain mood column
-- Backfill NULL moods with default value before adding constraint

UPDATE journal_entries
SET mood = 'okay'
WHERE mood IS NULL;

-- Now safe to add NOT NULL with default
ALTER TABLE journal_entries
  ALTER COLUMN mood SET DEFAULT 'okay',
  ALTER COLUMN mood SET NOT NULL;
