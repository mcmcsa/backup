-- Migration: Update work_requests status check constraint and migrate existing records (Phase 2)
-- Date: 2026-08-27

-- 1. Drop the old status check constraint first to avoid constraint violation during status update
ALTER TABLE public.work_requests DROP CONSTRAINT IF EXISTS work_requests_status_check;

-- 2. Update existing work request statuses to match the new workflow status definitions
UPDATE public.work_requests
SET status = CASE 
  WHEN status IN ('Pending Assignment', 'pending') THEN 'Pending'
  WHEN status IN ('Assigned', 'Accepted by Maintenance', 'Pre-Inspection Submitted', 'ongoing', 'in_progress') THEN 'In Progress'
  WHEN status IN ('Pre-Inspection Approved', 'In Progress (Post-Repair)') THEN 'Confirmed'
  WHEN status IN ('Pre-Inspection Declined', 'Declined/Cancelled', 'cancelled') THEN 'Declined'
  WHEN status = 'Post-Repair Submitted' THEN (
    CASE WHEN rework_count > 0 OR EXISTS (
      SELECT 1 FROM public.post_repair_reports pr
      WHERE pr.work_request_id = work_requests.id
        AND pr.status = 'Rework'
    ) THEN 'Rework' ELSE 'Confirmed' END
  )
  WHEN status IN ('For Rework', 'Under Evaluation', 'rework') THEN 'Rework'
  WHEN status IN ('Completed', 'completed', 'done') THEN 'Completed'
  ELSE 'Pending'
END;

-- 3. Add the new status check constraint containing only the 6 simplified statuses
ALTER TABLE public.work_requests ADD CONSTRAINT work_requests_status_check CHECK (
  status IN (
    'Pending',
    'In Progress',
    'Declined',
    'Confirmed',
    'Rework',
    'Completed'
  )
);
