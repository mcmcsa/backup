-- Repair Supabase Auth schema access after role / trigger changes.
-- Date: 2026-07-02
--
-- Symptom fixed:
--   Auth API returns:
--   {"error_code":"unexpected_failure","msg":"Database error querying schema"}
--
-- Apply this in Supabase SQL Editor or with a privileged database connection.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    GRANT USAGE ON SCHEMA auth TO supabase_auth_admin;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
    GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA auth TO supabase_auth_admin;

    ALTER DEFAULT PRIVILEGES IN SCHEMA auth
      GRANT ALL PRIVILEGES ON TABLES TO supabase_auth_admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA auth
      GRANT ALL PRIVILEGES ON SEQUENCES TO supabase_auth_admin;
    ALTER DEFAULT PRIVILEGES IN SCHEMA auth
      GRANT ALL PRIVILEGES ON FUNCTIONS TO supabase_auth_admin;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_name text;
  resolved_role text;
BEGIN
  resolved_name := COALESCE(
    NULLIF(new.raw_user_meta_data->>'name', ''),
    split_part(COALESCE(new.email, ''), '@', 1)
  );

  resolved_role := lower(COALESCE(new.raw_user_meta_data->>'role', 'teacher'));
  IF resolved_role NOT IN ('admin', 'campadmin', 'teacher', 'maintenance') THEN
    resolved_role := 'teacher';
  END IF;

  INSERT INTO public.users (
    id,
    email,
    name,
    role,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    resolved_name,
    resolved_role,
    true,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    updated_at = CURRENT_TIMESTAMP;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_profile();

CREATE OR REPLACE FUNCTION public.activate_verified_faculty_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF new.email_confirmed_at IS NOT NULL THEN
    UPDATE public.users
      SET is_active = true,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = new.id
        AND role = 'teacher';
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_verified ON auth.users;
CREATE TRIGGER on_auth_user_verified
AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.activate_verified_faculty_user();
