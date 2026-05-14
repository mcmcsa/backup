-- Normalize work_requests actor columns.
-- Keep: requestor_id, assigned_to_id, accepted_date
-- Drop: reported_by_id, accepted_by_id

BEGIN;

-- Backfill accepted_date if older rows only tracked accepted_by_id.
UPDATE public.work_requests
SET accepted_date = COALESCE(accepted_date, maintenance_start_time, approved_date, created_at)
WHERE accepted_date IS NULL
  AND accepted_by_id IS NOT NULL;

-- Prefer acceptance signature timestamp when available.
UPDATE public.work_requests wr
SET accepted_date = es.first_signed_at
FROM (
  SELECT work_request_id, MIN(signed_at) AS first_signed_at
  FROM public.e_signatures
  WHERE signature_type = 'acceptance'
  GROUP BY work_request_id
) es
WHERE wr.id = es.work_request_id
  AND wr.accepted_date IS NULL;

-- Recreate RLS policies before dropping columns they reference.
DROP POLICY IF EXISTS work_requests_select_policy ON public.work_requests;
CREATE POLICY work_requests_select_policy ON public.work_requests
FOR SELECT
USING (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR approved_by_id = auth.uid()
  OR assigned_to_id = auth.uid()
);

DROP POLICY IF EXISTS work_requests_insert_policy ON public.work_requests;
CREATE POLICY work_requests_insert_policy ON public.work_requests
FOR INSERT
WITH CHECK (
  public.is_admin()
  OR requestor_id = auth.uid()
);

DROP POLICY IF EXISTS work_requests_update_policy ON public.work_requests;
CREATE POLICY work_requests_update_policy ON public.work_requests
FOR UPDATE
USING (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR assigned_to_id = auth.uid()
)
WITH CHECK (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR assigned_to_id = auth.uid()
);

-- Remove no-longer-needed actor columns.
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS reported_by_id CASCADE;
ALTER TABLE public.work_requests DROP COLUMN IF EXISTS accepted_by_id CASCADE;

COMMIT;
