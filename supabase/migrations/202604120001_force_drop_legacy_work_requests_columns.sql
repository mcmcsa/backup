-- Force-remove legacy denormalized columns from work_requests.
-- Safe to run repeatedly because each column uses IF EXISTS.

BEGIN;

ALTER TABLE public.work_requests DROP COLUMN IF EXISTS building_name CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS department CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS office_room CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS requestor_name CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS requestor_position CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS reported_by CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS approved_by CASCADE;

COMMIT;
