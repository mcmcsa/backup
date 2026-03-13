-- Create room_schedules table
CREATE TABLE IF NOT EXISTS room_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  subject_name VARCHAR(255) NOT NULL,
  instructor VARCHAR(255) NOT NULL,
  scheduled_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_maintenance_window BOOLEAN DEFAULT false,
  notes TEXT,
  status VARCHAR(50) CHECK (status IN ('scheduled', 'confirmed', 'cancelled')) DEFAULT 'scheduled',
  created_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_room_schedules_room_id ON room_schedules(room_id);
CREATE INDEX IF NOT EXISTS idx_room_schedules_scheduled_date ON room_schedules(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_room_schedules_status ON room_schedules(status);

-- Enable RLS
ALTER TABLE room_schedules ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow authenticated users to read room schedules" ON room_schedules;
CREATE POLICY "Allow authenticated users to read room schedules"
  ON room_schedules FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to insert room schedules" ON room_schedules;
CREATE POLICY "Allow authenticated users to insert room schedules"
  ON room_schedules FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow admins to manage all room schedules" ON room_schedules;
CREATE POLICY "Allow admins to manage all room schedules"
  ON room_schedules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
    )
  );
