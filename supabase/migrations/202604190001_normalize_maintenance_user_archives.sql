-- Normalize maintenance_user_archives to the canonical 5-column shape:
-- id, maintenance_id, archived_by_admin_id, archive_at, original_created_at
-- This migration is safe across mixed legacy schemas.

BEGIN;

-- Ensure core columns exist.
ALTER TABLE public.maintenance_user_archives
  ADD COLUMN IF NOT EXISTS id UUID,
  ADD COLUMN IF NOT EXISTS maintenance_id UUID,
  ADD COLUMN IF NOT EXISTS archived_by_admin_id UUID,
  ADD COLUMN IF NOT EXISTS archive_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS original_created_at TIMESTAMP WITH TIME ZONE;

-- Backfill id.
UPDATE public.maintenance_user_archives
SET id = gen_random_uuid()
WHERE id IS NULL;

-- Backfill from legacy columns only when those columns exist.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_user_archives'
      AND column_name = 'user_id'
  ) THEN
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET maintenance_id = user_id
      WHERE maintenance_id IS NULL
        AND user_id IS NOT NULL
    ';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_user_archives'
      AND column_name = 'archived_at'
  ) AND EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_user_archives'
      AND column_name = 'created_at'
  ) THEN
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET archive_at = COALESCE(archive_at, archived_at, created_at, CURRENT_TIMESTAMP)
      WHERE archive_at IS NULL
    ';
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_user_archives'
      AND column_name = 'archived_at'
  ) THEN
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET archive_at = COALESCE(archive_at, archived_at, CURRENT_TIMESTAMP)
      WHERE archive_at IS NULL
    ';
  ELSIF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_user_archives'
      AND column_name = 'created_at'
  ) THEN
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET archive_at = COALESCE(archive_at, created_at, CURRENT_TIMESTAMP)
      WHERE archive_at IS NULL
    ';
  ELSE
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET archive_at = COALESCE(archive_at, CURRENT_TIMESTAMP)
      WHERE archive_at IS NULL
    ';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_user_archives'
      AND column_name = 'created_at'
  ) THEN
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET original_created_at = COALESCE(original_created_at, created_at)
      WHERE original_created_at IS NULL
    ';
  ELSE
    EXECUTE '
      UPDATE public.maintenance_user_archives
      SET original_created_at = COALESCE(original_created_at, archive_at)
      WHERE original_created_at IS NULL
    ';
  END IF;
END $$;

-- Apply defaults and not-null constraints for canonical columns.
ALTER TABLE public.maintenance_user_archives
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL,
  ALTER COLUMN maintenance_id SET NOT NULL,
  ALTER COLUMN archive_at SET DEFAULT CURRENT_TIMESTAMP,
  ALTER COLUMN archive_at SET NOT NULL;

-- Rebuild key constraints.
ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_pkey;
ALTER TABLE public.maintenance_user_archives
  ADD CONSTRAINT maintenance_user_archives_pkey PRIMARY KEY (id);

ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_user_id_key;
ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_maintenance_id_key;
ALTER TABLE public.maintenance_user_archives
  ADD CONSTRAINT maintenance_user_archives_maintenance_id_key UNIQUE (maintenance_id);

ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_maintenance_id_fkey;
ALTER TABLE public.maintenance_user_archives
  ADD CONSTRAINT maintenance_user_archives_maintenance_id_fkey
  FOREIGN KEY (maintenance_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_archived_by_admin_id_fkey;
ALTER TABLE public.maintenance_user_archives
  ADD CONSTRAINT maintenance_user_archives_archived_by_admin_id_fkey
  FOREIGN KEY (archived_by_admin_id) REFERENCES public.users(id) ON DELETE SET NULL;

-- Keep only canonical columns.
ALTER TABLE public.maintenance_user_archives
  DROP COLUMN IF EXISTS user_id,
  DROP COLUMN IF EXISTS employee_id,
  DROP COLUMN IF EXISTS specialization,
  DROP COLUMN IF EXISTS phone,
  DROP COLUMN IF EXISTS profile_image,
  DROP COLUMN IF EXISTS created_by_admin_id,
  DROP COLUMN IF EXISTS archived_at,
  DROP COLUMN IF EXISTS created_at,
  DROP COLUMN IF EXISTS updated_at;

-- Ensure useful index exists.
CREATE INDEX IF NOT EXISTS idx_maintenance_user_archives_maintenance_id
  ON public.maintenance_user_archives(maintenance_id);

COMMIT;
