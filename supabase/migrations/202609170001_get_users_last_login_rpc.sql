-- Migration: Function and trigger to track users' last sign-in accurately.
-- Exposes get_users_last_login() RPC so System Admin can query last logins directly from auth.users.

-- 1. Create RPC function to get last logins for all users from auth.users
CREATE OR REPLACE FUNCTION public.get_users_last_login()
RETURNS TABLE (
  user_id UUID,
  last_sign_in_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT id AS user_id, last_sign_in_at
  FROM auth.users
  WHERE last_sign_in_at IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.get_users_last_login() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_users_last_login() TO anon;

-- 2. Optional: Add last_login column to public.users and backfill from auth.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;

UPDATE public.users u
SET last_login = a.last_sign_in_at
FROM auth.users a
WHERE u.id = a.id AND a.last_sign_in_at IS NOT NULL;

-- 3. Automatic trigger on auth.users to keep public.users.last_login synced
CREATE OR REPLACE FUNCTION public.sync_user_last_login()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.last_sign_in_at IS DISTINCT FROM OLD.last_sign_in_at THEN
    UPDATE public.users
    SET last_login = NEW.last_sign_in_at
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_last_login ON auth.users;
CREATE TRIGGER on_auth_user_last_login
AFTER UPDATE OF last_sign_in_at ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_last_login();
