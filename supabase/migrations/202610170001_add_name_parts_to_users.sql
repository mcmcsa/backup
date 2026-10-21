-- Migration: Add first_name, middle_name, and last_name to public.users
-- Date: 2026-10-17

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS first_name VARCHAR(150);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS middle_name VARCHAR(150);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_name VARCHAR(150);

-- Backfill first_name and last_name from existing full name
UPDATE public.users
SET 
  first_name = COALESCE(first_name, split_part(name, ' ', 1)),
  last_name = COALESCE(last_name, CASE 
    WHEN array_length(string_to_array(trim(name), ' '), 1) > 1 
    THEN substr(name, length(split_part(name, ' ', 1)) + 2)
    ELSE ''
  END)
WHERE first_name IS NULL AND name IS NOT NULL AND trim(name) <> '';
