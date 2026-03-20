-- Create app_notifications table for role/user-targeted in-app notifications
CREATE TABLE IF NOT EXISTS app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'info',
  target_role VARCHAR(50) NOT NULL DEFAULT 'all' CHECK (target_role IN ('all', 'admin', 'student_teacher', 'maintenance')),
  target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  work_request_id TEXT REFERENCES work_requests(id) ON DELETE CASCADE,
  status_snapshot VARCHAR(50),
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
