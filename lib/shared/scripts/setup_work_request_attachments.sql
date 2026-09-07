-- Run this in Supabase SQL Editor:
-- 1. Add attachment_urls column to work_requests table if it doesn't already exist
ALTER TABLE public.work_requests 
ADD COLUMN IF NOT EXISTS attachment_urls TEXT[];

-- 2. Update work_requests work_evidence to TEXT if VARCHAR(500) is limiting long URLs
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'work_evidence'
  ) THEN
    ALTER TABLE public.work_requests ALTER COLUMN work_evidence TYPE TEXT;
  END IF;
END $$;

-- 3. Ensure work-request-attachments bucket exists and is public
INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'work-request-attachments',
  'work-request-attachments',
  true,
  20971520, -- 20MB limit
  NULL      -- Allow all image types
)
ON CONFLICT (id) DO UPDATE SET public = true, allowed_mime_types = NULL;

-- 4. Storage Policies for work-request-attachments
DROP POLICY IF EXISTS "Public can read work request attachments" ON storage.objects;
CREATE POLICY "Public can read work request attachments"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'work-request-attachments');

DROP POLICY IF EXISTS "Authenticated can insert work request attachments" ON storage.objects;
CREATE POLICY "Authenticated can insert work request attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'work-request-attachments');

DROP POLICY IF EXISTS "Anon can insert work request attachments" ON storage.objects;
CREATE POLICY "Anon can insert work request attachments"
ON storage.objects FOR INSERT TO anon
WITH CHECK (bucket_id = 'work-request-attachments');

DROP POLICY IF EXISTS "Authenticated can update work request attachments" ON storage.objects;
CREATE POLICY "Authenticated can update work request attachments"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'work-request-attachments');
