-- Remove trigger from maintenance_user_archives table
-- The trigger tries to access employee_id field which doesn't exist on this table
-- Date: 2026-04-20

DROP TRIGGER IF EXISTS trg_maintenance_user_archives_unique_employee_id ON public.maintenance_user_archives;
