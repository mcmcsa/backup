-- Restore the seeded system admin account after adding the campadmin role.
-- Date: 2026-07-03
--
-- Run this in Supabase SQL Editor after the campadmin migrations.

UPDATE public.users
SET role = 'admin',
    is_active = true,
    updated_at = CURRENT_TIMESTAMP
WHERE lower(email) = 'sysadmin@psu.edu.ph';

UPDATE auth.users
SET raw_user_meta_data =
  COALESCE(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('role', 'admin', 'name', 'System Administrator')
WHERE lower(email) = 'sysadmin@psu.edu.ph';
