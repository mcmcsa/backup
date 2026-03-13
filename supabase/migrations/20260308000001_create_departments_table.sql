-- Create departments table
CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  code VARCHAR(50) NOT NULL UNIQUE,
  campus VARCHAR(100) NOT NULL,
  contact_email VARCHAR(255),
  contact_phone VARCHAR(20),
  head_name VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index on department name for faster lookups
CREATE INDEX IF NOT EXISTS idx_departments_name ON departments(name);
CREATE INDEX IF NOT EXISTS idx_departments_campus ON departments(campus);

-- Enable RLS (Row Level Security)
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Create policies for departments (allow all authenticated users to read)
DROP POLICY IF EXISTS "Allow authenticated users to read departments" ON departments;
CREATE POLICY "Allow authenticated users to read departments"
  ON departments FOR SELECT
  USING (auth.role() = 'authenticated');
