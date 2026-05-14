-- Force removal of campus column from work_requests if it still exists
-- This is a separate migration to ensure it runs after any CREATE TABLE statements

BEGIN;

-- Drop any constraints that might reference this column
ALTER TABLE IF EXISTS public.work_requests 
  DROP COLUMN IF EXISTS campus CASCADE;

COMMIT;
