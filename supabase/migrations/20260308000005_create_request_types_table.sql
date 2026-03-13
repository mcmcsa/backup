-- Create request_types table
CREATE TABLE IF NOT EXISTS request_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  code VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
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
