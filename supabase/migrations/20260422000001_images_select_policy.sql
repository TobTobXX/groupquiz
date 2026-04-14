-- Drop the overly broad SELECT policy that allows listing all files.
-- Public bucket URLs work without any RLS policy, so no replacement is needed
-- for gameplay (image display). We add a scoped policy so creators can list
-- only their own folder via the JS client if needed.
DROP POLICY IF EXISTS "Public read images" ON storage.objects;

CREATE POLICY "Users can read own images"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );
