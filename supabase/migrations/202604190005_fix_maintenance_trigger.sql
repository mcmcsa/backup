-- Fix maintenance_users trigger to ensure proper operation
-- Recreate the trigger function with better error handling

DROP TRIGGER IF EXISTS trg_maintenance_users_unique_employee_id ON public.maintenance_users;
DROP TRIGGER IF EXISTS trg_maintenance_user_archives_unique_employee_id ON public.maintenance_user_archives;
DROP FUNCTION IF EXISTS public.enforce_unique_maintenance_employee_id() CASCADE;

CREATE OR REPLACE FUNCTION public.enforce_unique_maintenance_employee_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Only enforce if employee_id is provided
  IF NEW.employee_id IS NULL OR NEW.employee_id = '' THEN
    RETURN NEW;
  END IF;

  -- Trim the employee_id
  NEW.employee_id := TRIM(NEW.employee_id);

  -- Check if this employee_id already exists for a different user
  IF EXISTS (
    SELECT 1
    FROM public.maintenance_users
    WHERE LOWER(employee_id) = LOWER(NEW.employee_id)
      AND user_id <> NEW.user_id
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'Maintenance ID already exists';
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger only on maintenance_users table
-- maintenance_user_archives doesn't have employee_id column, so trigger doesn't apply
CREATE TRIGGER trg_maintenance_users_unique_employee_id
BEFORE INSERT OR UPDATE ON public.maintenance_users
FOR EACH ROW EXECUTE FUNCTION public.enforce_unique_maintenance_employee_id();
