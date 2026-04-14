-- profiles table: stores per-user flags (is_pro, etc.)
CREATE TABLE profiles (
  id   uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  is_pro boolean NOT NULL DEFAULT false
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read their own profile only.
-- No UPDATE policy — is_pro is set manually via the Supabase dashboard.
CREATE POLICY "Users can read own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

-- Storage bucket for question images (pro users only).
-- file_size_limit: 500 KiB = 512000 bytes
-- allowed_mime_types: JPEG-XL only; enforced server-side by Supabase Storage
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('images', 'images', true, 512000, ARRAY['image/jxl'])
ON CONFLICT (id) DO NOTHING;

-- Anyone can download images (needed during gameplay).
CREATE POLICY "Public read images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'images');

-- Only authenticated pro users may upload.
CREATE POLICY "Pro users can upload images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'images' AND
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND is_pro = true
    )
  );

-- Allow pro users to overwrite their own images (upsert).
CREATE POLICY "Pro users can update own images"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'images' AND
    (storage.foldername(name))[1] = auth.uid()::text AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_pro = true)
  )
  WITH CHECK (
    bucket_id = 'images' AND
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_pro = true)
  );
