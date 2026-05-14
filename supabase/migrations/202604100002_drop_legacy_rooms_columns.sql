-- Drop legacy room columns that are no longer part of the rooms model.
-- Safe to run multiple times.

ALTER TABLE public.rooms DROP COLUMN IF EXISTS room_number;
ALTER TABLE public.rooms DROP COLUMN IF EXISTS description;
ALTER TABLE public.rooms DROP COLUMN IF EXISTS equipment;
ALTER TABLE public.room_types DROP COLUMN IF EXISTS code;
DROP TABLE IF EXISTS public.room_schedules CASCADE;
