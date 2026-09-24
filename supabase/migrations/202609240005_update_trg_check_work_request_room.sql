-- Migration: 202609240005_update_trg_check_work_request_room.sql
-- Description: Update check_work_request_department_room() trigger function to allow
-- reporting maintenance for department-less rooms (Comfort Rooms, Lobbies, Hallways, Common Facilities)
-- without requiring a department or routing to a Department Head.

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

  -- Validation for teacher / faculty requestors
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

-- Re-assert trigger on public.work_requests
DROP TRIGGER IF EXISTS trg_check_work_request_room ON public.work_requests;
CREATE TRIGGER trg_check_work_request_room
BEFORE INSERT ON public.work_requests
FOR EACH ROW EXECUTE FUNCTION check_work_request_department_room();
