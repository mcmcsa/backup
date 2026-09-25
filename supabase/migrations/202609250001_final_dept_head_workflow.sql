-- Migration: 202609250001_final_dept_head_workflow.sql
-- Description: Implement final Department Head workflow, constraints, e-signature role, RLS policies, and cancellation support.

-- 1. Add Department Head evaluated date and cancellation tracking columns to work_requests
ALTER TABLE public.work_requests
ADD COLUMN IF NOT EXISTS dept_head_evaluated_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS cancellation_reason_type TEXT,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_work_requests_cancelled ON public.work_requests(cancelled_by, cancelled_at);

-- 2. Update work_requests status check constraint to support full workflow statuses:
-- 'Pending Department Head', 'Pending Campus Admin', 'Pending', 'In Progress', 'Acknowledged', 'Approved', 'Declined', 'Confirmed', 'Rework', 'Completed', 'Cancelled'
ALTER TABLE public.work_requests DROP CONSTRAINT IF EXISTS work_requests_status_check;
ALTER TABLE public.work_requests ADD CONSTRAINT work_requests_status_check CHECK (
  status IN (
    'Pending Department Head',
    'Pending Campus Admin',
    'Pending',
    'In Progress',
    'Acknowledged',
    'Approved',
    'Declined',
    'Confirmed',
    'Rework',
    'Completed',
    'Cancelled'
  )
);

-- 3. Update dept_head_status check constraint: 'pending', 'approved', 'acknowledged', 'not_applicable', 'declined'
ALTER TABLE public.work_requests DROP CONSTRAINT IF EXISTS work_requests_dept_head_status_check;
ALTER TABLE public.work_requests ADD CONSTRAINT work_requests_dept_head_status_check CHECK (
  dept_head_status IN ('pending', 'approved', 'acknowledged', 'not_applicable', 'declined')
);

-- 4. Update e_signatures check constraints:
-- Permit 'dept_head' as signer_role
ALTER TABLE public.e_signatures DROP CONSTRAINT IF EXISTS e_signatures_signer_role_check;
ALTER TABLE public.e_signatures ADD CONSTRAINT e_signatures_signer_role_check CHECK (
  signer_role IN ('admin', 'campadmin', 'maintenance', 'teacher', 'dept_head')
);

-- Permit 'dept_head_approval' and 'dept_head_acknowledgement' as signature_type
ALTER TABLE public.e_signatures DROP CONSTRAINT IF EXISTS e_signatures_signature_type_check;
ALTER TABLE public.e_signatures ADD CONSTRAINT e_signatures_signature_type_check CHECK (
  signature_type IN (
    'requestor',
    'approval',
    'acceptance',
    'pre_inspection',
    'pre_inspection_admin',
    'post_repair',
    'completion',
    'dept_head_approval',
    'dept_head_acknowledgement'
  )
);

-- 5. Trigger Function: Enforce Campus Admin Cannot Bypass Pending Department Head
CREATE OR REPLACE FUNCTION enforce_dept_head_workflow_guard()
RETURNS TRIGGER AS $$
BEGIN
  -- When request is pending Department Head review:
  IF OLD.dept_head_status = 'pending' THEN
    -- Prevent assigning maintenance
    IF NEW.assigned_to_id IS NOT NULL AND (OLD.assigned_to_id IS NULL OR OLD.assigned_to_id != NEW.assigned_to_id) THEN
      RAISE EXCEPTION 'Action Denied: Cannot assign maintenance while request is pending Department Head review.';
    END IF;
    
    -- Prevent admin approval
    IF NEW.approved_by_id IS NOT NULL AND OLD.approved_by_id IS NULL THEN
      RAISE EXCEPTION 'Action Denied: Cannot approve request while pending Department Head review.';
    END IF;
    
    -- Prevent advancing status past Department Head unless Dept Head is approving or acknowledging or requestor is cancelling
    IF NEW.status NOT IN ('Pending Department Head', 'Pending Campus Admin', 'Acknowledged', 'Cancelled', 'Declined') THEN
      RAISE EXCEPTION 'Action Denied: Invalid status transition while pending Department Head review.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_dept_head_workflow ON public.work_requests;
CREATE TRIGGER trg_enforce_dept_head_workflow
BEFORE UPDATE ON public.work_requests
FOR EACH ROW EXECUTE FUNCTION enforce_dept_head_workflow_guard();

-- 6. Row Level Security Policies for work_requests:
-- Department Heads must be able to view and update (endorse/acknowledge) requests routed to their department
DROP POLICY IF EXISTS work_requests_select_policy ON public.work_requests;
CREATE POLICY work_requests_select_policy ON public.work_requests
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR requestor_id = auth.uid()
    OR approved_by_id = auth.uid()
    OR assigned_to_id = auth.uid()
    OR dept_head_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.departments d
      WHERE d.id = work_requests.department_id AND d.head_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS work_requests_update_policy ON public.work_requests;
CREATE POLICY work_requests_update_policy ON public.work_requests
  FOR UPDATE TO authenticated
  USING (
    public.is_admin()
    OR requestor_id = auth.uid()
    OR assigned_to_id = auth.uid()
    OR dept_head_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.departments d
      WHERE d.id = work_requests.department_id AND d.head_user_id = auth.uid()
    )
  )
  WITH CHECK (
    public.is_admin()
    OR requestor_id = auth.uid()
    OR assigned_to_id = auth.uid()
    OR dept_head_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.departments d
      WHERE d.id = work_requests.department_id AND d.head_user_id = auth.uid()
    )
  );

-- 7. Row Level Security Policies for work_request_follow_ups:
-- Restrict reading follow-ups to authorized parties (requestor, recipient, admin, dept head of the department)
DROP POLICY IF EXISTS "Allow authenticated users to read follow ups" ON public.work_request_follow_ups;
DROP POLICY IF EXISTS "Allow authorized users to read follow ups" ON public.work_request_follow_ups;
CREATE POLICY "Allow authorized users to read follow ups"
  ON public.work_request_follow_ups FOR SELECT
  USING (
    public.is_admin()
    OR requestor_id = auth.uid()
    OR recipient_user_id = auth.uid()
    OR (
      target_stage = 'dept_head' AND EXISTS (
        SELECT 1 FROM public.work_requests wr
        JOIN public.departments d ON d.id = wr.department_id
        WHERE wr.id = work_request_follow_ups.work_request_id
          AND d.head_user_id = auth.uid()
      )
    )
  );
