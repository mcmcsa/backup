-- Automatic DB-level audit logs for admin data mutations.
-- Captures INSERT/UPDATE/DELETE across core tables into admin_activity_logs.

CREATE OR REPLACE FUNCTION public.log_admin_table_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
  v_name TEXT;
  v_role TEXT;
  v_payload JSONB;
  v_record_id TEXT;
  v_work_request_id TEXT;
  v_title TEXT;
BEGIN
  -- Never recurse on the logs table itself.
  IF TG_TABLE_NAME = 'admin_activity_logs' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT u.name, u.role
  INTO v_name, v_role
  FROM public.users u
  WHERE u.id = v_uid
  LIMIT 1;

  IF COALESCE(v_role, '') <> 'admin' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_payload := to_jsonb(OLD);
  ELSE
    v_payload := to_jsonb(NEW);
  END IF;

  v_record_id := COALESCE(
    v_payload ->> 'id',
    v_payload ->> 'user_id',
    v_payload ->> 'maintenance_id',
    v_payload ->> 'work_request_id'
  );
  v_work_request_id := v_payload ->> 'work_request_id';

  v_title := format('Admin %s on %s', TG_OP, TG_TABLE_NAME);

  INSERT INTO public.admin_activity_logs (
    user_id,
    user_name,
    role,
    event_type,
    title,
    details,
    work_request_id,
    logged_at
  )
  VALUES (
    v_uid,
    COALESCE(v_name, 'Admin'),
    'admin',
    'action',
    v_title,
    jsonb_build_object(
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'operation', TG_OP,
      'record_id', v_record_id
    )::TEXT,
    v_work_request_id,
    CURRENT_TIMESTAMP
  );

  RETURN COALESCE(NEW, OLD);
EXCEPTION
  WHEN OTHERS THEN
    -- Audit logging should not block primary transaction.
    RETURN COALESCE(NEW, OLD);
END;
$$;

DO $$
DECLARE
  table_name TEXT;
  table_list TEXT[] := ARRAY[
    'users',
    'departments',
    'buildings',
    'room_types',
    'floors',
    'rooms',
    'qr_code_history',
    'maintenance_users',
    'maintenance_user_archives',
    'teacher_users',
    'request_types',
    'work_requests',
    'e_signatures',
    'pre_inspection_reports',
    'post_repair_reports',
    'app_notifications'
  ];
BEGIN
  FOREACH table_name IN ARRAY table_list
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS %I ON public.%I',
      'trg_admin_audit_' || table_name,
      table_name
    );

    EXECUTE format(
      'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.log_admin_table_mutation()',
      'trg_admin_audit_' || table_name,
      table_name
    );
  END LOOP;
END $$;
