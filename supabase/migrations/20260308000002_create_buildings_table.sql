-- Create buildings table
CREATE TABLE IF NOT EXISTS buildings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  campus VARCHAR(100) NOT NULL,
  address TEXT,
  floors INT DEFAULT 3,
  total_rooms INT DEFAULT 0,
  description TEXT,
  building_manager VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_buildings_name ON buildings(name);
CREATE INDEX IF NOT EXISTS idx_buildings_campus ON buildings(campus);
CREATE INDEX IF NOT EXISTS idx_buildings_code ON buildings(code);

-- Enable RLS
ALTER TABLE buildings ENABLE ROW LEVEL SECURITY;

-- Create policies
DROP POLICY IF EXISTS "Allow authenticated users to read buildings" ON buildings;
CREATE POLICY "Allow authenticated users to read buildings"
  ON buildings FOR SELECT
  USING (auth.role() = 'authenticated');
