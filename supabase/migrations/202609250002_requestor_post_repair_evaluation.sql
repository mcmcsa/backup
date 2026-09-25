-- Migration: 202609250002_requestor_post_repair_evaluation.sql
-- Description: Add Requestor Post-Repair Evaluation workflow fields, constraints, RLS policies, and guards.

-- 1. Add requestor evaluation columns to post_repair_reports table
ALTER TABLE public.post_repair_reports
  ADD COLUMN IF NOT EXISTS requestor_evaluation VARCHAR(20),
  ADD COLUMN IF NOT EXISTS requestor_rating INT,
  ADD COLUMN IF NOT EXISTS requestor_comment TEXT,
  ADD COLUMN IF NOT EXISTS requestor_evaluated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS requestor_evaluated_date TIMESTAMPTZ;

-- 2. Add CHECK constraints for requestor evaluation
ALTER TABLE public.post_repair_reports
  DROP CONSTRAINT IF EXISTS post_repair_reports_requestor_evaluation_check;
ALTER TABLE public.post_repair_reports
  ADD CONSTRAINT post_repair_reports_requestor_evaluation_check
  CHECK (requestor_evaluation IS NULL OR requestor_evaluation IN ('satisfy', 'not_satisfy'));

ALTER TABLE public.post_repair_reports
  DROP CONSTRAINT IF EXISTS post_repair_reports_requestor_rating_check;
ALTER TABLE public.post_repair_reports
  ADD CONSTRAINT post_repair_reports_requestor_rating_check
  CHECK (requestor_rating IS NULL OR (requestor_rating >= 1 AND requestor_rating <= 5));

-- 3. Create index for query performance
CREATE INDEX IF NOT EXISTS idx_post_repair_reports_requestor_eval 
  ON public.post_repair_reports (work_request_id, attempt_number, requestor_evaluation);

-- 4. Update RLS policies for post_repair_reports
-- Requestors must be able to SELECT post repair reports for their own work requests
DROP POLICY IF EXISTS post_repair_reports_select_policy ON public.post_repair_reports;
CREATE POLICY post_repair_reports_select_policy ON public.post_repair_reports
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR technician_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.work_requests wr
      WHERE wr.id = post_repair_reports.work_request_id
        AND (
          wr.requestor_id = auth.uid()
          OR wr.assigned_to_id = auth.uid()
          OR wr.dept_head_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.departments d
            WHERE d.id = wr.department_id AND d.head_user_id = auth.uid()
          )
        )
    )
  );

-- Requestors can UPDATE only the post repair report of their own work request to submit evaluation
DROP POLICY IF EXISTS post_repair_reports_update_policy ON public.post_repair_reports;
CREATE POLICY post_repair_reports_update_policy ON public.post_repair_reports
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR technician_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.work_requests wr
      WHERE wr.id = post_repair_reports.work_request_id
        AND wr.requestor_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin()
    OR technician_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.work_requests wr
      WHERE wr.id = post_repair_reports.work_request_id
        AND wr.requestor_id = auth.uid()
    )
  );

-- 5. Trigger Function: Guard Post-Repair Evaluation transitions
CREATE OR REPLACE FUNCTION enforce_post_repair_evaluation_guard()
RETURNS TRIGGER AS $$
DECLARE
  v_requestor_id UUID;
  v_assigned_to_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  -- Get work request requestor and assignee
  SELECT requestor_id, assigned_to_id
  INTO v_requestor_id, v_assigned_to_id
  FROM public.work_requests
  WHERE id = NEW.work_request_id;

  v_is_admin := public.is_admin();

  -- If an authenticated non-admin user is updating:
  IF NOT v_is_admin THEN
    -- If user is the requestor:
    IF auth.uid() = v_requestor_id THEN
      -- Requestor cannot modify admin evaluation or technician fields or status directly
      IF NEW.admin_evaluation IS DISTINCT FROM OLD.admin_evaluation OR
         NEW.admin_evaluated_by IS DISTINCT FROM OLD.admin_evaluated_by OR
         NEW.status IS DISTINCT FROM OLD.status OR
         NEW.work_performed IS DISTINCT FROM OLD.work_performed THEN
        RAISE EXCEPTION 'Action Denied: Requestor cannot modify administrative evaluation or technician report.';
      END IF;

      -- Requestor must evaluate with valid decision
      IF NEW.requestor_evaluation IS NOT NULL AND NEW.requestor_evaluation NOT IN ('satisfy', 'not_satisfy') THEN
        RAISE EXCEPTION 'Action Denied: Invalid requestor evaluation. Must be satisfy or not_satisfy.';
      END IF;

      -- Requestor cannot evaluate on behalf of someone else
      IF NEW.requestor_evaluated_by IS NOT NULL AND NEW.requestor_evaluated_by != auth.uid() THEN
        RAISE EXCEPTION 'Action Denied: Cannot submit evaluation on behalf of another user.';
      END IF;
    -- If user is technician:
    ELSIF auth.uid() = NEW.technician_id OR auth.uid() = v_assigned_to_id THEN
      -- Maintenance cannot submit requestor evaluation or admin evaluation or mark Completed
      IF NEW.requestor_evaluation IS DISTINCT FROM OLD.requestor_evaluation OR
         NEW.requestor_rating IS DISTINCT FROM OLD.requestor_rating OR
         NEW.requestor_comment IS DISTINCT FROM OLD.requestor_comment OR
         NEW.admin_evaluation IS DISTINCT FROM OLD.admin_evaluation OR
         NEW.status = 'Completed' THEN
        RAISE EXCEPTION 'Action Denied: Maintenance cannot evaluate work or mark post-repair report as completed.';
      END IF;
    ELSE
      -- Neither admin, nor requestor, nor assigned maintenance
      RAISE EXCEPTION 'Action Denied: Unauthorized to update this post-repair report.';
    END IF;
  END IF;

  -- Campus Admin finalization guard:
  -- Admin cannot finalize (satisfied or rework) without a Requestor evaluation
  IF NEW.admin_evaluation IS NOT NULL AND OLD.admin_evaluation IS NULL THEN
    IF NEW.requestor_evaluation IS NULL THEN
      RAISE EXCEPTION 'Action Denied: Campus Admin cannot finalize post-repair decision before the Requestor has submitted an evaluation.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_post_repair_evaluation ON public.post_repair_reports;
CREATE TRIGGER trg_enforce_post_repair_evaluation
BEFORE UPDATE ON public.post_repair_reports
FOR EACH ROW EXECUTE FUNCTION enforce_post_repair_evaluation_guard();
