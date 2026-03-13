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
