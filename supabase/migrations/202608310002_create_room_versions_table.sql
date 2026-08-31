-- Create room_versions table for background room editing log
CREATE TABLE IF NOT EXISTS public.room_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  version INT NOT NULL,
  room_data JSONB NOT NULL,
  edited_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.room_versions ENABLE ROW LEVEL SECURITY;

-- Select policy
DROP POLICY IF EXISTS "Allow authenticated users to read room_versions" ON public.room_versions;
CREATE POLICY "Allow authenticated users to read room_versions"
  ON public.room_versions FOR SELECT
  TO authenticated
  USING (true);

-- Insert policy
DROP POLICY IF EXISTS "Allow authenticated users to insert room_versions" ON public.room_versions;
CREATE POLICY "Allow authenticated users to insert room_versions"
  ON public.room_versions FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Enable real-time replication for app_notifications and rooms tables
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'app_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'rooms'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
  END IF;
END $$;

