-- Add room_name, building and department columns to qr_code_history table
ALTER TABLE qr_code_history ADD COLUMN IF NOT EXISTS room_name TEXT;
ALTER TABLE qr_code_history ADD COLUMN IF NOT EXISTS building TEXT;
ALTER TABLE qr_code_history ADD COLUMN IF NOT EXISTS department TEXT;
