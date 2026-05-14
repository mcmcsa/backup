-- Make work_requests columns optional (remove NOT NULL constraints)
-- These snapshot columns should be optional since they may not always be available at submission

BEGIN;

ALTER TABLE public.work_requests 
  ALTER COLUMN building_name_snapshot DROP NOT NULL;

ALTER TABLE public.work_requests 
  ALTER COLUMN department_snapshot DROP NOT NULL;

ALTER TABLE public.work_requests 
  ALTER COLUMN office_room_snapshot DROP NOT NULL;

ALTER TABLE public.work_requests 
  ALTER COLUMN requestor_name_snapshot DROP NOT NULL;

ALTER TABLE public.work_requests 
  ALTER COLUMN requestor_position_snapshot DROP NOT NULL;

ALTER TABLE public.work_requests 
  ALTER COLUMN type_of_request_snapshot DROP NOT NULL;

COMMIT;
