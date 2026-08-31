-- Migration: Update database schema for Work Request workflow (Phase 1)
-- Date: 2026-08-26
-- Option A selected: Pre-Inspection Decline returns the request to Pre-Inspection Declined status.

-- 1. Modify work_requests status check constraint to include all user requested statuses
ALTER TABLE public.work_requests DROP CONSTRAINT IF EXISTS work_requests_status_check;
ALTER TABLE public.work_requests ADD CONSTRAINT work_requests_status_check CHECK (
  status IN (
    'Pending Assignment',
    'Assigned',
    'Accepted by Maintenance',
    'Pre-Inspection Submitted',
    'Pre-Inspection Approved',
    'Pre-Inspection Declined',
    'In Progress (Post-Repair)',
    'Post-Repair Submitted',
    'Under Evaluation',
    'For Rework',
    'Completed',
    'Declined/Cancelled'
  )
);

-- 2. Modify e_signatures type check constraint to include 'requestor' and 'pre_inspection_admin'
ALTER TABLE public.e_signatures DROP CONSTRAINT IF EXISTS e_signatures_signature_type_check;
ALTER TABLE public.e_signatures ADD CONSTRAINT e_signatures_signature_type_check CHECK (
  signature_type IN (
    'requestor',
    'approval',
    'acceptance',
    'pre_inspection',
    'pre_inspection_admin',
    'post_repair',
    'completion'
  )
);

-- 3. Update pre_inspection_reports status check constraint to Approved/Declined/Pending
ALTER TABLE public.pre_inspection_reports DROP CONSTRAINT IF EXISTS pre_inspection_reports_status_check;
ALTER TABLE public.pre_inspection_reports ADD CONSTRAINT pre_inspection_reports_status_check CHECK (
  status IN ('Pending', 'Approved', 'Declined')
);
ALTER TABLE public.pre_inspection_reports ALTER COLUMN status SET DEFAULT 'Pending';

-- 4. Update post_repair_reports columns and constraints
ALTER TABLE public.post_repair_reports ADD COLUMN IF NOT EXISTS attempt_number INT NOT NULL DEFAULT 1;

ALTER TABLE public.post_repair_reports DROP CONSTRAINT IF EXISTS post_repair_reports_status_check;
ALTER TABLE public.post_repair_reports ADD CONSTRAINT post_repair_reports_status_check CHECK (
  status IN ('Pending', 'Completed', 'Rework')
);
ALTER TABLE public.post_repair_reports ALTER COLUMN status SET DEFAULT 'Pending';
