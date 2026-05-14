-- Refactor maintenance schema: simplify active profile columns and move archives to a dedicated table.
-- Date: 2026-04-06

-- Ensure active maintenance profile keeps only required fields.
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS specialization VARCHAR(150);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS employee_id VARCHAR(100);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS profile_image VARCHAR(500);
ALTER TABLE maintenance_users ADD COLUMN IF NOT EXISTS created_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Remove deprecated columns no longer used by maintenance account creation flow.
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS shift_schedule;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS department_id;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS department_snapshot;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS archived_at;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS archived_by_admin_id;
ALTER TABLE maintenance_users DROP CONSTRAINT IF EXISTS fk_maintenance_users_department_id;

-- Dedicated archive table for maintenance accounts.
CREATE TABLE IF NOT EXISTS maintenance_user_archives (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  maintenance_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  archive_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  archived_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  original_created_at TIMESTAMP WITH TIME ZONE,
);

-- Indexes
DROP INDEX IF EXISTS idx_maintenance_users_department_id;
CREATE INDEX IF NOT EXISTS idx_maintenance_users_created_by_admin_id ON maintenance_users(created_by_admin_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_users_employee_id ON maintenance_users(employee_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_user_archives_maintenance_id ON maintenance_user_archives(maintenance_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_user_archives_archive_at ON maintenance_user_archives(archive_at DESC);

-- RLS for archive table.
ALTER TABLE maintenance_user_archives ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS maintenance_user_archives_select_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_select_policy ON maintenance_user_archives
FOR SELECT
USING (public.is_admin());

DROP POLICY IF EXISTS maintenance_user_archives_insert_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_insert_policy ON maintenance_user_archives
FOR INSERT
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS maintenance_user_archives_update_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_update_policy ON maintenance_user_archives
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS maintenance_user_archives_delete_policy ON maintenance_user_archives;
CREATE POLICY maintenance_user_archives_delete_policy ON maintenance_user_archives
FOR DELETE
USING (public.is_admin());
