-- ==============================================================================
-- PSU MainSystem (PSU E-Ayos) - Complete PostgreSQL / Supabase Database Schema
-- Generated: 2026-09-27
-- Target Database: PostgreSQL 15+ (Supabase)
-- Scope: All tables, primary & foreign keys, check constraints, default values,
--        indexes, and relationships across the entire application.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 1. CORE AUTH & IDENTITY EXTENSION TABLES
-- ==============================================================================

-- 1.1 Base Users Table (Profile mirroring auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'campadmin', 'teacher', 'maintenance')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);

-- 1.2 Admin Users Profile Extension
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  employee_id VARCHAR(100),
  position VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_users_employee_id ON public.admin_users(employee_id);

-- 1.3 Teacher / Faculty Users Profile Extension
CREATE TABLE IF NOT EXISTS public.teacher_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  department_id UUID, -- Foreign key defined after departments table
  position VARCHAR(100),
  employee_id VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  is_department_head BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_teacher_users_user_id ON public.teacher_users(user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_users_is_dept_head ON public.teacher_users(is_department_head);

-- 1.4 Maintenance Users Profile Extension
CREATE TABLE IF NOT EXISTS public.maintenance_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  specialization VARCHAR(150),
  shift_schedule VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  schedule_image_url TEXT,
  employee_id VARCHAR(100),
  is_available BOOLEAN NOT NULL DEFAULT true,
  availability_notes TEXT,
  created_by_admin_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_maintenance_users_user_id ON public.maintenance_users(user_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_users_is_available ON public.maintenance_users(is_available);

-- 1.5 Maintenance User Archives (Audit for removed maintenance staff)
CREATE TABLE IF NOT EXISTS public.maintenance_user_archives (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  archive_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_by_admin_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  original_created_at TIMESTAMPTZ
);


-- ==============================================================================
-- 2. CAMPUS INFRASTRUCTURE & FACILITIES
-- ==============================================================================

-- 2.1 Departments Table
CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  head_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_departments_head_user ON public.departments(head_user_id);

-- Attach foreign key from teacher_users to departments
ALTER TABLE public.teacher_users 
  DROP CONSTRAINT IF EXISTS teacher_users_department_id_fkey;
ALTER TABLE public.teacher_users
  ADD CONSTRAINT teacher_users_department_id_fkey
  FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_teacher_users_dept_id ON public.teacher_users(department_id);

-- 2.2 Buildings Table
CREATE TABLE IF NOT EXISTS public.buildings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.3 Department <-> Buildings Junction Table (Many-to-Many)
CREATE TABLE IF NOT EXISTS public.department_buildings (
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (department_id, building_id)
);

CREATE INDEX IF NOT EXISTS idx_dept_bldgs_department_id ON public.department_buildings(department_id);
CREATE INDEX IF NOT EXISTS idx_dept_bldgs_building_id ON public.department_buildings(building_id);

-- 2.4 Floors Table
CREATE TABLE IF NOT EXISTS public.floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.5 Room Types Table
CREATE TABLE IF NOT EXISTS public.room_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2.6 Rooms Table
CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  floor_id UUID REFERENCES public.floors(id) ON DELETE SET NULL,
  room_type_id UUID REFERENCES public.room_types(id) ON DELETE SET NULL,
  seats INT NOT NULL DEFAULT 0,
  status VARCHAR(50) NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'reserved', 'maintenance', 'inactive')),
  image_url TEXT,
  qr_code_data TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_rooms_building_id ON public.rooms(building_id);
CREATE INDEX IF NOT EXISTS idx_rooms_department_id ON public.rooms(department_id);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);

-- 2.7 Room Versions (Historical audit log for background edits)
CREATE TABLE IF NOT EXISTS public.room_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  version INT NOT NULL,
  room_data JSONB NOT NULL,
  edited_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_room_versions_room_id ON public.room_versions(room_id);

-- 2.8 QR Code History Table
CREATE TABLE IF NOT EXISTS public.qr_code_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
  qr_code_value TEXT NOT NULL UNIQUE,
  created_by_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scanned_count INT NOT NULL DEFAULT 0,
  last_scanned TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_qr_code_history_room_id ON public.qr_code_history(room_id);


-- ==============================================================================
-- 3. WORK REQUESTS & WORKFLOW SYSTEM
-- ==============================================================================

-- 3.1 Request Types
CREATE TABLE IF NOT EXISTS public.request_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3.2 Work Requests Table
CREATE TABLE IF NOT EXISTS public.work_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legacy_id TEXT UNIQUE,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  request_type_id UUID REFERENCES public.request_types(id) ON DELETE SET NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'Pending'
    CHECK (status IN (
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
    )),
  priority VARCHAR(50) NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
  date_submitted TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_completed TIMESTAMPTZ,
  date_due TIMESTAMPTZ,
  requestor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  requestor_name VARCHAR(255),
  requestor_position VARCHAR(100),
  approved_by_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  approved_date TIMESTAMPTZ,
  assigned_to_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  accepted_date TIMESTAMPTZ,
  maintenance_start_time TIMESTAMPTZ,
  maintenance_end_time TIMESTAMPTZ,
  rework_count INT NOT NULL DEFAULT 0,
  rework_notes TEXT,
  work_evidence VARCHAR(500),
  maintenance_notes TEXT,
  attachment_urls TEXT[],
  voice_notes JSONB,
  duplicate_of_id UUID REFERENCES public.work_requests(id) ON DELETE SET NULL,
  -- Department Head Approval Routing
  dept_head_id UUID REFERENCES public.users(id) ON DELETE RESTRICT,
  dept_head_status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (dept_head_status IN ('pending', 'approved', 'acknowledged', 'not_applicable', 'declined')),
  dept_head_approved_date TIMESTAMPTZ,
  dept_head_evaluated_date TIMESTAMPTZ,
  dept_head_notes TEXT,
  -- Cancellation Tracking
  cancelled_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason_type TEXT,
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_work_requests_status ON public.work_requests(status);
CREATE INDEX IF NOT EXISTS idx_work_requests_requestor ON public.work_requests(requestor_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_assigned ON public.work_requests(assigned_to_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_dept_head ON public.work_requests(dept_head_id, dept_head_status);
CREATE INDEX IF NOT EXISTS idx_work_requests_room_id ON public.work_requests(room_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_dept_id ON public.work_requests(department_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_submitted ON public.work_requests(date_submitted DESC);

-- 3.3 E-Signatures Table (Audit trail of digital signatures)
CREATE TABLE IF NOT EXISTS public.e_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  signer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  signer_name VARCHAR(255) NOT NULL,
  signer_role VARCHAR(50) NOT NULL
    CHECK (signer_role IN ('admin', 'campadmin', 'maintenance', 'teacher', 'dept_head')),
  signature_type VARCHAR(50) NOT NULL
    CHECK (signature_type IN (
      'requestor',
      'approval',
      'acceptance',
      'pre_inspection',
      'pre_inspection_admin',
      'post_repair',
      'completion',
      'dept_head_approval',
      'dept_head_acknowledgement'
    )),
  signature_data TEXT NOT NULL,
  signed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_e_signatures_wr_id ON public.e_signatures(work_request_id);
CREATE INDEX IF NOT EXISTS idx_e_signatures_signer ON public.e_signatures(signer_id);

-- 3.4 Pre-Inspection Reports Table
CREATE TABLE IF NOT EXISTS public.pre_inspection_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  inspector_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  inspector_name VARCHAR(255) NOT NULL,
  inspection_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  condition_found TEXT NOT NULL,
  description TEXT,
  root_cause TEXT,
  severity_level VARCHAR(50) NOT NULL DEFAULT 'Minor'
    CHECK (severity_level IN ('Minor', 'Moderate', 'Critical')),
  recommended_action VARCHAR(255),
  materials_needed TEXT,
  estimated_time VARCHAR(100),
  photo_evidence TEXT,
  admin_approved BOOLEAN NOT NULL DEFAULT false,
  admin_approved_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  admin_approved_date TIMESTAMPTZ,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'approved', 'rejected')),
  notes TEXT,
  review_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pre_inspection_wr ON public.pre_inspection_reports(work_request_id);

-- 3.5 Post-Repair Reports Table (With Requestor & Admin Evaluation)
CREATE TABLE IF NOT EXISTS public.post_repair_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  technician_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  technician_name VARCHAR(255) NOT NULL,
  repair_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  work_performed TEXT NOT NULL,
  materials_used TEXT,
  photo_before TEXT,
  photo_after TEXT,
  repair_duration VARCHAR(100),
  repair_status VARCHAR(50) NOT NULL DEFAULT 'completed'
    CHECK (repair_status IN ('completed', 'partial', 'needs_followup')),
  technician_notes TEXT,
  attempt_number INT NOT NULL DEFAULT 1,
  -- Campus Admin Evaluation
  admin_evaluation VARCHAR(50) CHECK (admin_evaluation IN ('satisfied', 'rework')),
  admin_evaluation_notes TEXT,
  admin_evaluated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  admin_evaluated_date TIMESTAMPTZ,
  -- Requestor Faculty Evaluation
  requestor_evaluation VARCHAR(20) CHECK (requestor_evaluation IS NULL OR requestor_evaluation IN ('satisfy', 'not_satisfy')),
  requestor_rating INT CHECK (requestor_rating IS NULL OR (requestor_rating >= 1 AND requestor_rating <= 5)),
  requestor_comment TEXT,
  requestor_evaluated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  requestor_evaluated_date TIMESTAMPTZ,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'evaluated', 'rework')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_post_repair_wr ON public.post_repair_reports(work_request_id);
CREATE INDEX IF NOT EXISTS idx_post_repair_reports_requestor_eval 
  ON public.post_repair_reports(work_request_id, attempt_number, requestor_evaluation);

-- 3.6 Work Request Follow-Ups (Messages between Faculty & Dept Head/Campus Admin)
CREATE TABLE IF NOT EXISTS public.work_request_follow_ups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  requestor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  target_stage VARCHAR(50) NOT NULL DEFAULT 'dept_head',
  recipient_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  admin_response TEXT,
  responded_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wr_followups_request ON public.work_request_follow_ups(work_request_id);
CREATE INDEX IF NOT EXISTS idx_wr_followups_requestor ON public.work_request_follow_ups(requestor_id);


-- ==============================================================================
-- 4. COLLABORATION, COSTS & DUPLICATE TRACKING
-- ==============================================================================

-- 4.1 Work Request Collaborators (Secondary Maintenance Personnel)
CREATE TABLE IF NOT EXISTS public.work_request_collaborators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('primary', 'secondary')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'removed')),
  invited_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  responded_at TIMESTAMPTZ,
  CONSTRAINT unique_collaborator UNIQUE (work_request_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_collaborators_wr ON public.work_request_collaborators(work_request_id);

-- 4.2 Work Request Tasks (Checklist items per ticket)
CREATE TABLE IF NOT EXISTS public.work_request_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  task_description TEXT NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_wr_tasks_wr ON public.work_request_tasks(work_request_id);

-- 4.3 Work Request Notes
CREATE TABLE IF NOT EXISTS public.work_request_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  attachment_urls TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wr_notes_wr ON public.work_request_notes(work_request_id);

-- 4.4 Work Request Activities (Audit trail of ticket updates)
CREATE TABLE IF NOT EXISTS public.work_request_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wr_activities_wr ON public.work_request_activities(work_request_id);

-- 4.5 Work Request Costs (Budget and Expenses)
CREATE TABLE IF NOT EXISTS public.work_request_costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL UNIQUE REFERENCES public.work_requests(id) ON DELETE CASCADE,
  estimated_labor_cost NUMERIC(12, 2) DEFAULT 0.00,
  estimated_material_cost NUMERIC(12, 2) DEFAULT 0.00,
  actual_labor_cost NUMERIC(12, 2) DEFAULT 0.00,
  actual_material_cost NUMERIC(12, 2) DEFAULT 0.00,
  additional_expenses NUMERIC(12, 2) DEFAULT 0.00,
  total_cost NUMERIC(12, 2) GENERATED ALWAYS AS (actual_labor_cost + actual_material_cost + additional_expenses) STORED,
  budget_source TEXT,
  purchase_reference_number TEXT,
  receipt_attachment_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4.6 Request Reporters (Duplicate Joiners)
CREATE TABLE IF NOT EXISTS public.request_reporters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  reporter_name TEXT NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (work_request_id, reporter_id)
);

-- 4.7 Request Merges (Merge History)
CREATE TABLE IF NOT EXISTS public.request_merges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  primary_request_id UUID REFERENCES public.work_requests(id) ON DELETE SET NULL,
  merged_request_id UUID REFERENCES public.work_requests(id) ON DELETE SET NULL,
  merged_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  merged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT
);


-- ==============================================================================
-- 5. REALTIME CHAT SYSTEM
-- ==============================================================================

-- 5.1 Chat Rooms
CREATE TABLE IF NOT EXISTS public.chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT,
  type TEXT NOT NULL DEFAULT 'direct' CHECK (type IN ('direct', 'group')),
  work_request_id UUID REFERENCES public.work_requests(id) ON DELETE SET NULL,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_rooms_updated ON public.chat_rooms(updated_at DESC);

-- 5.2 Chat Participants
CREATE TABLE IF NOT EXISTS public.chat_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'teacher',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_read_at TIMESTAMPTZ,
  UNIQUE(room_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_participants_room ON public.chat_participants(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON public.chat_participants(user_id);

-- 5.3 Chat Messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  sender_role TEXT NOT NULL DEFAULT 'teacher',
  content TEXT,
  message_type TEXT NOT NULL DEFAULT 'text'
    CHECK (message_type IN ('text', 'image', 'voice', 'file', 'system')),
  attachment_url TEXT,
  attachment_name TEXT,
  reply_to_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
  reply_to_content TEXT,
  is_forwarded BOOLEAN NOT NULL DEFAULT false,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON public.chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created ON public.chat_messages(room_id, created_at DESC);

-- 5.4 Chat Typing Indicators
CREATE TABLE IF NOT EXISTS public.chat_typing (
  room_id UUID NOT NULL,
  user_id UUID NOT NULL,
  user_name TEXT NOT NULL DEFAULT '',
  is_typing BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (room_id, user_id)
);


-- ==============================================================================
-- 6. NOTIFICATIONS & PUSH DEVICE TOKENS
-- ==============================================================================

-- 6.1 In-App Notifications
CREATE TABLE IF NOT EXISTS public.app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'info',
  target_role VARCHAR(50) NOT NULL DEFAULT 'all'
    CHECK (target_role IN ('all', 'admin', 'campadmin', 'teacher', 'maintenance')),
  target_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  work_request_id UUID REFERENCES public.work_requests(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_app_notif_target_user ON public.app_notifications(target_user_id);
CREATE INDEX IF NOT EXISTS idx_app_notif_created ON public.app_notifications(created_at DESC);

-- 6.2 FCM Push Notification Device Tokens
CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_user_platform UNIQUE (user_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_fcm_token ON public.user_devices(fcm_token);

-- 6.3 User Notification Preferences
CREATE TABLE IF NOT EXISTS public.user_notification_settings (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  notifications_enabled BOOLEAN NOT NULL DEFAULT true,
  email_notifications BOOLEAN NOT NULL DEFAULT false,
  push_notifications BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ==============================================================================
-- 7. SYSTEM SETTINGS, ANNOUNCEMENTS & AUDIT LOGS
-- ==============================================================================

-- 7.1 Admin Activity Logs
CREATE TABLE IF NOT EXISTS public.admin_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  role TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('login', 'action')),
  title TEXT NOT NULL,
  details TEXT,
  work_request_id TEXT,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_logged_at ON public.admin_activity_logs(logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_activity_logs_user_id ON public.admin_activity_logs(user_id);

-- 7.2 System Settings
CREATE TABLE IF NOT EXISTS public.system_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  system_name TEXT NOT NULL DEFAULT 'PSU Maintenance',
  campus_name TEXT NOT NULL DEFAULT 'Main Campus',
  primary_color TEXT NOT NULL DEFAULT '#1E3A8A',
  academic_year TEXT NOT NULL DEFAULT '2025-2026',
  session_timeout_minutes INT NOT NULL DEFAULT 60,
  theme TEXT NOT NULL DEFAULT 'light',
  timezone TEXT NOT NULL DEFAULT 'Asia/Manila',
  semester TEXT NOT NULL DEFAULT '1st Semester',
  enforce_password_policy BOOLEAN NOT NULL DEFAULT true,
  maintenance_mode BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7.3 System Feedback (App ratings and issue reporting)
CREATE TABLE IF NOT EXISTS public.system_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  user_name TEXT NOT NULL,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  admin_reply TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7.4 System Announcements
CREATE TABLE IF NOT EXISTS public.system_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  status TEXT NOT NULL DEFAULT 'draft',
  scheduled_for TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  target_audience TEXT[] NOT NULL DEFAULT '{all}',
  display_type TEXT NOT NULL DEFAULT 'notification',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7.5 System Backups Log
CREATE TABLE IF NOT EXISTS public.system_backups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename TEXT NOT NULL,
  size_bytes BIGINT NOT NULL,
  status TEXT NOT NULL,
  created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
