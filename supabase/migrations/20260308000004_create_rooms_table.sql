-- Create rooms table
CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  building_id UUID REFERENCES buildings(id) ON DELETE CASCADE NOT NULL,
  floor VARCHAR(50) NOT NULL,
  room_number VARCHAR(50),
  seats INT DEFAULT 40,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  room_type VARCHAR(100) CHECK (room_type IN ('Laboratory', 'Lecture Hall', 'Seminar Room', 'Office', 'Storage', 'Conference Room')) DEFAULT 'Laboratory',
  status VARCHAR(50) CHECK (status IN ('available', 'reserved', 'maintenance', 'inactive')) DEFAULT 'available',
  image_url VARCHAR(500),
  description TEXT,
  qr_code_data TEXT UNIQUE,
  equipment TEXT,
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
