-- ==============================================================================
-- Duplicate Report Detection Schema
-- Run this in your Supabase SQL Editor
-- ==============================================================================

-- 1. request_reporters
-- Tracks users who "joined" an existing request as co-reporters.
CREATE TABLE IF NOT EXISTS public.request_reporters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id uuid NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  reporter_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reporter_name text NOT NULL,
  joined_at timestamp with time zone DEFAULT now(),
  UNIQUE (work_request_id, reporter_id)
);

-- 2. request_merges
-- Audit trail for merged duplicate requests performed by Campus Admins.
CREATE TABLE IF NOT EXISTS public.request_merges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  primary_request_id uuid REFERENCES public.work_requests(id) ON DELETE SET NULL,
  merged_request_id uuid REFERENCES public.work_requests(id) ON DELETE SET NULL,
  merged_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  merged_at timestamp with time zone DEFAULT now(),
  notes text
);

-- ==============================================================================
-- Row Level Security
-- ==============================================================================

ALTER TABLE public.request_reporters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_merges ENABLE ROW LEVEL SECURITY;

-- request_reporters: authenticated users can read and insert their own rows
CREATE POLICY "Authenticated users can view reporters"
  ON public.request_reporters FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Users can join a request as reporter"
  ON public.request_reporters FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = reporter_id);

-- request_merges: only admins can insert and view (broad policy, app guards role)
CREATE POLICY "Authenticated can read merge history"
  ON public.request_merges FOR SELECT
  TO authenticated USING (true);

CREATE POLICY "Authenticated can insert merge records"
  ON public.request_merges FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = merged_by);

-- ==============================================================================
-- Enable Realtime for these tables (optional, recommended)
-- Run this if you want live updates in the admin merge view.
-- ==============================================================================
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.request_reporters;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.request_merges;
