-- Migration 036: Photos on book pages
--
-- 1. Adds a photos JSONB column to the pages table.
--    Each element describes one photo assigned to that page:
--    {
--      "storage_path":    "user-uuid/entries/entry-uuid/photo.jpg",
--      "entry_id":        "entry-uuid",
--      "caption":         "One of us at the beach, Mum looked so young.",
--      "score":           72,
--      "layout":          "weekOpener" | "rightFloat" | "leftFloat" | "midPage" | "photoStrip",
--      "after_paragraph": 0,          -- 0 = top of page / hero; N = after paragraph N
--      "aspect_ratio":    "landscape" | "portrait" | "square",
--      "is_hero":         true | false
--    }
--
-- 2. Adds words_per_page_with_photo app_config key (reduced target when a page
--    has a photo, to leave visual space for the image).

-- ── 1. Add photos column ─────────────────────────────────────────────────────
ALTER TABLE public.pages
  ADD COLUMN IF NOT EXISTS photos JSONB NOT NULL DEFAULT '[]';

COMMENT ON COLUMN public.pages.photos IS
  'Array of photo assignments for this page. Each element: '
  '{storage_path, entry_id, caption, score, layout, after_paragraph, aspect_ratio, is_hero}';

-- ── 2. Index for querying pages that have photos ─────────────────────────────
-- Useful for admin dashboards and analytics.
CREATE INDEX IF NOT EXISTS idx_pages_has_photos
  ON public.pages ((jsonb_array_length(photos) > 0))
  WHERE jsonb_array_length(photos) > 0;

-- ── 3. app_config: words_per_page_with_photo ─────────────────────────────────
INSERT INTO public.app_config (key, value, description)
VALUES (
  'words_per_page_with_photo',
  '160',
  'Target word count per page when a photo is present (reduced from words_per_page to leave visual space)'
)
ON CONFLICT (key) DO NOTHING;
