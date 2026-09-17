-- Drop the unused 'office' column from admin_users table
ALTER TABLE public.admin_users
DROP COLUMN IF EXISTS office;
