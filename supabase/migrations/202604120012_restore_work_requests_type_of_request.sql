-- Restore the human-readable type_of_request column on work_requests.
-- This preserves the submitted request type label alongside request_type_id.

BEGIN;

ALTER TABLE public.work_requests
  ADD COLUMN IF NOT EXISTS type_of_request VARCHAR(255);

-- Backfill from the normalized request_types table when possible.
UPDATE public.work_requests wr
SET type_of_request = rt.name
FROM public.request_types rt
WHERE wr.request_type_id = rt.id
  AND (wr.type_of_request IS NULL OR btrim(wr.type_of_request) = '');

-- As a fallback, use the current request_type_id text value if it looks like a label.
UPDATE public.work_requests
SET type_of_request = request_type_id::text
WHERE type_of_request IS NULL
  AND request_type_id IS NOT NULL;

COMMIT;
