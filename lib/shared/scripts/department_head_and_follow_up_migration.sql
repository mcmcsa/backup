-- ==============================================================================
-- Department Head Approval Routing, Room Validation & Work Request Follow-Ups
-- ==============================================================================

-- 1. Departments Table: Add official Department Head relationship
ALTER TABLE public.departments 
ADD COLUMN IF NOT EXISTS head_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_departments_head_user ON public.departments(head_user_id);

-- 2. Work Requests Table: Add Department Head approval tracking columns
-- Note: ON DELETE RESTRICT ensures historical snapshot integrity for audit purposes;
-- user accounts must be soft-deactivated (is_active = false), never hard-deleted.
ALTER TABLE public.work_requests
ADD COLUMN IF NOT EXISTS dept_head_id UUID REFERENCES public.users(id) ON DELETE RESTRICT,
ADD COLUMN IF NOT EXISTS dept_head_status VARCHAR(50) NOT NULL DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS dept_head_approved_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS dept_head_notes TEXT;

CREATE INDEX IF NOT EXISTS idx_work_requests_dept_head ON public.work_requests(dept_head_id, dept_head_status);
CREATE INDEX IF NOT EXISTS idx_work_requests_dept_id ON public.work_requests(department_id);

-- 3. Update E-Signatures signature_type check constraint to permit dept_head_approval
ALTER TABLE public.e_signatures DROP CONSTRAINT IF EXISTS e_signatures_signature_type_check;
ALTER TABLE public.e_signatures ADD CONSTRAINT e_signatures_signature_type_check
  CHECK (signature_type IN (
    'requestor',
    'approval',
    'acceptance',
    'pre_inspection',
    'pre_inspection_admin',
    'post_repair',
    'completion',
    'dept_head_approval'
  ));

-- 4. Work Request Follow-Ups Table
CREATE TABLE IF NOT EXISTS public.work_request_follow_ups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  requestor_id UUID NOT NULL REFERENCES public.users(id),
  message TEXT NOT NULL,
  target_stage VARCHAR(50) NOT NULL DEFAULT 'dept_head', -- 'dept_head' or 'campus_admin'
  recipient_user_id UUID REFERENCES public.users(id),
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'acknowledged', 'replied'
  admin_response TEXT,
  responded_by UUID REFERENCES public.users(id),
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wr_followups_request ON public.work_request_follow_ups(work_request_id);
CREATE INDEX IF NOT EXISTS idx_wr_followups_requestor ON public.work_request_follow_ups(requestor_id);

-- 5. Trigger Function: Room-to-Department Validation (Layer 3)
CREATE OR REPLACE FUNCTION check_work_request_department_room()
RETURNS TRIGGER AS $$
DECLARE
  u_role TEXT;
  u_dept UUID;
  r_dept UUID;
BEGIN
  -- Determine requestor role
  SELECT role INTO u_role FROM public.users WHERE id = NEW.requestor_id;
  
  -- Query room department
  SELECT department_id INTO r_dept FROM public.rooms WHERE id = NEW.room_id;

  -- Validation only applies to teacher / faculty / student requestors, not admin direct override
  IF u_role = 'teacher' THEN
    SELECT department_id INTO u_dept FROM public.teacher_users WHERE user_id = NEW.requestor_id;
    
    IF u_dept IS NULL THEN
      RAISE EXCEPTION 'Requestor has no assigned department in the system.';
    END IF;
    
    -- Case 1: Room belongs to a department
    IF r_dept IS NOT NULL THEN
      IF u_dept != r_dept THEN
        RAISE EXCEPTION 'Access Denied: Room does not belong to requestor department.';
      END IF;
      
      -- Ensure work request department_id matches room's department
      NEW.department_id := r_dept;
    ELSE
      -- Case 2: Room has NO Department (Comfort Room, Lobby, Hallway, Common Area)
      -- Allow the request without requiring room.department_id
      -- Do NOT assign requestor's department to the Room or the Work Request
      -- Do NOT assign a Department Head; allow direct Campus Admin routing
      NEW.department_id := NULL;
      NEW.dept_head_id := NULL;
      NEW.dept_head_status := 'not_applicable';
    END IF;
  ELSE
    -- Non-teacher requestors (admin, campadmin, maintenance, etc.)
    IF r_dept IS NULL THEN
      NEW.department_id := NULL;
      NEW.dept_head_id := NULL;
      NEW.dept_head_status := 'not_applicable';
    ELSE
      NEW.department_id := r_dept;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_work_request_room ON public.work_requests;
CREATE TRIGGER trg_check_work_request_room
BEFORE INSERT ON public.work_requests
FOR EACH ROW EXECUTE FUNCTION check_work_request_department_room();

-- 6. Trigger Function: Validate Department Head Assignment
CREATE OR REPLACE FUNCTION validate_department_head_assignment()
RETURNS TRIGGER AS $$
DECLARE
  head_is_active BOOLEAN;
  head_dept_id UUID;
BEGIN
  IF NEW.head_user_id IS NOT NULL THEN
    SELECT is_active INTO head_is_active FROM public.users WHERE id = NEW.head_user_id;
    IF head_is_active IS NULL OR head_is_active = false THEN
      RAISE EXCEPTION 'Designated Department Head user must be an active user account.';
    END IF;
    
    SELECT department_id INTO head_dept_id FROM public.teacher_users WHERE user_id = NEW.head_user_id;
    IF head_dept_id IS NULL OR head_dept_id != NEW.id THEN
      RAISE EXCEPTION 'Designated Department Head user must belong to this department.';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_department_head ON public.departments;
CREATE TRIGGER trg_validate_department_head
BEFORE INSERT OR UPDATE OF head_user_id ON public.departments
FOR EACH ROW EXECUTE FUNCTION validate_department_head_assignment();

-- 7. Row Level Security Policies for Follow-Ups
ALTER TABLE public.work_request_follow_ups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read follow ups"
  ON public.work_request_follow_ups FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Allow users to insert their own follow ups"
  ON public.work_request_follow_ups FOR INSERT
  WITH CHECK (requestor_id = auth.uid());

CREATE POLICY "Allow admins and dept heads to update follow ups"
  ON public.work_request_follow_ups FOR UPDATE
  USING (
    responded_by = auth.uid() OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'campadmin')) OR
    EXISTS (SELECT 1 FROM public.departments WHERE head_user_id = auth.uid())
  );
