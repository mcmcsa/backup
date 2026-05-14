-- Drop deprecated work_requests columns that are no longer written by the app.
-- Safe to run repeatedly.

BEGIN;

ALTER TABLE public.work_requests DROP COLUMN IF EXISTS accepted_by_name_snapshot CASCADE;

COMMIT;
