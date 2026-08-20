-- Force-replace maintenance RPCs to remove legacy references (e.g. ma.employee_id)
-- and align with current schema.

-- 1) Listing RPC used by web/mobile maintenance pages
CREATE OR REPLACE FUNCTION public.get_admin_maintenance_accounts(include_archived BOOLEAN DEFAULT false)
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  full_name TEXT,
  employee_id TEXT,
  specialization TEXT,
  phone TEXT,
  is_active BOOLEAN,
  archived_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  created_by_admin_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin()
     AND COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '') <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can access maintenance accounts';
  END IF;

  IF include_archived THEN
    RETURN QUERY
    SELECT
      u.id AS user_id,
      u.email::text,
      u.name::text AS full_name,
      m.employee_id::text,
      m.specialization::text,
      u.phone::text,
      u.is_active,
      a.archive_at AS archived_at,
      COALESCE(a.original_created_at, m.created_at, u.created_at) AS created_at,
      m.created_by_admin_id
    FROM public.maintenance_user_archives a
    JOIN public.users u ON u.id = a.maintenance_id
    LEFT JOIN public.maintenance_users m ON m.user_id = u.id
    ORDER BY a.archive_at DESC;
  ELSE
    RETURN QUERY
    SELECT
      u.id AS user_id,
      u.email::text,
      u.name::text AS full_name,
      m.employee_id::text,
      m.specialization::text,
      u.phone::text,
      u.is_active,
      NULL::TIMESTAMP WITH TIME ZONE AS archived_at,
      COALESCE(m.created_at, u.created_at) AS created_at,
      m.created_by_admin_id
    FROM public.users u
    LEFT JOIN public.maintenance_users m ON m.user_id = u.id
    WHERE u.role = 'maintenance' AND u.is_active = true
    ORDER BY COALESCE(m.created_at, u.created_at) DESC;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_maintenance_accounts(BOOLEAN) TO authenticated;

-- 2) Recovery RPC used when auth email exists but public profile is missing
DROP FUNCTION IF EXISTS public.recover_maintenance_account_by_email(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.recover_maintenance_account_by_email(TEXT, TEXT, TEXT, TEXT);

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
    phone,
    created_at,
    updated_at
  )
  VALUES (
    v_auth_user_id,
    lower(trim(p_email)),
    trim(p_full_name),
    'maintenance',
    true,
    NULLIF(trim(COALESCE(p_phone, '')), ''),
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = 'maintenance',
    is_active = true,
    phone = EXCLUDED.phone,
    updated_at = CURRENT_TIMESTAMP;

  INSERT INTO public.maintenance_users (
    user_id,
    employee_id,
    specialization,
    created_by_admin_id
  )
  VALUES (
    v_auth_user_id,
    NULLIF(trim(p_employee_id), ''),
    NULLIF(trim(p_specialization), ''),
    v_admin_id
  )
  ON CONFLICT (user_id) DO UPDATE SET
    employee_id = EXCLUDED.employee_id,
    specialization = EXCLUDED.specialization,
    created_by_admin_id = COALESCE(public.maintenance_users.created_by_admin_id, EXCLUDED.created_by_admin_id),
    updated_at = CURRENT_TIMESTAMP;

  RETURN v_auth_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recover_maintenance_account_by_email(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
