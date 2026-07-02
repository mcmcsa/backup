-- Fix handle_new_user_profile trigger to support campadmin role
-- Date: 2026-07-02

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
  -- Allow admin, campadmin, teacher, maintenance
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
