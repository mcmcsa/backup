-- Remove legacy campus attribute from users table.
-- Remove code attribute from work_requests table.
-- Safe to run multiple times.

ALTER TABLE public.users DROP COLUMN IF EXISTS campus;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS code;

