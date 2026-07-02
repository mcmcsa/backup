-- Migration: Add campadmin role and update constraints / helper functions
-- Date: 2026-07-02

-- 1. Alter check constraint on users table
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('admin', 'campadmin', 'teacher', 'maintenance'));

-- 2. Alter check constraint on e_signatures table
ALTER TABLE public.e_signatures DROP CONSTRAINT IF EXISTS e_signatures_signer_role_check;
ALTER TABLE public.e_signatures ADD CONSTRAINT e_signatures_signer_role_check CHECK (signer_role IN ('admin', 'campadmin', 'maintenance', 'teacher'));

-- 3. Alter check constraint on app_notifications table
ALTER TABLE public.app_notifications DROP CONSTRAINT IF EXISTS app_notifications_target_role_check;
ALTER TABLE public.app_notifications ADD CONSTRAINT app_notifications_target_role_check CHECK (target_role IN ('all', 'admin', 'campadmin', 'teacher', 'maintenance'));

-- 4. Update is_admin() function to support both admin and campadmin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.current_user_role() IN ('admin', 'campadmin'), false)
$$;

-- 5. Keep the seeded system admin as admin; campus admins should be assigned
--    explicitly through the app or a targeted data migration.
