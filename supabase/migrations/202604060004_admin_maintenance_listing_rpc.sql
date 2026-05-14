-- Admin RPCs for maintenance management listing/count to avoid RLS join edge cases.
-- Date: 2026-04-06

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
      m.phone::text,
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
      m.phone::text,
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

CREATE OR REPLACE FUNCTION public.get_admin_teacher_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  total_count INTEGER;
BEGIN
  IF NOT public.is_admin()
     AND COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '') <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can access teacher count';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO total_count
  FROM public.users
  WHERE role = 'teacher';

  RETURN total_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_admin_teacher_count() TO authenticated;
