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
  signer_role VARCHAR(50) NOT NULL CHECK (signer_role IN ('admin', 'maintenance', 'student_teacher')),
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

CREATE POLICY "Allow authenticated users to read e_signatures"
  ON e_signatures FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Allow users to insert their own e_signatures"
  ON e_signatures FOR INSERT
  WITH CHECK (signer_id = auth.uid());

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

CREATE POLICY "Allow authenticated users to read pre_inspection_reports"
  ON pre_inspection_reports FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Allow maintenance to insert pre_inspection_reports"
  ON pre_inspection_reports FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('maintenance', 'admin'))
  );

CREATE POLICY "Allow admins to manage all pre_inspection_reports"
  ON pre_inspection_reports FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

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

CREATE POLICY "Allow authenticated users to read post_repair_reports"
  ON post_repair_reports FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Allow maintenance to insert post_repair_reports"
  ON post_repair_reports FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('maintenance', 'admin'))
  );

CREATE POLICY "Allow admins to manage all post_repair_reports"
  ON post_repair_reports FOR ALL
  USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Allow maintenance to update own post_repair_reports"
  ON post_repair_reports FOR UPDATE
  USING (technician_id = auth.uid());

-- Add foreign key references from work_requests
ALTER TABLE work_requests ADD CONSTRAINT fk_pre_inspection
  FOREIGN KEY (pre_inspection_id) REFERENCES pre_inspection_reports(id) ON DELETE SET NULL;

ALTER TABLE work_requests ADD CONSTRAINT fk_post_repair
  FOREIGN KEY (post_repair_id) REFERENCES post_repair_reports(id) ON DELETE SET NULL;
