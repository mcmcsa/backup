-- Enforce unique Maintenance ID across active and archived maintenance records.
-- Date: 2026-04-06

CREATE OR REPLACE FUNCTION public.enforce_unique_maintenance_employee_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.employee_id IS NULL OR btrim(NEW.employee_id) = '' THEN
    RETURN NEW;
  END IF;

  NEW.employee_id := btrim(NEW.employee_id);

  IF TG_TABLE_NAME = 'maintenance_users' THEN
    IF EXISTS (
      SELECT 1
      FROM public.maintenance_users mu
      WHERE mu.employee_id = NEW.employee_id
        AND mu.user_id <> NEW.user_id
    ) THEN
      RAISE EXCEPTION 'Maintenance ID already exists';
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1
      FROM public.maintenance_users mu
      WHERE mu.employee_id = NEW.employee_id
        AND mu.user_id <> NEW.user_id
    ) THEN
      RAISE EXCEPTION 'Maintenance ID already exists';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_maintenance_users_unique_employee_id ON maintenance_users;
CREATE TRIGGER trg_maintenance_users_unique_employee_id
BEFORE INSERT OR UPDATE ON maintenance_users
FOR EACH ROW EXECUTE FUNCTION public.enforce_unique_maintenance_employee_id();
