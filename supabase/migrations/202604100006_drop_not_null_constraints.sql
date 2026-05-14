-- Force drop NOT NULL constraint from building_name column if it exists
-- This handles both old column names and new snapshot names

BEGIN;

-- Try to alter building_name column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'building_name'
  ) THEN
    ALTER TABLE public.work_requests 
      ALTER COLUMN building_name DROP NOT NULL;
  END IF;
END $$;

-- Try to alter department column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'department'
  ) THEN
    ALTER TABLE public.work_requests 
      ALTER COLUMN department DROP NOT NULL;
  END IF;
END $$;

-- Try to alter office_room column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'office_room'
  ) THEN
    ALTER TABLE public.work_requests 
      ALTER COLUMN office_room DROP NOT NULL;
  END IF;
END $$;

-- Try to alter requestor_name column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'requestor_name'
  ) THEN
    ALTER TABLE public.work_requests 
      ALTER COLUMN requestor_name DROP NOT NULL;
  END IF;
END $$;

-- Try to alter requestor_position column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'requestor_position'
  ) THEN
    ALTER TABLE public.work_requests 
      ALTER COLUMN requestor_position DROP NOT NULL;
  END IF;
END $$;

-- Try to alter type_of_request column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'work_requests' AND column_name = 'type_of_request'
  ) THEN
    ALTER TABLE public.work_requests 
      ALTER COLUMN type_of_request DROP NOT NULL;
  END IF;
END $$;

COMMIT;
