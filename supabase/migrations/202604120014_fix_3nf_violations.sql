-- Remove denormalized columns that violate 3NF now that the app reads from normalized relations.
-- This migration is safe to run repeatedly.

BEGIN;

ALTER TABLE public.work_requests
  DROP COLUMN IF EXISTS requestor_name,
  DROP COLUMN IF EXISTS requestor_position,
  DROP COLUMN IF EXISTS type_of_request;

ALTER TABLE public.qr_code_history
  DROP COLUMN IF EXISTS room_name,
  DROP COLUMN IF EXISTS building,
  DROP COLUMN IF EXISTS department;

-- Intentional audit snapshots: these columns preserve the human-readable actor data at the time of the event.
COMMENT ON COLUMN public.e_signatures.signer_name IS 'Intentional audit snapshot: stores the signer name at the time of signature.';
COMMENT ON COLUMN public.e_signatures.signer_role IS 'Intentional audit snapshot: stores the signer role at the time of signature.';
COMMENT ON COLUMN public.pre_inspection_reports.inspector_name IS 'Intentional audit snapshot: stores the inspector name at the time of inspection.';
COMMENT ON COLUMN public.post_repair_reports.technician_name IS 'Intentional audit snapshot: stores the technician name at the time of repair.';

COMMIT;