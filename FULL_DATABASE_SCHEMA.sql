-- PSU MainSystem
-- Full database schema (current state after applied migrations through 202604120014)
-- Scope: public schema core DDL (extensions, tables, key constraints, and key indexes)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'teacher', 'maintenance')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.buildings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.room_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  floor_id UUID REFERENCES public.floors(id) ON DELETE SET NULL,
  room_type_id UUID REFERENCES public.room_types(id) ON DELETE SET NULL,
  seats INT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'reserved', 'maintenance', 'inactive')),
  image_url VARCHAR(500),
  qr_code_data TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.maintenance_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  specialization VARCHAR(150),
  employee_id VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_by_admin_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.maintenance_user_archives (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  maintenance_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  archive_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_by_admin_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  original_created_at TIMESTAMP WITH TIME ZONE,
);

CREATE TABLE IF NOT EXISTS public.teacher_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  position VARCHAR(100),
  employee_id VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.request_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.work_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legacy_id TEXT,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  request_type_id UUID REFERENCES public.request_types(id) ON DELETE SET NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework', 'cancelled')),
  priority VARCHAR(50) NOT NULL DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
  department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
  date_submitted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_completed TIMESTAMP WITH TIME ZONE,
  date_due TIMESTAMP WITH TIME ZONE,
  requestor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  approved_by_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  approved_date TIMESTAMP WITH TIME ZONE,
  assigned_to_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  accepted_date TIMESTAMP WITH TIME ZONE,
  maintenance_start_time TIMESTAMP WITH TIME ZONE,
  maintenance_end_time TIMESTAMP WITH TIME ZONE,
  rework_count INT NOT NULL DEFAULT 0,
  rework_notes TEXT,
  work_evidence VARCHAR(500),
  maintenance_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_work_requests_legacy_id
  ON public.work_requests(legacy_id);

CREATE TABLE IF NOT EXISTS public.e_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  signer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  signer_name VARCHAR(255) NOT NULL, -- Intentional audit snapshot: signer name at signature time.
  signer_role VARCHAR(50) NOT NULL -- Intentional audit snapshot: signer role at signature time.
    CHECK (signer_role IN ('admin', 'maintenance', 'teacher')),
  signature_type VARCHAR(50) NOT NULL
    CHECK (signature_type IN ('approval', 'acceptance', 'pre_inspection', 'post_repair', 'completion')),
  signature_data TEXT NOT NULL,
  signed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.pre_inspection_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  inspector_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  inspector_name VARCHAR(255) NOT NULL, -- Intentional audit snapshot: inspector name at inspection time.
  inspection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
  admin_approved_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'approved', 'rejected')),
  notes TEXT,
  review_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.post_repair_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
  technician_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  technician_name VARCHAR(255) NOT NULL, -- Intentional audit snapshot: technician name at repair time.
  repair_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  work_performed TEXT NOT NULL,
  materials_used TEXT,
  photo_before TEXT,
  photo_after TEXT,
  repair_duration VARCHAR(100),
  repair_status VARCHAR(50) NOT NULL DEFAULT 'completed'
    CHECK (repair_status IN ('completed', 'partial', 'needs_followup')),
  technician_notes TEXT,
  admin_evaluation VARCHAR(50) CHECK (admin_evaluation IN ('satisfied', 'rework')),
  admin_evaluation_notes TEXT,
  admin_evaluated_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  admin_evaluated_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'evaluated', 'rework')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'info',
  target_role VARCHAR(50) NOT NULL DEFAULT 'all'
    CHECK (target_role IN ('all', 'admin', 'teacher', 'maintenance')),
  target_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  work_request_id UUID REFERENCES public.work_requests(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.qr_code_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
  qr_code_value TEXT NOT NULL UNIQUE,
  created_by_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scanned_count INT NOT NULL DEFAULT 0,
  last_scanned TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_qr_code_history_room_id
  ON public.qr_code_history(room_id);

CREATE INDEX IF NOT EXISTS idx_work_requests_room_id
  ON public.work_requests(room_id);
