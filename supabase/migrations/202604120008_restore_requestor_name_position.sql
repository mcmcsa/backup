-- Restore requestor name/position columns on work_requests.
-- These fields preserve submitted identity details for each request row.

BEGIN;

ALTER TABLE public.work_requests
  ADD COLUMN IF NOT EXISTS requestor_name VARCHAR(255),
  ADD COLUMN IF NOT EXISTS requestor_position VARCHAR(100);

-- Backfill requestor_name from users table when missing.
UPDATE public.work_requests wr
SET requestor_name = u.name
FROM public.users u
WHERE wr.requestor_id = u.id
  AND (wr.requestor_name IS NULL OR btrim(wr.requestor_name) = '');

-- Backfill requestor_position from teacher profile first, then maintenance profile.
UPDATE public.work_requests wr
SET requestor_position = tu.position
FROM public.teacher_users tu
WHERE wr.requestor_id = tu.user_id
  AND (wr.requestor_position IS NULL OR btrim(wr.requestor_position) = '');

UPDATE public.work_requests wr
SET requestor_position = mu.specialization
FROM public.maintenance_users mu
WHERE wr.requestor_id = mu.user_id
  AND (wr.requestor_position IS NULL OR btrim(wr.requestor_position) = '');

COMMIT;
