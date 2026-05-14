-- Create storage bucket for maintenance work evidence uploads.
-- This resolves: Bucket not found (404) during image upload.

BEGIN;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'work-evidence',
  'work-evidence',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

UPDATE storage.buckets
SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']
WHERE id = 'work-evidence';

DROP POLICY IF EXISTS work_evidence_select_public ON storage.objects;
CREATE POLICY work_evidence_select_public
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'work-evidence');

DROP POLICY IF EXISTS work_evidence_insert_authenticated ON storage.objects;
CREATE POLICY work_evidence_insert_authenticated
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'work-evidence');

DROP POLICY IF EXISTS work_evidence_update_authenticated ON storage.objects;
CREATE POLICY work_evidence_update_authenticated
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'work-evidence')
WITH CHECK (bucket_id = 'work-evidence');

DROP POLICY IF EXISTS work_evidence_delete_authenticated ON storage.objects;
CREATE POLICY work_evidence_delete_authenticated
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'work-evidence');

COMMIT;
