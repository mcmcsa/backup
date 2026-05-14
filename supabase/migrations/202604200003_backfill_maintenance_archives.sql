-- Backfill archive rows for existing inactive maintenance users.
-- This keeps the archived tab populated even if earlier archive writes were missed.

INSERT INTO public.maintenance_user_archives (
  maintenance_id,
  archived_by_admin_id,
  archive_at,
  original_created_at
)
SELECT
  u.id AS maintenance_id,
  NULL::UUID AS archived_by_admin_id,
  COALESCE(u.updated_at, u.created_at, CURRENT_TIMESTAMP) AS archive_at,
  COALESCE(m.created_at, u.created_at, CURRENT_TIMESTAMP) AS original_created_at
FROM public.users u
LEFT JOIN public.maintenance_users m ON m.user_id = u.id
WHERE u.role = 'maintenance'
  AND u.is_active = false
  AND NOT EXISTS (
    SELECT 1
    FROM public.maintenance_user_archives a
    WHERE a.maintenance_id = u.id
  )
ON CONFLICT (maintenance_id) DO NOTHING;
