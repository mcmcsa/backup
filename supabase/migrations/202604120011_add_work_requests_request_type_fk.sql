-- Restore missing FK from work_requests.request_type_id to request_types.id
-- Needed for PostgREST relation selects like request_type:request_types(...)

BEGIN;

-- Clean up invalid values so FK can be created safely.
UPDATE public.work_requests wr
SET request_type_id = NULL
WHERE request_type_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.request_types rt
    WHERE rt.id = wr.request_type_id
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'work_requests_request_type_id_fkey'
      AND conrelid = 'public.work_requests'::regclass
  ) THEN
    ALTER TABLE public.work_requests
      ADD CONSTRAINT work_requests_request_type_id_fkey
      FOREIGN KEY (request_type_id)
      REFERENCES public.request_types(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_work_requests_request_type_id
  ON public.work_requests(request_type_id);

COMMIT;
