-- Recover maintenance accounts when email exists in auth.users but missing in public.users.
-- Allows admin-side repair instead of failing with "already registered".

CREATE OR REPLACE FUNCTION public.recover_maintenance_account_by_email(
  p_email TEXT,
  p_full_name TEXT,
  p_employee_id TEXT,
  p_specialization TEXT,
  p_phone TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_user_id UUID;
  v_admin_id UUID;
BEGIN
  IF NOT public.is_admin()
     AND COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '') <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can recover maintenance accounts';
  END IF;

  v_admin_id := auth.uid();

  SELECT au.id
  INTO v_auth_user_id
  FROM auth.users au
  WHERE lower(au.email) = lower(trim(p_email))
  LIMIT 1;

  IF v_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'No auth user found for email %', p_email;
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
    v_auth_user_id,
    lower(trim(p_email)),
    trim(p_full_name),
    'maintenance',
    true,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = 'maintenance',
    is_active = true,
    updated_at = CURRENT_TIMESTAMP;

  INSERT INTO public.maintenance_users (
    user_id,
    employee_id,
    specialization,
    phone,
    created_by_admin_id
  )
  VALUES (
    v_auth_user_id,
    trim(p_employee_id),
    trim(p_specialization),
    NULLIF(trim(COALESCE(p_phone, '')), ''),
    v_admin_id
  )
  ON CONFLICT (user_id) DO UPDATE SET
    employee_id = EXCLUDED.employee_id,
    specialization = EXCLUDED.specialization,
    phone = EXCLUDED.phone,
    created_by_admin_id = COALESCE(public.maintenance_users.created_by_admin_id, EXCLUDED.created_by_admin_id),
    updated_at = CURRENT_TIMESTAMP;

  RETURN v_auth_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recover_maintenance_account_by_email(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
