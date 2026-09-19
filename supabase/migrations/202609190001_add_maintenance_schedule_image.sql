-- ==============================================================================
-- Add schedule_image_url column to maintenance_users table
-- ==============================================================================

ALTER TABLE public.maintenance_users
  ADD COLUMN IF NOT EXISTS schedule_image_url text;
