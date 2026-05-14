-- Add missing rooms.department_snapshot column for environments that were created before snapshot columns existed.

ALTER TABLE public.rooms
ADD COLUMN IF NOT EXISTS department_snapshot VARCHAR(150);
