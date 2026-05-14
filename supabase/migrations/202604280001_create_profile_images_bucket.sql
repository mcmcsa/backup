-- Create storage bucket for user profile images.
-- This resolves upload failures for teacher and maintenance profile photos.

BEGIN;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'profile-images',
  'profile-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

UPDATE storage.buckets
SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'profile-images';

DROP POLICY IF EXISTS profile_images_select_public ON storage.objects;
CREATE POLICY profile_images_select_public
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'profile-images');

DROP POLICY IF EXISTS profile_images_insert_authenticated ON storage.objects;
CREATE POLICY profile_images_insert_authenticated
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profile-images');

DROP POLICY IF EXISTS profile_images_update_authenticated ON storage.objects;
CREATE POLICY profile_images_update_authenticated
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'profile-images')
WITH CHECK (bucket_id = 'profile-images');

DROP POLICY IF EXISTS profile_images_delete_authenticated ON storage.objects;
CREATE POLICY profile_images_delete_authenticated
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'profile-images');

COMMIT;
