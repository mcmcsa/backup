-- Fix Row Level Security (RLS) insert policy for maintenance users
-- Goal: Allow maintenance staff (authenticated users) to insert/upsert their own profile details.
-- Currently, maintenance_users_insert_policy only allows admins to insert records, which blocks upsert operations from the client app.

DROP POLICY IF EXISTS maintenance_users_insert_policy ON public.maintenance_users;

CREATE POLICY maintenance_users_insert_policy ON public.maintenance_users
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_admin());
