-- Migration: Fix priority column so new work requests don't auto-get 'medium'
-- Date: 2026-08-27
-- Reason: Priority should only be set by admin during approval, not on submission.

-- 1. Drop the old check constraint
ALTER TABLE public.work_requests DROP CONSTRAINT IF EXISTS work_requests_priority_check;

-- 2. Make priority nullable and remove the default
ALTER TABLE public.work_requests
  ALTER COLUMN priority DROP DEFAULT,
  ALTER COLUMN priority DROP NOT NULL;

-- 3. Set existing 'medium' priority rows that are still Pending to NULL
--    (they got 'medium' from the old default, not from an admin decision)
UPDATE public.work_requests
SET priority = NULL
WHERE status = 'Pending' AND priority = 'medium';

-- 4. Add new check constraint that allows NULL and ensures only valid priorities are used
ALTER TABLE public.work_requests
  ADD CONSTRAINT work_requests_priority_check
  CHECK (priority IS NULL OR priority IN ('low', 'medium', 'high'));
