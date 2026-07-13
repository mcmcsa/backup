-- Add voice_notes to work_requests table
ALTER TABLE public.work_requests
ADD COLUMN voice_notes TEXT[] DEFAULT '{}';

-- Add voice_notes to work_request_notes table for collaboration updates
ALTER TABLE public.work_request_notes
ADD COLUMN voice_notes TEXT[] DEFAULT '{}';

-- Create Storage Bucket for Voice Recordings
INSERT INTO storage.buckets (id, name, public) 
VALUES ('voice_recordings', 'voice_recordings', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for voice_recordings bucket
CREATE POLICY "Public Access Voice" ON storage.objects
FOR SELECT USING (bucket_id = 'voice_recordings');

CREATE POLICY "Authenticated Users Upload Voice" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (bucket_id = 'voice_recordings');

CREATE POLICY "Users can update their own voice recordings" ON storage.objects
FOR UPDATE TO authenticated USING (bucket_id = 'voice_recordings' AND owner = auth.uid());

CREATE POLICY "Users can delete their own voice recordings" ON storage.objects
FOR DELETE TO authenticated USING (bucket_id = 'voice_recordings' AND owner = auth.uid());
