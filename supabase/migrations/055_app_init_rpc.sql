-- Migration 055: get_app_init_data RPC
--
-- Returns profile, streak, chapters, books, and min_app_version in a single
-- call. Replaces 5 separate API calls on cold start with 1.
--
-- Before: profile + streak + chapters + books + remote_config = 5 REST calls
-- After:  get_app_init_data = 1 RPC call

CREATE OR REPLACE FUNCTION public.get_app_init_data(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'profile', (
      SELECT row_to_json(p.*)
      FROM profiles p
      WHERE p.id = p_user_id
    ),
    'streak', (
      SELECT row_to_json(s.*)
      FROM streaks s
      WHERE s.user_id = p_user_id
    ),
    'chapters', COALESCE((
      SELECT json_agg(row_to_json(c.*) ORDER BY c.chapter_number)
      FROM chapters c
      WHERE c.user_id = p_user_id
    ), '[]'::json),
    'books', COALESCE((
      SELECT json_agg(row_to_json(b.*) ORDER BY b.sort_order)
      FROM books b
      WHERE b.user_id = p_user_id
    ), '[]'::json),
    'min_app_version', (
      SELECT value
      FROM remote_config
      WHERE key = 'min_app_version'
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.get_app_init_data(UUID) TO authenticated;
