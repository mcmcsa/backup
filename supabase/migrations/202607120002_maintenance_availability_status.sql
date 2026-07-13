-- ==============================================================================
-- Maintenance Availability Status
-- Adds availability tracking columns to existing maintenance_users table.
-- ==============================================================================

ALTER TABLE public.maintenance_users
  ADD COLUMN IF NOT EXISTS availability_status text NOT NULL DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS current_location text,
  ADD COLUMN IF NOT EXISTS current_assignment_id uuid REFERENCES public.work_requests(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS estimated_completion_time timestamp with time zone,
  ADD COLUMN IF NOT EXISTS last_active_at timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS working_hours_start time,
  ADD COLUMN IF NOT EXISTS working_hours_end time,
  ADD COLUMN IF NOT EXISTS status_updated_at timestamp with time zone DEFAULT now();

-- Add constraint for valid status values
ALTER TABLE public.maintenance_users
  DROP CONSTRAINT IF EXISTS maintenance_users_availability_status_check;

ALTER TABLE public.maintenance_users
  ADD CONSTRAINT maintenance_users_availability_status_check
  CHECK (availability_status IN (
    'online', 'offline', 'busy', 'available', 'on_leave', 'working', 'break'
  ));

-- Enable Realtime for maintenance_users so admins see live status changes
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_users;
