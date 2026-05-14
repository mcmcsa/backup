-- Remove all recovery RPC versions - recovery is now handled app-side
-- This eliminates database RPC permission issues with auth.users access

DROP FUNCTION IF EXISTS public.recover_maintenance_account_by_email(TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.recover_maintenance_account_by_email(TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.recover_maintenance_account_by_email(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.recover_maintenance_account_by_email() CASCADE;
