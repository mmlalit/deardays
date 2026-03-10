-- Add cover_image_url column to books table
ALTER TABLE books ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

-- ============================================================
-- Storage bucket: user-covers (public, so app can load via URL)
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-covers',
  'user-covers',
  true,
  5242880, -- 5 MB max per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: users can upload to their own folder
CREATE POLICY "Users can upload their own covers"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'user-covers'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS: anyone can read covers (public bucket)
CREATE POLICY "Anyone can read covers"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'user-covers');

-- RLS: users can update/delete their own covers
CREATE POLICY "Users can update their own covers"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'user-covers'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete their own covers"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'user-covers'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================
-- Default chapter covers table (admin-managed stock photos)
-- ============================================================
CREATE TABLE IF NOT EXISTS default_chapter_covers (
  id SERIAL PRIMARY KEY,
  category TEXT NOT NULL UNIQUE,
  keywords TEXT[] NOT NULL,
  image_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Public read access (no RLS needed for reads, admin-only writes)
ALTER TABLE default_chapter_covers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read default covers"
  ON default_chapter_covers FOR SELECT
  TO public
  USING (true);

-- Seed with curated stock photos
INSERT INTO default_chapter_covers (category, keywords, image_url) VALUES
  ('family',    ARRAY['family', 'home', 'parent', 'mom', 'dad', 'child', 'kids'],
    'https://images.unsplash.com/photo-1606791405792-1004f1718d0c?w=600&h=600&fit=crop'),
  ('travel',    ARRAY['travel', 'trip', 'adventure', 'vacation', 'journey', 'explore'],
    'https://images.unsplash.com/photo-1530789253388-582c481c54b0?w=600&h=600&fit=crop'),
  ('career',    ARRAY['career', 'work', 'job', 'office', 'business', 'professional'],
    'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=600&h=600&fit=crop'),
  ('growth',    ARRAY['growth', 'self', 'mindful', 'meditat', 'wellness', 'health', 'fitness'],
    'https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=600&h=600&fit=crop'),
  ('love',      ARRAY['love', 'romance', 'relationship', 'dating', 'partner', 'heart'],
    'https://images.unsplash.com/photo-1518568403628-2ef91db3862c?w=600&h=600&fit=crop'),
  ('friends',   ARRAY['friend', 'social', 'people', 'community'],
    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=600&h=600&fit=crop'),
  ('education', ARRAY['school', 'study', 'learn', 'education', 'college', 'university'],
    'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=600&h=600&fit=crop'),
  ('food',      ARRAY['food', 'cook', 'recipe', 'kitchen', 'baking'],
    'https://images.unsplash.com/photo-1466637574441-749b8f19452f?w=600&h=600&fit=crop'),
  ('music',     ARRAY['music', 'song', 'concert', 'playlist'],
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=600&h=600&fit=crop'),
  ('nature',    ARRAY['nature', 'outdoor', 'garden', 'plant', 'hiking'],
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=600&fit=crop'),
  ('pets',      ARRAY['pet', 'dog', 'cat', 'animal'],
    'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=600&h=600&fit=crop'),
  ('creative',  ARRAY['creative', 'art', 'paint', 'draw', 'craft', 'design'],
    'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?w=600&h=600&fit=crop'),
  ('yearly',    ARRAY['2024', '2025', '2026', '2027', '2028'],
    'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600&h=600&fit=crop'),
  ('monthly',   ARRAY['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'],
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=600&fit=crop'),
  ('quarterly', ARRAY['q1', 'q2', 'q3', 'q4', 'quarter'],
    'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600&h=600&fit=crop')
ON CONFLICT (category) DO NOTHING;
