-- Create work_requests table
CREATE TABLE IF NOT EXISTS work_requests (
  id TEXT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  type_of_request VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL CHECK (status IN ('pending', 'ongoing', 'done', 'cancelled')) DEFAULT 'pending',
  priority VARCHAR(50) NOT NULL CHECK (priority IN ('low', 'medium', 'high')) DEFAULT 'medium',
  campus VARCHAR(100) NOT NULL,
  building_name VARCHAR(255) NOT NULL,
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  department VARCHAR(255) NOT NULL,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  office_room VARCHAR(100) NOT NULL,
  room_id TEXT REFERENCES rooms(id) ON DELETE SET NULL,
  date_submitted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_completed TIMESTAMP WITH TIME ZONE,
  date_due TIMESTAMP WITH TIME ZONE,
  requestor_name VARCHAR(255) NOT NULL,
  requestor_position VARCHAR(100) NOT NULL,
  requestor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reported_by VARCHAR(255),
  reported_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_by VARCHAR(255),
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
