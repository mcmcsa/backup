-- Ensure rooms.image_url column is TEXT to prevent length truncation with long storage URLs or base64 fallbacks
-- Ensure room-images bucket exists with public access policies

BEGIN;

ALTER TABLE public.rooms ALTER COLUMN image_url TYPE TEXT;

-- Create room-images storage bucket if not exists
INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'room-images',
  'room-images',
  true,
  20971520, -- 20MB limit
  NULL      -- Allow all image types
)
ON CONFLICT (id) DO UPDATE SET public = true, allowed_mime_types = NULL;

-- Storage Policies for room-images
DROP POLICY IF EXISTS "Public can read room images" ON storage.objects;
CREATE POLICY "Public can read room images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'room-images');

DROP POLICY IF EXISTS "Authenticated can insert room images" ON storage.objects;
CREATE POLICY "Authenticated can insert room images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'room-images');

DROP POLICY IF EXISTS "Anon can insert room images" ON storage.objects;
CREATE POLICY "Anon can insert room images"
ON storage.objects FOR INSERT TO anon
WITH CHECK (bucket_id = 'room-images');

DROP POLICY IF EXISTS "Authenticated can update room images" ON storage.objects;
CREATE POLICY "Authenticated can update room images"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'room-images');

DROP POLICY IF EXISTS "Anon can update room images" ON storage.objects;
CREATE POLICY "Anon can update room images"
ON storage.objects FOR UPDATE TO anon
USING (bucket_id = 'room-images');

DROP POLICY IF EXISTS "Authenticated can delete room images" ON storage.objects;
CREATE POLICY "Authenticated can delete room images"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'room-images');

DROP POLICY IF EXISTS "Anon can delete room images" ON storage.objects;
CREATE POLICY "Anon can delete room images"
ON storage.objects FOR DELETE TO anon
USING (bucket_id = 'room-images');

COMMIT;
