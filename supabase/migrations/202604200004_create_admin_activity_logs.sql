-- Persistent activity logs for admin login and admin actions.

CREATE TABLE IF NOT EXISTS public.admin_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  role TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('login', 'action')),
  title TEXT NOT NULL,
  details TEXT,
  work_request_id TEXT,
  logged_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_logged_at
  ON public.admin_activity_logs(logged_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_role
  ON public.admin_activity_logs(role);

CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_user_id
  ON public.admin_activity_logs(user_id);

ALTER TABLE public.admin_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_activity_logs_select_policy ON public.admin_activity_logs;
CREATE POLICY admin_activity_logs_select_policy
ON public.admin_activity_logs
FOR SELECT
USING (public.is_admin() OR user_id = auth.uid());

DROP POLICY IF EXISTS admin_activity_logs_insert_policy ON public.admin_activity_logs;
CREATE POLICY admin_activity_logs_insert_policy
ON public.admin_activity_logs
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_admin());
