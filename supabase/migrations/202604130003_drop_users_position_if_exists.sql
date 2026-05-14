-- Remove legacy redundant users.position column.
-- Position is role-specific and should live in teacher_users/maintenance_users.

BEGIN;

ALTER TABLE public.users
  DROP COLUMN IF EXISTS position;

COMMIT;
