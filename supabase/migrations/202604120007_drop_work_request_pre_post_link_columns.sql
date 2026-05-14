-- Drop redundant parent link columns from work_requests.
-- Child tables already own the relationship via work_request_id.

BEGIN;

ALTER TABLE public.work_requests DROP COLUMN IF EXISTS pre_inspection_id CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS post_repair_id CASCADE;

COMMIT;
