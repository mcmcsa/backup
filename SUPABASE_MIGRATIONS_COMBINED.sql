-- ============================================================
-- File: 20260308000001_create_departments_table.sql
-- ============================================================
-- Create departments table
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index on department name for faster lookups
CREATE INDEX IF NOT EXISTS idx_departments_name ON departments(name);

-- Enable RLS (Row Level Security)
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Create policies for departments (allow all authenticated users to read)
DROP POLICY IF EXISTS "Allow authenticated users to read departments" ON departments;
CREATE POLICY "Allow authenticated users to read departments"
  ON departments FOR SELECT
  USING (auth.role() = 'authenticated');


-- ============================================================
-- File: 20260308000002_create_buildings_table.sql
-- ============================================================
-- Create buildings table
CREATE TABLE IF NOT EXISTS buildings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_buildings_name ON buildings(name);
CREATE INDEX IF NOT EXISTS idx_buildings_code ON buildings(code);

-- Enable RLS
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow authenticated users to read buildings" ON buildings;
CREATE POLICY "Allow authenticated users to read buildings"
  ON buildings FOR SELECT
  USING (auth.role() = 'authenticated');


-- ============================================================
-- File: 20260308000003_create_users_table.sql
-- ============================================================
-- Create users table (profiles for auth users)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'teacher', 'maintenance')),
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all user profiles" ON users;
CREATE POLICY "Admins can view all user profiles"
  ON users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow service_role to insert users (needed for auth.users creation)
DROP POLICY IF EXISTS "Allow service_role to create users" ON users;
CREATE POLICY "Allow service_role to create users"
  ON users FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Create trigger function to auto-create user profile when auth user is created
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, is_active)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'role', 'teacher'),
    true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new auth users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- File: 20260308000004_create_rooms_table.sql
-- ============================================================
-- Create rooms table
CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  building_id UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL,
  floor VARCHAR(50) NOT NULL,
  room_type_id UUID REFERENCES room_types(id) ON DELETE SET NULL,
  seats INT NOT NULL,
  status VARCHAR(50) CHECK (status IN ('available', 'reserved', 'maintenance', 'inactive')) DEFAULT 'available',
  image_url VARCHAR(500),
  qr_code_data TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_rooms_building_id ON rooms(building_id);
CREATE INDEX IF NOT EXISTS idx_rooms_department_id ON rooms(department_id);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms(status);
CREATE INDEX IF NOT EXISTS idx_rooms_name ON rooms(name);

-- Enable RLS
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow authenticated users to read rooms" ON rooms;
CREATE POLICY "Allow authenticated users to read rooms"
  ON rooms FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow admins to manage rooms" ON rooms;
CREATE POLICY "Allow admins to manage rooms"
  ON rooms FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- ============================================================
-- File: 20260308000005_create_request_types_table.sql
-- ============================================================
-- Create request_types table
CREATE TABLE IF NOT EXISTS request_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_request_types_name ON request_types(name);

-- Enable RLS
ALTER TABLE request_types ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow authenticated users to read request types" ON request_types;
CREATE POLICY "Allow authenticated users to read request types"
  ON request_types FOR SELECT
  USING (auth.role() = 'authenticated');


-- ============================================================
-- File: 20260308000006_create_work_requests_table.sql
-- ============================================================
-- Create work_requests table
CREATE TABLE IF NOT EXISTS work_requests (
  id TEXT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  type_of_request VARCHAR(255),
  status VARCHAR(50) NOT NULL CHECK (status IN ('pending', 'ongoing', 'done', 'cancelled')) DEFAULT 'pending',
  priority VARCHAR(50) NOT NULL CHECK (priority IN ('low', 'medium', 'high')) DEFAULT 'medium',
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  room_id TEXT REFERENCES rooms(id) ON DELETE SET NULL,
  date_submitted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_completed TIMESTAMP WITH TIME ZONE,
  date_due TIMESTAMP WITH TIME ZONE,
  requestor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reported_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_date TIMESTAMP WITH TIME ZONE,
  assigned_to_id UUID REFERENCES users(id) ON DELETE SET NULL,
  work_evidence VARCHAR(500),
  maintenance_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_work_requests_status ON work_requests(status);
CREATE INDEX IF NOT EXISTS idx_work_requests_priority ON work_requests(priority);
CREATE INDEX IF NOT EXISTS idx_work_requests_date_submitted ON work_requests(date_submitted);
CREATE INDEX IF NOT EXISTS idx_work_requests_building_id ON work_requests(building_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_department_id ON work_requests(department_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_room_id ON work_requests(room_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_requestor_id ON work_requests(requestor_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_assigned_to_id ON work_requests(assigned_to_id);

-- Enable RLS
ALTER TABLE work_requests ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Allow authenticated users to read work requests" ON work_requests;
CREATE POLICY "Allow authenticated users to read work requests"
  ON work_requests FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow users to insert their own work requests" ON work_requests;
CREATE POLICY "Allow users to insert their own work requests"
  ON work_requests FOR INSERT
  WITH CHECK (
    requestor_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Allow admins to manage all work requests" ON work_requests;
CREATE POLICY "Allow admins to manage all work requests"
  ON work_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Allow assigned maintenance staff to update their work requests" ON work_requests;
CREATE POLICY "Allow assigned maintenance staff to update their work requests"
  ON work_requests FOR UPDATE
  USING (
    assigned_to_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- ============================================================
-- File: 20260308000008_create_qr_code_history_table.sql
-- ============================================================
-- Create qr_code_history table
CREATE TABLE IF NOT EXISTS qr_code_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT REFERENCES rooms(id) ON DELETE CASCADE,
  qr_code_value TEXT NOT NULL UNIQUE,
  qr_code_image TEXT,
  created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scanned_count INT DEFAULT 0,
  last_scanned TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_qr_code_history_room_id ON qr_code_history(room_id);
CREATE INDEX IF NOT EXISTS idx_qr_code_history_created_by_id ON qr_code_history(created_by_id);
CREATE INDEX IF NOT EXISTS idx_qr_code_history_is_active ON qr_code_history(is_active);

-- Enable RLS
ALTER TABLE qr_code_history ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow authenticated users to read qr code history" ON qr_code_history;
CREATE POLICY "Allow authenticated users to read qr code history"
  ON qr_code_history FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow users to insert qr code history" ON qr_code_history;
CREATE POLICY "Allow users to insert qr code history"
  ON qr_code_history FOR INSERT
  WITH CHECK (created_by_id = auth.uid() OR 
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Allow admins to manage qr code history" ON qr_code_history;
CREATE POLICY "Allow admins to manage qr code history"
  ON qr_code_history FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- ============================================================
-- File: 20260308000010_add_workflow_tables.sql
-- ============================================================
-- ============================================================
-- Migration: Add full maintenance workflow tables
-- Adds: e_signatures, pre_inspection_reports, post_repair_reports
-- Updates: work_requests status values & new columns
-- ============================================================

-- 1. Update work_requests status constraint to support full workflow
ALTER TABLE work_requests DROP CONSTRAINT IF EXISTS work_requests_status_check;
ALTER TABLE work_requests ADD CONSTRAINT work_requests_status_check
  CHECK (status IN ('pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework', 'cancelled'));

-- 2. Add new workflow columns to work_requests
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS accepted_by_id UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS accepted_by_name VARCHAR(255);
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS accepted_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS maintenance_start_time TIMESTAMP WITH TIME ZONE;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS maintenance_end_time TIMESTAMP WITH TIME ZONE;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS pre_inspection_id UUID;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS post_repair_id UUID;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS rework_count INT DEFAULT 0;
ALTER TABLE work_requests ADD COLUMN IF NOT EXISTS rework_notes TEXT;

-- Create index for accepted_by
CREATE INDEX IF NOT EXISTS idx_work_requests_accepted_by_id ON work_requests(accepted_by_id);

-- ============================================================
-- 3. Create e_signatures table
-- ============================================================
CREATE TABLE IF NOT EXISTS e_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  signer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signer_name VARCHAR(255) NOT NULL,
  signer_role VARCHAR(50) NOT NULL CHECK (signer_role IN ('admin', 'maintenance', 'teacher')),
  signature_type VARCHAR(50) NOT NULL CHECK (signature_type IN ('approval', 'acceptance', 'pre_inspection', 'post_repair', 'completion')),
  signature_data TEXT NOT NULL, -- Base64 encoded signature image
  signed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_e_signatures_work_request_id ON e_signatures(work_request_id);
CREATE INDEX IF NOT EXISTS idx_e_signatures_signer_id ON e_signatures(signer_id);
CREATE INDEX IF NOT EXISTS idx_e_signatures_signature_type ON e_signatures(signature_type);

ALTER TABLE e_signatures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read e_signatures" ON e_signatures;
CREATE POLICY "Allow authenticated users to read e_signatures"
  ON e_signatures FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow users to insert their own e_signatures" ON e_signatures;
CREATE POLICY "Allow users to insert their own e_signatures"
  ON e_signatures FOR INSERT
  WITH CHECK (signer_id = auth.uid());

DROP POLICY IF EXISTS "Allow admins to manage all e_signatures" ON e_signatures;
CREATE POLICY "Allow admins to manage all e_signatures"
  ON e_signatures FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

-- ============================================================
-- 4. Create pre_inspection_reports table
-- ============================================================
CREATE TABLE IF NOT EXISTS pre_inspection_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  inspector_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inspector_name VARCHAR(255) NOT NULL,
  inspection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  condition_found TEXT NOT NULL,
  description TEXT,
  root_cause TEXT,
  severity_level VARCHAR(50) NOT NULL CHECK (severity_level IN ('Minor', 'Moderate', 'Critical')) DEFAULT 'Minor',
  recommended_action VARCHAR(255),
  materials_needed TEXT, -- JSON array of materials
  estimated_time VARCHAR(100),
  photo_evidence TEXT, -- JSON array of photo URLs
  admin_approved BOOLEAN DEFAULT FALSE,
  admin_approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_approved_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL CHECK (status IN ('submitted', 'approved', 'rejected')) DEFAULT 'submitted',
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pre_inspection_work_request_id ON pre_inspection_reports(work_request_id);
CREATE INDEX IF NOT EXISTS idx_pre_inspection_inspector_id ON pre_inspection_reports(inspector_id);
CREATE INDEX IF NOT EXISTS idx_pre_inspection_status ON pre_inspection_reports(status);

ALTER TABLE pre_inspection_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read pre_inspection_reports" ON pre_inspection_reports;
CREATE POLICY "Allow authenticated users to read pre_inspection_reports"
  ON pre_inspection_reports FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow maintenance to insert pre_inspection_reports" ON pre_inspection_reports;
CREATE POLICY "Allow maintenance to insert pre_inspection_reports"
  ON pre_inspection_reports FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('maintenance', 'admin'))
  );

DROP POLICY IF EXISTS "Allow admins to manage all pre_inspection_reports" ON pre_inspection_reports;
CREATE POLICY "Allow admins to manage all pre_inspection_reports"
  ON pre_inspection_reports FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Allow maintenance to update own pre_inspection_reports" ON pre_inspection_reports;
CREATE POLICY "Allow maintenance to update own pre_inspection_reports"
  ON pre_inspection_reports FOR UPDATE
  USING (inspector_id = auth.uid());

-- ============================================================
-- 5. Create post_repair_reports table
-- ============================================================
CREATE TABLE IF NOT EXISTS post_repair_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  technician_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  technician_name VARCHAR(255) NOT NULL,
  repair_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  work_performed TEXT NOT NULL,
  materials_used TEXT, -- JSON array of materials used
  photo_before TEXT, -- JSON array of before photo URLs
  photo_after TEXT, -- JSON array of after photo URLs
  repair_duration VARCHAR(100),
  repair_status VARCHAR(50) NOT NULL CHECK (repair_status IN ('completed', 'partial', 'needs_followup')) DEFAULT 'completed',
  technician_notes TEXT,
  admin_evaluation VARCHAR(50) CHECK (admin_evaluation IN ('satisfied', 'rework')),
  admin_evaluation_notes TEXT,
  admin_evaluated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_evaluated_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL CHECK (status IN ('submitted', 'evaluated', 'rework')) DEFAULT 'submitted',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_post_repair_work_request_id ON post_repair_reports(work_request_id);
CREATE INDEX IF NOT EXISTS idx_post_repair_technician_id ON post_repair_reports(technician_id);
CREATE INDEX IF NOT EXISTS idx_post_repair_status ON post_repair_reports(status);

ALTER TABLE post_repair_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read post_repair_reports" ON post_repair_reports;
CREATE POLICY "Allow authenticated users to read post_repair_reports"
  ON post_repair_reports FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow maintenance to insert post_repair_reports" ON post_repair_reports;
CREATE POLICY "Allow maintenance to insert post_repair_reports"
  ON post_repair_reports FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('maintenance', 'admin'))
  );

DROP POLICY IF EXISTS "Allow admins to manage all post_repair_reports" ON post_repair_reports;
CREATE POLICY "Allow admins to manage all post_repair_reports"
  ON post_repair_reports FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

DROP POLICY IF EXISTS "Allow maintenance to update own post_repair_reports" ON post_repair_reports;
CREATE POLICY "Allow maintenance to update own post_repair_reports"
  ON post_repair_reports FOR UPDATE
  USING (technician_id = auth.uid());

-- Add foreign key references from work_requests
ALTER TABLE work_requests DROP CONSTRAINT IF EXISTS fk_pre_inspection;
ALTER TABLE work_requests ADD CONSTRAINT fk_pre_inspection
  FOREIGN KEY (pre_inspection_id) REFERENCES pre_inspection_reports(id) ON DELETE SET NULL;

ALTER TABLE work_requests DROP CONSTRAINT IF EXISTS fk_post_repair;
ALTER TABLE work_requests ADD CONSTRAINT fk_post_repair
  FOREIGN KEY (post_repair_id) REFERENCES post_repair_reports(id) ON DELETE SET NULL;


-- ============================================================
-- File: 20260308000011_add_room_name_department_to_qr_code_history.sql
-- ============================================================
-- Add room_name, building and department columns to qr_code_history table
ALTER TABLE qr_code_history ADD COLUMN IF NOT EXISTS room_name TEXT;
ALTER TABLE qr_code_history ADD COLUMN IF NOT EXISTS building TEXT;
ALTER TABLE qr_code_history ADD COLUMN IF NOT EXISTS department TEXT;


-- ============================================================
-- File: 20260308000012_add_insert_policies_buildings_departments.sql
-- ============================================================
-- Add INSERT/UPDATE/DELETE policies for buildings table
DROP POLICY IF EXISTS "Allow authenticated users to insert buildings" ON buildings;
CREATE POLICY "Allow authenticated users to insert buildings"
  ON buildings FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to update buildings" ON buildings;
CREATE POLICY "Allow authenticated users to update buildings"
  ON buildings FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to delete buildings" ON buildings;
CREATE POLICY "Allow authenticated users to delete buildings"
  ON buildings FOR DELETE
  USING (auth.role() = 'authenticated');

-- Add INSERT/UPDATE/DELETE policies for departments table
DROP POLICY IF EXISTS "Allow authenticated users to insert departments" ON departments;
CREATE POLICY "Allow authenticated users to insert departments"
  ON departments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to update departments" ON departments;
CREATE POLICY "Allow authenticated users to update departments"
  ON departments FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to delete departments" ON departments;
CREATE POLICY "Allow authenticated users to delete departments"
  ON departments FOR DELETE
  USING (auth.role() = 'authenticated');


-- ============================================================
-- File: 20260315000011_create_app_notifications_table.sql
-- ============================================================
-- Create app_notifications table for role/user-targeted in-app notifications
CREATE TABLE IF NOT EXISTS app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'info',
  target_role VARCHAR(50) NOT NULL DEFAULT 'all' CHECK (target_role IN ('all', 'admin', 'teacher', 'maintenance')),
  target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  work_request_id TEXT REFERENCES work_requests(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_app_notifications_target_role ON app_notifications(target_role);
CREATE INDEX IF NOT EXISTS idx_app_notifications_target_user_id ON app_notifications(target_user_id);
CREATE INDEX IF NOT EXISTS idx_app_notifications_created_at ON app_notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_notifications_is_read ON app_notifications(is_read);

ALTER TABLE app_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read app_notifications" ON app_notifications;
CREATE POLICY "Allow authenticated users to read app_notifications"
  ON app_notifications FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to insert app_notifications" ON app_notifications;
CREATE POLICY "Allow authenticated users to insert app_notifications"
  ON app_notifications FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to update app_notifications" ON app_notifications;
CREATE POLICY "Allow authenticated users to update app_notifications"
  ON app_notifications FOR UPDATE
  USING (auth.role() = 'authenticated');


-- ============================================================
-- File: 20260315000012_migrate_room_ids_to_rm_format.sql
-- ============================================================
-- Migrate existing UUID-style room IDs to RM#### auto-increment format.
-- Steps:
--   1. Drop FK constraints that reference rooms(id) so we can update the PK.
--   2. Rename each UUID room to RM0001, RM0002, â€¦ in creation order.
--   3. Update every child-table row that referenced the old UUID.
--   4. Re-add FK constraints with the original ON DELETE behaviour.

-- â”€â”€ 1. Drop FK constraints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
ALTER TABLE work_requests   DROP CONSTRAINT IF EXISTS work_requests_room_id_fkey;
ALTER TABLE qr_code_history DROP CONSTRAINT IF EXISTS qr_code_history_room_id_fkey;

-- â”€â”€ 2 & 3. Rename UUIDs and update children â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DO $$
DECLARE
  room_rec RECORD;
  new_id   TEXT;
  counter  INT := 1;
BEGIN
  -- Process only rooms whose id is NOT already RM#### format
  FOR room_rec IN
    SELECT id
    FROM   rooms
    WHERE  id !~ '^RM[0-9]+$'
    ORDER  BY created_at ASC
  LOOP
    -- Find the next free RM#### slot
    LOOP
      new_id := 'RM' || LPAD(counter::TEXT, 4, '0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM rooms WHERE id = new_id);
      counter := counter + 1;
    END LOOP;

    -- Update child tables that reference this room
    UPDATE work_requests   SET room_id = new_id WHERE room_id = room_rec.id;
    UPDATE qr_code_history SET room_id = new_id WHERE room_id = room_rec.id;

    -- Update the room PK itself
    UPDATE rooms SET id = new_id WHERE id = room_rec.id;

    counter := counter + 1;
  END LOOP;
END $$;

-- â”€â”€ 4. Re-add FK constraints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
ALTER TABLE work_requests
  ADD CONSTRAINT work_requests_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL;

ALTER TABLE qr_code_history
  ADD CONSTRAINT qr_code_history_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE;


-- ============================================================
-- File: 20260321000013_create_role_user_tables.sql
-- ============================================================
-- Create separate role profile tables linked to users(id).
-- Each row represents one authenticated user role profile.

-- ============================================================
-- 1) Create role tables
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  office VARCHAR(150),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  specialization VARCHAR(150),
  shift_schedule VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS teacher_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  department VARCHAR(150),
  position VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_users_user_id ON maintenance_users(user_id);
CREATE INDEX IF NOT EXISTS idx_teacher_users_user_id ON teacher_users(user_id);

-- ============================================================
-- 2) Enable RLS + policies
-- ============================================================
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin users can view own profile" ON admin_users;
CREATE POLICY "Admin users can view own profile"
  ON admin_users FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Maintenance users can view own profile" ON maintenance_users;
CREATE POLICY "Maintenance users can view own profile"
  ON maintenance_users FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Teacher users can view own profile" ON teacher_users;
CREATE POLICY "Teacher users can view own profile"
  ON teacher_users FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage admin user profiles" ON admin_users;
CREATE POLICY "Admins can manage admin user profiles"
  ON admin_users FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Admins can manage maintenance user profiles" ON maintenance_users;
CREATE POLICY "Admins can manage maintenance user profiles"
  ON maintenance_users FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

DROP POLICY IF EXISTS "Admins can manage teacher user profiles" ON teacher_users;
CREATE POLICY "Admins can manage teacher user profiles"
  ON teacher_users FOR ALL
  USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));

-- ============================================================
-- 3) Sync function: keep role tables aligned with users.role
-- ============================================================
CREATE OR REPLACE FUNCTION public.sync_role_user_tables()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM admin_users WHERE user_id = NEW.id;
  DELETE FROM maintenance_users WHERE user_id = NEW.id;
  DELETE FROM teacher_users WHERE user_id = NEW.id;

  IF NEW.role = 'admin' THEN
    INSERT INTO admin_users (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
  ELSIF NEW.role = 'maintenance' THEN
    INSERT INTO maintenance_users (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
  ELSIF NEW.role = 'teacher' THEN
    INSERT INTO teacher_users (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_users_sync_role_tables ON users;
CREATE TRIGGER on_users_sync_role_tables
  AFTER INSERT OR UPDATE OF role
  ON users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_role_user_tables();

-- ============================================================
-- 4) Backfill existing users to role tables
-- ============================================================
INSERT INTO admin_users (user_id)
SELECT id FROM users WHERE role = 'admin'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO maintenance_users (user_id)
SELECT id FROM users WHERE role = 'maintenance'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO teacher_users (user_id)
SELECT id FROM users WHERE role = 'teacher'
ON CONFLICT (user_id) DO NOTHING;


-- ============================================================
-- File: 20260327000014_fix_users_policy_recursion.sql
-- ============================================================
-- Fix: infinite recursion in users SELECT policy
-- Root cause: policy on users queried users again via EXISTS(...) causing recursive RLS evaluation.

-- 1) Helper function to check admin role without triggering RLS recursion.
-- SECURITY DEFINER runs with the function owner's privileges.
CREATE OR REPLACE FUNCTION public.is_admin_user(target_uid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = target_uid
      AND u.role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_user(UUID) TO authenticated;

-- 2) Replace recursive policy with a non-recursive policy.
DROP POLICY IF EXISTS "Admins can view all user profiles" ON users;

CREATE POLICY "Admins can view all user profiles"
  ON users FOR SELECT
  USING (public.is_admin_user(auth.uid()));


-- ============================================================
-- File: 20260327000015_simplify_departments_for_room_identity.sql
-- ============================================================
-- ============================================================
-- Migration: Simplify departments for room identity usage
-- Goal: Keep departments centered on identity fields (id, name, code)
-- while remaining backward-compatible with current application code.
-- ============================================================

-- 1) Keep legacy metadata columns optional
--    This allows existing code paths to continue working but removes
--    strict dependency on campus/contact/head data.
ALTER TABLE departments ALTER COLUMN campus DROP NOT NULL;
ALTER TABLE departments ALTER COLUMN campus DROP DEFAULT;

-- 2) If campus index exists from legacy usage, remove it.
--    For identity lookups, name/code indexes are enough.
DROP INDEX IF EXISTS idx_departments_campus;

-- 3) Provide a clean identity view for room-related usage.
CREATE OR REPLACE VIEW department_identity AS
SELECT id, name, code
FROM departments;

-- 4) Grant authenticated users read access to the identity view.
GRANT SELECT ON department_identity TO authenticated;


-- ============================================================
-- File: 20260327000016_add_account_management_fields.sql
-- ============================================================
-- ============================================================
-- Migration: Support faculty self-registration and admin maintenance management
-- ============================================================

-- 1) Extend role profile tables with fields used by UI forms.
ALTER TABLE teacher_users ADD COLUMN IF NOT EXISTS employee_id VARCHAR(100);

ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS department VARCHAR(150);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS employee_id VARCHAR(100);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS contact_no VARCHAR(20);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS created_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_users_created_by_admin_id
  ON maintenance_users(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_users_employee_id
  ON maintenance_users(employee_id);
CREATE INDEX IF NOT EXISTS idx_teacher_users_employee_id
  ON teacher_users(employee_id);

-- 2) Make admin-management policies non-recursive via helper function.
DROP POLICY IF EXISTS "Admins can manage admin user profiles" ON admin_users;
CREATE POLICY "Admins can manage admin user profiles"
  ON admin_users FOR ALL
  USING (public.is_admin_user(auth.uid()))
  WITH CHECK (public.is_admin_user(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage maintenance user profiles" ON maintenance_users;
CREATE POLICY "Admins can manage maintenance user profiles"
  ON maintenance_users FOR ALL
  USING (public.is_admin_user(auth.uid()))
  WITH CHECK (public.is_admin_user(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage teacher user profiles" ON teacher_users;
CREATE POLICY "Admins can manage teacher user profiles"
  ON teacher_users FOR ALL
  USING (public.is_admin_user(auth.uid()))
  WITH CHECK (public.is_admin_user(auth.uid()));

-- 3) Ensure new faculty accounts stay inactive until verified.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_role VARCHAR(50);
BEGIN
  new_role := COALESCE(NEW.raw_user_meta_data->>'role', 'teacher');

  INSERT INTO public.users (id, email, name, role, is_active)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    new_role,
    CASE WHEN new_role = 'teacher' THEN false ELSE true END
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.activate_verified_faculty_user()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL THEN
    UPDATE public.users
      SET is_active = true,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = NEW.id
        AND role = 'teacher';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_verified ON auth.users;
CREATE TRIGGER on_auth_user_verified
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.activate_verified_faculty_user();

-- Backfill currently verified faculty accounts as active.
UPDATE users u
SET is_active = true,
    updated_at = CURRENT_TIMESTAMP
FROM auth.users au
WHERE u.id = au.id
  AND u.role = 'teacher'
  AND au.email_confirmed_at IS NOT NULL;


-- ============================================================
-- File: 20260327000017_enforce_single_admin_user.sql
-- ============================================================
-- Enforce a single admin account in users table.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_single_admin
  ON users(role)
  WHERE role = 'admin';


-- ============================================================
-- File: 20260327000018_limit_teacher_management_and_maintenance_archive.sql
-- ============================================================
-- Restrict admin access: no teacher profile management, only view if needed.
-- Also scope maintenance management to accounts created by the current admin.

ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS archived_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_users_archived_at
  ON maintenance_users(archived_at);

DROP POLICY IF EXISTS "Admins can manage teacher user profiles" ON teacher_users;
CREATE POLICY "Admins can view teacher user profiles"
  ON teacher_users FOR SELECT
  USING (public.is_admin_user(auth.uid()));

DROP POLICY IF EXISTS "Admins can manage maintenance user profiles" ON maintenance_users;
CREATE POLICY "Admins can manage own maintenance user profiles"
  ON maintenance_users FOR ALL
  USING (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  )
  WITH CHECK (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  );


-- ============================================================
-- File: 20260327000019_fix_maintenance_signup_policy.sql
-- ============================================================
-- Fix maintenance account creation: allow initial trigger-created row with NULL creator,
-- while keeping admin ownership restrictions for ongoing management.

DROP POLICY IF EXISTS "Admins can manage own maintenance user profiles" ON maintenance_users;

CREATE POLICY "Admins can view own maintenance user profiles"
  ON maintenance_users FOR SELECT
  USING (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  );

CREATE POLICY "Admins can insert maintenance user profiles"
  ON maintenance_users FOR INSERT
  WITH CHECK (
    public.is_admin_user(auth.uid())
    AND (
      created_by_admin_id = auth.uid()
      OR created_by_admin_id IS NULL
    )
  );

CREATE POLICY "Admins can update own maintenance user profiles"
  ON maintenance_users FOR UPDATE
  USING (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  )
  WITH CHECK (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  );

CREATE POLICY "Admins can delete own maintenance user profiles"
  ON maintenance_users FOR DELETE
  USING (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  );


-- ============================================================
-- File: 20260327000020_fix_auth_trigger_rls_for_role_tables.sql
-- ============================================================
-- Fix signup failures caused by auth-trigger writes being blocked by strict RLS.
-- Supabase auth may execute trigger-side writes under supabase_auth_admin/service_role.

-- 1) Allow auth system roles to insert into users from trigger flows.
DROP POLICY IF EXISTS "Allow service_role to create users" ON users;
CREATE POLICY "Allow system roles to create users"
  ON users FOR INSERT
  WITH CHECK (auth.role() IN ('service_role', 'supabase_auth_admin'));

-- 2) Allow auth system roles to sync role profile tables via trigger function.
DROP POLICY IF EXISTS "System roles can manage admin user profiles" ON admin_users;
CREATE POLICY "System roles can manage admin user profiles"
  ON admin_users FOR ALL
  USING (auth.role() IN ('service_role', 'supabase_auth_admin'))
  WITH CHECK (auth.role() IN ('service_role', 'supabase_auth_admin'));

DROP POLICY IF EXISTS "System roles can manage maintenance user profiles" ON maintenance_users;
CREATE POLICY "System roles can manage maintenance user profiles"
  ON maintenance_users FOR ALL
  USING (auth.role() IN ('service_role', 'supabase_auth_admin'))
  WITH CHECK (auth.role() IN ('service_role', 'supabase_auth_admin'));

DROP POLICY IF EXISTS "System roles can manage teacher user profiles" ON teacher_users;
CREATE POLICY "System roles can manage teacher user profiles"
  ON teacher_users FOR ALL
  USING (auth.role() IN ('service_role', 'supabase_auth_admin'))
  WITH CHECK (auth.role() IN ('service_role', 'supabase_auth_admin'));

-- 3) Keep admin ownership constraints, but allow claiming newly created
-- maintenance rows where created_by_admin_id is initially NULL.
DROP POLICY IF EXISTS "Admins can update own maintenance user profiles" ON maintenance_users;
CREATE POLICY "Admins can update own maintenance user profiles"
  ON maintenance_users FOR UPDATE
  USING (
    public.is_admin_user(auth.uid())
    AND (
      created_by_admin_id = auth.uid()
      OR created_by_admin_id IS NULL
    )
  )
  WITH CHECK (
    public.is_admin_user(auth.uid())
    AND created_by_admin_id = auth.uid()
  );


-- ============================================================
-- File: 20260327000021_fix_system_role_policies_by_db_role.sql
-- ============================================================
-- Fix auth signup trigger writes by targeting actual DB roles directly in RLS policies.
-- Using auth.role() can fail in trigger contexts where JWT claims are absent.

-- users table: allow auth system roles to insert/update profile rows from auth triggers.
DROP POLICY IF EXISTS "Allow system roles to create users" ON users;
DROP POLICY IF EXISTS "System roles can insert users" ON users;
DROP POLICY IF EXISTS "System roles can update users" ON users;

CREATE POLICY "System roles can insert users"
  ON users FOR INSERT
  TO service_role, supabase_auth_admin
  WITH CHECK (true);

CREATE POLICY "System roles can update users"
  ON users FOR UPDATE
  TO service_role, supabase_auth_admin
  USING (true)
  WITH CHECK (true);

-- role profile tables: allow auth system roles to sync rows from trigger function.
DROP POLICY IF EXISTS "System roles can manage admin user profiles" ON admin_users;
DROP POLICY IF EXISTS "System roles can manage maintenance user profiles" ON maintenance_users;
DROP POLICY IF EXISTS "System roles can manage teacher user profiles" ON teacher_users;

CREATE POLICY "System roles can manage admin user profiles"
  ON admin_users FOR ALL
  TO service_role, supabase_auth_admin
  USING (true)
  WITH CHECK (true);

CREATE POLICY "System roles can manage maintenance user profiles"
  ON maintenance_users FOR ALL
  TO service_role, supabase_auth_admin
  USING (true)
  WITH CHECK (true);

CREATE POLICY "System roles can manage teacher user profiles"
  ON teacher_users FOR ALL
  TO service_role, supabase_auth_admin
  USING (true)
  WITH CHECK (true);


-- ============================================================
-- File: 20260327000022_create_room_types_table.sql
-- ============================================================
-- Create room_types table
CREATE TABLE IF NOT EXISTS room_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_room_types_name ON room_types(name);

ALTER TABLE room_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read room types" ON room_types;
CREATE POLICY "Allow authenticated users to read room types"
  ON room_types FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow admins to manage room types" ON room_types;
CREATE POLICY "Allow admins to manage room types"
  ON room_types FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );

ALTER TABLE rooms DROP CONSTRAINT IF EXISTS rooms_room_type_check;


-- ============================================================
-- File: 20260401000019_create_floors_table.sql
-- ============================================================
-- Create floors table
CREATE TABLE IF NOT EXISTS floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_floors_name ON floors(name);

-- Enable RLS
ALTER TABLE floors ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "Allow authenticated users to read floors" ON floors;
CREATE POLICY "Allow authenticated users to read floors"
  ON floors FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to insert floors" ON floors;
CREATE POLICY "Allow authenticated users to insert floors"
  ON floors FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to update floors" ON floors;
CREATE POLICY "Allow authenticated users to update floors"
  ON floors FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to delete floors" ON floors;
CREATE POLICY "Allow authenticated users to delete floors"
  ON floors FOR DELETE
  USING (auth.role() = 'authenticated');


-- ============================================================
-- File: 20260401000020_normalize_master_tables_and_remove_seed_data.sql
-- ============================================================
-- Normalize master tables and remove legacy static seed data.
-- This keeps the lookup tables admin-managed instead of prepopulated.

ALTER TABLE departments
  ADD COLUMN IF NOT EXISTS code VARCHAR(50),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE buildings
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE request_types
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_departments_code ON departments(code);

DELETE FROM departments
WHERE code IN ('CAS', 'COE', 'COB', 'COED', 'CIT');

DELETE FROM buildings
WHERE code IN ('MAB', 'EBA', 'EBB', 'SC', 'AB');

DELETE FROM request_types
WHERE name IN (
  'Ocular Inspection',
  'Installation',
  'Repair',
  'Replacement',
  'Router Inspection',
  'Remediation',
  'Preventive Maintenance',
  'Emergency Repair'
);

DELETE FROM room_types
WHERE name IN ('Laboratory', 'Lecture Hall', 'Seminar Room', 'Office', 'Storage', 'Conference Room');

DELETE FROM floors
WHERE code IN ('FLOOR_1', 'FLOOR_2', 'FLOOR_3', 'FLOOR_4');

ALTER TABLE departments DROP COLUMN IF EXISTS campus;
ALTER TABLE departments DROP COLUMN IF EXISTS contact_email;
ALTER TABLE departments DROP COLUMN IF EXISTS contact_phone;
ALTER TABLE departments DROP COLUMN IF EXISTS head_name;

ALTER TABLE buildings DROP COLUMN IF EXISTS campus;
ALTER TABLE buildings DROP COLUMN IF EXISTS address;
ALTER TABLE buildings DROP COLUMN IF EXISTS floors;
ALTER TABLE buildings DROP COLUMN IF EXISTS total_rooms;
ALTER TABLE buildings DROP COLUMN IF EXISTS description;
ALTER TABLE buildings DROP COLUMN IF EXISTS building_manager;

ALTER TABLE request_types DROP COLUMN IF EXISTS code;
ALTER TABLE request_types DROP COLUMN IF EXISTS description;
ALTER TABLE request_types DROP COLUMN IF EXISTS is_active;

ALTER TABLE room_types DROP COLUMN IF EXISTS description;
ALTER TABLE room_types DROP COLUMN IF EXISTS is_active;
ALTER TABLE work_requests DROP COLUMN IF EXISTS campus;

ALTER TABLE floors DROP COLUMN IF EXISTS is_active;

ALTER TABLE rooms DROP CONSTRAINT IF EXISTS rooms_room_type_check;

-- ============================================================
-- File: 20260402000021_apply_base_migration_deltas.sql
-- ============================================================
-- Catch-up migration for changes made to already-applied base migrations.
-- This ensures remote databases receive the same effective schema updates.

-- 1) Drop legacy constraints first so normalization updates can run safely.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE app_notifications DROP CONSTRAINT IF EXISTS app_notifications_target_role_check;
ALTER TABLE e_signatures DROP CONSTRAINT IF EXISTS e_signatures_signer_role_check;

-- 2) Normalize legacy role values.
UPDATE users
SET role = 'teacher'
WHERE role = 'student_teacher';

UPDATE app_notifications
SET target_role = 'teacher'
WHERE target_role = 'student_teacher';

UPDATE e_signatures
SET signer_role = 'teacher'
WHERE signer_role = 'student_teacher';

-- 3) Enforce users.role allowed values.
ALTER TABLE users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin', 'teacher', 'maintenance'));

-- 4) Enforce app_notifications.target_role allowed values.
ALTER TABLE app_notifications
  ADD CONSTRAINT app_notifications_target_role_check
  CHECK (target_role IN ('all', 'admin', 'teacher', 'maintenance'));

-- 5) Enforce e_signatures.signer_role allowed values.
ALTER TABLE e_signatures
  ADD CONSTRAINT e_signatures_signer_role_check
  CHECK (signer_role IN ('admin', 'maintenance', 'teacher'));

-- 6) Remove legacy static room_type check if still present.
ALTER TABLE rooms DROP CONSTRAINT IF EXISTS rooms_room_type_check;


-- ============================================================
-- File: 20260402000022_finalize_department_drop_code.sql
-- ============================================================
-- Finalize department schema without code column.
-- Uses IF EXISTS guards to be safe across partial migration attempts.

DROP VIEW IF EXISTS department_identity;

DROP INDEX IF EXISTS idx_departments_code;
ALTER TABLE departments DROP COLUMN IF EXISTS code;

CREATE VIEW department_identity AS
SELECT id, name
FROM departments;

GRANT SELECT ON department_identity TO authenticated;


-- ============================================================
-- File: 20260402000023_add_department_id_to_buildings.sql
-- ============================================================
-- Connect buildings to departments.

ALTER TABLE buildings
  ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES departments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_buildings_department_id ON buildings(department_id);



-- ============================================================
-- File: 202604100003_drop_users_campus_column.sql
-- ============================================================
-- Remove legacy campus attribute from users table.
-- Safe to run multiple times.

ALTER TABLE public.users DROP COLUMN IF EXISTS campus;



