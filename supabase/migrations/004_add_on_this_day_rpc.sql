-- ============================================================================
-- DearDays: Migration 004 — Add "On This Day" RPC function
-- ============================================================================

-- Returns journal entries from previous years that match the given month-day.
-- Used by the "On This Day" feature to show memories from past years.
CREATE OR REPLACE FUNCTION public.get_on_this_day_entries(
  p_user_id UUID,
  p_month_day TEXT  -- format: 'MM-DD'
)
RETURNS SETOF public.journal_entries
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT *
  FROM public.journal_entries
  WHERE user_id = p_user_id
    AND to_char(entry_date, 'MM-DD') = p_month_day
    AND entry_date < CURRENT_DATE  -- exclude today
  ORDER BY entry_date DESC;
$$;
