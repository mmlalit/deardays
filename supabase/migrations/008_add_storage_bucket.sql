-- Create the entry-media storage bucket (private, requires auth)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'entry-media',
  'entry-media',
  false,
  10485760, -- 10 MB max per file
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'audio/mp4', 'audio/m4a', 'audio/aac']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: users can upload to their own folder
CREATE POLICY "Users can upload their own media"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'entry-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS: users can read their own media
CREATE POLICY "Users can read their own media"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'entry-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS: users can delete their own media
CREATE POLICY "Users can delete their own media"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'entry-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
