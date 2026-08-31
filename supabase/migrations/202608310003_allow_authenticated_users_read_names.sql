-- Allow all authenticated users to read public user profile details (id, name, role, profile_image)
-- This fixes the issue where maintenance technicians are unable to fetch the requestor's name due to RLS policies.

BEGIN;

DROP POLICY IF EXISTS users_select_policy ON public.users;

CREATE POLICY users_select_policy ON public.users
FOR SELECT
TO authenticated
USING (true);

COMMIT;
