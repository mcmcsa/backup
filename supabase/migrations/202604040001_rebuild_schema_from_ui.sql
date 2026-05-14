-- Rebuild baseline schema from SUPABASE_SCHEMA_FROM_UI.md
-- Date: 2026-04-04

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'teacher', 'maintenance')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  specialization VARCHAR(150),
  employee_id VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_user_archives (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  employee_id VARCHAR(100),
  specialization VARCHAR(150),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  archived_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  original_created_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS teacher_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  department_id UUID,
  position VARCHAR(100),
  employee_id VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS buildings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS room_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  building_id UUID NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  floor_id UUID REFERENCES floors(id) ON DELETE SET NULL,
  room_type_id UUID REFERENCES room_types(id) ON DELETE SET NULL,
  seats INT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'maintenance', 'inactive')),
  image_url VARCHAR(500),
  qr_code_data TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS qr_code_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  qr_code_value TEXT NOT NULL UNIQUE,
  qr_code_image TEXT,
  created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_name TEXT,
  building TEXT,
  department TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scanned_count INT NOT NULL DEFAULT 0,
  last_scanned TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS request_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS work_requests (
  id TEXT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  request_type_id UUID REFERENCES request_types(id) ON DELETE SET NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework', 'cancelled')),
  priority VARCHAR(50) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  date_submitted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_completed TIMESTAMP WITH TIME ZONE,
  date_due TIMESTAMP WITH TIME ZONE,
  requestor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reported_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_date TIMESTAMP WITH TIME ZONE,
  assigned_to_id UUID REFERENCES users(id) ON DELETE SET NULL,
  accepted_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  accepted_date TIMESTAMP WITH TIME ZONE,
  maintenance_start_time TIMESTAMP WITH TIME ZONE,
  maintenance_end_time TIMESTAMP WITH TIME ZONE,
  pre_inspection_id UUID,
  post_repair_id UUID,
  rework_count INT NOT NULL DEFAULT 0,
  rework_notes TEXT,
  work_evidence VARCHAR(500),
  maintenance_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS e_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  signer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signer_name VARCHAR(255) NOT NULL,
  signer_role VARCHAR(50) NOT NULL CHECK (signer_role IN ('admin', 'maintenance', 'teacher')),
  signature_type VARCHAR(50) NOT NULL CHECK (signature_type IN ('approval', 'acceptance', 'pre_inspection', 'post_repair', 'completion')),
  signature_data TEXT NOT NULL,
  signed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pre_inspection_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  inspector_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inspector_name VARCHAR(255) NOT NULL,
  inspection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  condition_found TEXT NOT NULL,
  description TEXT,
  root_cause TEXT,
  severity_level VARCHAR(50) NOT NULL DEFAULT 'Minor' CHECK (severity_level IN ('Minor', 'Moderate', 'Critical')),
  recommended_action VARCHAR(255),
  materials_needed TEXT,
  estimated_time VARCHAR(100),
  photo_evidence TEXT,
  admin_approved BOOLEAN NOT NULL DEFAULT false,
  admin_approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_approved_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'approved', 'rejected')),
  notes TEXT,
  review_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS post_repair_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  technician_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  technician_name VARCHAR(255) NOT NULL,
  repair_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  work_performed TEXT NOT NULL,
  materials_used TEXT,
  photo_before TEXT,
  photo_after TEXT,
  repair_duration VARCHAR(100),
  repair_status VARCHAR(50) NOT NULL DEFAULT 'completed' CHECK (repair_status IN ('completed', 'partial', 'needs_followup')),
  technician_notes TEXT,
  admin_evaluation VARCHAR(50) CHECK (admin_evaluation IN ('satisfied', 'rework')),
  admin_evaluation_notes TEXT,
  admin_evaluated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_evaluated_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'evaluated', 'rework')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'info',
  target_role VARCHAR(50) NOT NULL DEFAULT 'all' CHECK (target_role IN ('all', 'admin', 'teacher', 'maintenance')),
  target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  work_request_id TEXT REFERENCES work_requests(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Backfill missing columns when running against an existing database.
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS specialization VARCHAR(150);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS employee_id VARCHAR(100);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS profile_image VARCHAR(500);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS created_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE maintenance_users DROP COLUMN IF EXISTS shift_schedule;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS department_id;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS department_snapshot;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS archived_at;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS archived_by_admin_id;

ALTER TABLE maintenance_users DROP CONSTRAINT IF EXISTS fk_maintenance_users_department_id;

ALTER TABLE teacher_users ADD COLUMN IF NOT EXISTS department_id UUID;
ALTER TABLE teacher_users ADD COLUMN IF NOT EXISTS position VARCHAR(100);
ALTER TABLE teacher_users ADD COLUMN IF NOT EXISTS employee_id VARCHAR(100);
ALTER TABLE teacher_users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS floor_id UUID;
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS code VARCHAR(50);

ALTER TABLE floors DROP COLUMN IF EXISTS code;

ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS request_type_id UUID;
ALTER TABLE work_requests DROP COLUMN IF EXISTS campus;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_teacher_users_department_id'
  ) THEN
    ALTER TABLE teacher_users
      ADD CONSTRAINT fk_teacher_users_department_id
      FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Keep updated_at columns in sync on row updates.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_maintenance_users_updated_at ON maintenance_users;
CREATE TRIGGER trg_maintenance_users_updated_at
BEFORE UPDATE ON maintenance_users
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_maintenance_user_archives_updated_at ON maintenance_user_archives;
CREATE TRIGGER trg_maintenance_user_archives_updated_at
BEFORE UPDATE ON maintenance_user_archives
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_teacher_users_updated_at ON teacher_users;
CREATE TRIGGER trg_teacher_users_updated_at
BEFORE UPDATE ON teacher_users
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_departments_updated_at ON departments;
CREATE TRIGGER trg_departments_updated_at
BEFORE UPDATE ON departments
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_buildings_updated_at ON buildings;
CREATE TRIGGER trg_buildings_updated_at
BEFORE UPDATE ON buildings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_room_types_updated_at ON room_types;
CREATE TRIGGER trg_room_types_updated_at
BEFORE UPDATE ON room_types
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_floors_updated_at ON floors;
CREATE TRIGGER trg_floors_updated_at
BEFORE UPDATE ON floors
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_rooms_updated_at ON rooms;
CREATE TRIGGER trg_rooms_updated_at
BEFORE UPDATE ON rooms
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_request_types_updated_at ON request_types;
CREATE TRIGGER trg_request_types_updated_at
BEFORE UPDATE ON request_types
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_work_requests_updated_at ON work_requests;
CREATE TRIGGER trg_work_requests_updated_at
BEFORE UPDATE ON work_requests
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_pre_inspection_reports_updated_at ON pre_inspection_reports;
CREATE TRIGGER trg_pre_inspection_reports_updated_at
BEFORE UPDATE ON pre_inspection_reports
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_post_repair_reports_updated_at ON post_repair_reports;
CREATE TRIGGER trg_post_repair_reports_updated_at
BEFORE UPDATE ON post_repair_reports
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Performance indexes for common dashboard and detail queries.
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_maintenance_users_created_by_admin_id ON maintenance_users(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_users_employee_id ON maintenance_users(employee_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_user_archives_created_by_admin_id ON maintenance_user_archives(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_user_archives_archived_at ON maintenance_user_archives(archived_at DESC);
CREATE INDEX IF NOT EXISTS idx_teacher_users_department_id ON teacher_users(department_id);
CREATE INDEX IF NOT EXISTS idx_rooms_building_id ON rooms(building_id);
CREATE INDEX IF NOT EXISTS idx_rooms_department_id ON rooms(department_id);
CREATE INDEX IF NOT EXISTS idx_rooms_floor_id ON rooms(floor_id);
CREATE INDEX IF NOT EXISTS idx_qr_code_history_room_id ON qr_code_history(room_id);
CREATE INDEX IF NOT EXISTS idx_qr_code_history_active ON qr_code_history(is_active);
CREATE INDEX IF NOT EXISTS idx_work_requests_status ON work_requests(status);
CREATE INDEX IF NOT EXISTS idx_work_requests_priority ON work_requests(priority);
CREATE INDEX IF NOT EXISTS idx_work_requests_date_submitted ON work_requests(date_submitted DESC);
CREATE INDEX IF NOT EXISTS idx_work_requests_request_type_id ON work_requests(request_type_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_requestor_id ON work_requests(requestor_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_assigned_to_id ON work_requests(assigned_to_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_building_id ON work_requests(building_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_department_id ON work_requests(department_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_room_id ON work_requests(room_id);
CREATE INDEX IF NOT EXISTS idx_e_signatures_work_request_id ON e_signatures(work_request_id);
CREATE INDEX IF NOT EXISTS idx_e_signatures_signed_at ON e_signatures(signed_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_notifications_target_user_id ON app_notifications(target_user_id);
CREATE INDEX IF NOT EXISTS idx_app_notifications_is_read ON app_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_app_notifications_created_at ON app_notifications(created_at DESC);

-- Helper functions for role-aware RLS checks.
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.users WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.current_user_role() = 'admin', false)
$$;

-- Row Level Security baseline
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_user_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_code_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE request_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE e_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_inspection_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_repair_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_notifications ENABLE ROW LEVEL SECURITY;

-- users
DROP POLICY IF EXISTS users_select_policy ON users;
CREATE POLICY users_select_policy ON users
FOR SELECT
USING (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS users_insert_policy ON users;
CREATE POLICY users_insert_policy ON users
FOR INSERT
WITH CHECK (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS users_update_policy ON users;
CREATE POLICY users_update_policy ON users
FOR UPDATE
USING (id = auth.uid() OR public.is_admin())
WITH CHECK (id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS users_delete_policy ON users;
CREATE POLICY users_delete_policy ON users
FOR DELETE
USING (public.is_admin());

-- maintenance_users
DROP POLICY IF EXISTS maintenance_users_select_policy ON maintenance_users;
CREATE POLICY maintenance_users_select_policy ON maintenance_users
FOR SELECT
USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS maintenance_users_insert_policy ON maintenance_users;
CREATE POLICY maintenance_users_insert_policy ON maintenance_users
FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS maintenance_users_update_policy ON maintenance_users;
CREATE POLICY maintenance_users_update_policy ON maintenance_users
FOR UPDATE
USING (user_id = auth.uid() OR public.is_admin())
WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS maintenance_users_delete_policy ON maintenance_users;
CREATE POLICY maintenance_users_delete_policy ON maintenance_users
FOR DELETE
USING (public.is_admin());

-- maintenance_user_archives
DROP POLICY IF EXISTS maintenance_user_archives_select_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_select_policy ON maintenance_user_archives
FOR SELECT
USING (public.is_admin());

DROP POLICY IF EXISTS maintenance_user_archives_insert_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_insert_policy ON maintenance_user_archives
FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS maintenance_user_archives_update_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_update_policy ON maintenance_user_archives
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS maintenance_user_archives_delete_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_delete_policy ON maintenance_user_archives
FOR DELETE
USING (public.is_admin());

-- teacher_users
DROP POLICY IF EXISTS teacher_users_select_policy ON teacher_users;
CREATE POLICY teacher_users_select_policy ON teacher_users
FOR SELECT
USING (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS teacher_users_insert_policy ON teacher_users;
CREATE POLICY teacher_users_insert_policy ON teacher_users
FOR INSERT
WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS teacher_users_update_policy ON teacher_users;
CREATE POLICY teacher_users_update_policy ON teacher_users
FOR UPDATE
USING (user_id = auth.uid() OR public.is_admin())
WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS teacher_users_delete_policy ON teacher_users;
CREATE POLICY teacher_users_delete_policy ON teacher_users
FOR DELETE
USING (public.is_admin());

-- reference and facility tables (read for authenticated users, write for admins)
DROP POLICY IF EXISTS departments_select_policy ON departments;
CREATE POLICY departments_select_policy ON departments
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS departments_admin_write_policy ON departments;
CREATE POLICY departments_admin_write_policy ON departments
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS buildings_select_policy ON buildings;
CREATE POLICY buildings_select_policy ON buildings
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS buildings_admin_write_policy ON buildings;
CREATE POLICY buildings_admin_write_policy ON buildings
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS room_types_select_policy ON room_types;
CREATE POLICY room_types_select_policy ON room_types
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS room_types_admin_write_policy ON room_types;
CREATE POLICY room_types_admin_write_policy ON room_types
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS floors_select_policy ON floors;
CREATE POLICY floors_select_policy ON floors
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS floors_admin_write_policy ON floors;
CREATE POLICY floors_admin_write_policy ON floors
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS rooms_select_policy ON rooms;
CREATE POLICY rooms_select_policy ON rooms
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS rooms_admin_write_policy ON rooms;
CREATE POLICY rooms_admin_write_policy ON rooms
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS request_types_select_policy ON request_types;
CREATE POLICY request_types_select_policy ON request_types
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS request_types_admin_write_policy ON request_types;
CREATE POLICY request_types_admin_write_policy ON request_types
FOR ALL
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- qr_code_history
DROP POLICY IF EXISTS qr_code_history_select_policy ON qr_code_history;
CREATE POLICY qr_code_history_select_policy ON qr_code_history
FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS qr_code_history_insert_policy ON qr_code_history;
CREATE POLICY qr_code_history_insert_policy ON qr_code_history
FOR INSERT
WITH CHECK (public.is_admin() OR public.current_user_role() = 'maintenance');

DROP POLICY IF EXISTS qr_code_history_update_policy ON qr_code_history;
CREATE POLICY qr_code_history_update_policy ON qr_code_history
FOR UPDATE
USING (public.is_admin() OR public.current_user_role() = 'maintenance')
WITH CHECK (public.is_admin() OR public.current_user_role() = 'maintenance');

DROP POLICY IF EXISTS qr_code_history_delete_policy ON qr_code_history;
CREATE POLICY qr_code_history_delete_policy ON qr_code_history
FOR DELETE
USING (public.is_admin());

-- work_requests
DROP POLICY IF EXISTS work_requests_select_policy ON work_requests;
CREATE POLICY work_requests_select_policy ON work_requests
FOR SELECT
USING (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR reported_by_id = auth.uid()
  OR approved_by_id = auth.uid()
  OR assigned_to_id = auth.uid()
  OR accepted_by_id = auth.uid()
);

DROP POLICY IF EXISTS work_requests_insert_policy ON work_requests;
CREATE POLICY work_requests_insert_policy ON work_requests
FOR INSERT
WITH CHECK (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR reported_by_id = auth.uid()
);

DROP POLICY IF EXISTS work_requests_update_policy ON work_requests;
CREATE POLICY work_requests_update_policy ON work_requests
FOR UPDATE
USING (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR assigned_to_id = auth.uid()
  OR accepted_by_id = auth.uid()
)
WITH CHECK (
  public.is_admin()
  OR requestor_id = auth.uid()
  OR assigned_to_id = auth.uid()
  OR accepted_by_id = auth.uid()
);

DROP POLICY IF EXISTS work_requests_delete_policy ON work_requests;
CREATE POLICY work_requests_delete_policy ON work_requests
FOR DELETE
USING (public.is_admin());

-- e_signatures
DROP POLICY IF EXISTS e_signatures_select_policy ON e_signatures;
CREATE POLICY e_signatures_select_policy ON e_signatures
FOR SELECT
USING (public.is_admin() OR signer_id = auth.uid());

DROP POLICY IF EXISTS e_signatures_insert_policy ON e_signatures;
CREATE POLICY e_signatures_insert_policy ON e_signatures
FOR INSERT
WITH CHECK (public.is_admin() OR signer_id = auth.uid());

DROP POLICY IF EXISTS e_signatures_delete_policy ON e_signatures;
CREATE POLICY e_signatures_delete_policy ON e_signatures
FOR DELETE
USING (public.is_admin());

-- pre_inspection_reports
DROP POLICY IF EXISTS pre_inspection_reports_select_policy ON pre_inspection_reports;
CREATE POLICY pre_inspection_reports_select_policy ON pre_inspection_reports
FOR SELECT
USING (public.is_admin() OR inspector_id = auth.uid());

DROP POLICY IF EXISTS pre_inspection_reports_insert_policy ON pre_inspection_reports;
CREATE POLICY pre_inspection_reports_insert_policy ON pre_inspection_reports
FOR INSERT
WITH CHECK (public.is_admin() OR inspector_id = auth.uid());

DROP POLICY IF EXISTS pre_inspection_reports_update_policy ON pre_inspection_reports;
CREATE POLICY pre_inspection_reports_update_policy ON pre_inspection_reports
FOR UPDATE
USING (public.is_admin() OR inspector_id = auth.uid())
WITH CHECK (public.is_admin() OR inspector_id = auth.uid());

DROP POLICY IF EXISTS pre_inspection_reports_delete_policy ON pre_inspection_reports;
CREATE POLICY pre_inspection_reports_delete_policy ON pre_inspection_reports
FOR DELETE
USING (public.is_admin());

-- post_repair_reports
DROP POLICY IF EXISTS post_repair_reports_select_policy ON post_repair_reports;
CREATE POLICY post_repair_reports_select_policy ON post_repair_reports
FOR SELECT
USING (public.is_admin() OR technician_id = auth.uid());

DROP POLICY IF EXISTS post_repair_reports_insert_policy ON post_repair_reports;
CREATE POLICY post_repair_reports_insert_policy ON post_repair_reports
FOR INSERT
WITH CHECK (public.is_admin() OR technician_id = auth.uid());

DROP POLICY IF EXISTS post_repair_reports_update_policy ON post_repair_reports;
CREATE POLICY post_repair_reports_update_policy ON post_repair_reports
FOR UPDATE
USING (public.is_admin() OR technician_id = auth.uid())
WITH CHECK (public.is_admin() OR technician_id = auth.uid());

DROP POLICY IF EXISTS post_repair_reports_delete_policy ON post_repair_reports;
CREATE POLICY post_repair_reports_delete_policy ON post_repair_reports
FOR DELETE
USING (public.is_admin());

-- app_notifications
DROP POLICY IF EXISTS app_notifications_select_policy ON app_notifications;
CREATE POLICY app_notifications_select_policy ON app_notifications
FOR SELECT
USING (
  public.is_admin()
  OR target_user_id = auth.uid()
  OR target_role = 'all'
  OR target_role = public.current_user_role()
);

DROP POLICY IF EXISTS app_notifications_insert_policy ON app_notifications;
CREATE POLICY app_notifications_insert_policy ON app_notifications
FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS app_notifications_update_policy ON app_notifications;
CREATE POLICY app_notifications_update_policy ON app_notifications
FOR UPDATE
USING (
  public.is_admin()
  OR target_user_id = auth.uid()
  OR target_role = 'all'
  OR target_role = public.current_user_role()
)
WITH CHECK (
  public.is_admin()
  OR target_user_id = auth.uid()
  OR target_role = 'all'
  OR target_role = public.current_user_role()
);

DROP POLICY IF EXISTS app_notifications_delete_policy ON app_notifications;
CREATE POLICY app_notifications_delete_policy ON app_notifications
FOR DELETE
USING (public.is_admin());
