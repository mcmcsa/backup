-- Atomic archive/restore RPCs for maintenance accounts.
-- These keep the archive table and users.is_active in sync in one server-side step.

CREATE OR REPLACE FUNCTION public.archive_maintenance_account(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id UUID;
  v_created_at TIMESTAMP WITH TIME ZONE;
BEGIN
  IF NOT public.is_admin()
     AND COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '') <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can archive maintenance accounts';
  END IF;

  v_admin_id := auth.uid();

  SELECT COALESCE(m.created_at, u.created_at)
  INTO v_created_at
  FROM public.users u
  LEFT JOIN public.maintenance_users m ON m.user_id = u.id
  WHERE u.id = p_user_id
    AND u.role = 'maintenance'
  LIMIT 1;

  IF v_created_at IS NULL THEN
    RAISE EXCEPTION 'Maintenance account not found';
  END IF;

  INSERT INTO public.maintenance_user_archives (
    maintenance_id,
    archived_by_admin_id,
    archive_at,
    original_created_at
  )
  VALUES (
    p_user_id,
    v_admin_id,
    CURRENT_TIMESTAMP,
    v_created_at
  )
  ON CONFLICT (maintenance_id) DO UPDATE
    SET archived_by_admin_id = EXCLUDED.archived_by_admin_id,
        archive_at = EXCLUDED.archive_at,
        original_created_at = COALESCE(
          public.maintenance_user_archives.original_created_at,
          EXCLUDED.original_created_at
        );

  UPDATE public.users
  SET is_active = false,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.archive_maintenance_account(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.restore_maintenance_account(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin()
     AND COALESCE(auth.jwt() -> 'user_metadata' ->> 'role', '') <> 'admin' THEN
    RAISE EXCEPTION 'Only admin can restore maintenance accounts';
  END IF;

  UPDATE public.users
  SET is_active = true,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;

  DELETE FROM public.maintenance_user_archives
  WHERE maintenance_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.restore_maintenance_account(UUID) TO authenticated;
