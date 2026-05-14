-- Add surrogate UUID primary keys to extension profile tables while preserving one-to-one user mapping.
-- Tables affected: teacher_users, maintenance_users, maintenance_user_archives
-- Compatibility: keeps user_id column and enforces UNIQUE(user_id).

BEGIN;

-- ---------------------------------------------------------------------------
-- maintenance_users
-- ---------------------------------------------------------------------------
ALTER TABLE public.maintenance_users
  ADD COLUMN IF NOT EXISTS id UUID;

UPDATE public.maintenance_users
SET id = gen_random_uuid()
WHERE id IS NULL;

ALTER TABLE public.maintenance_users
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL;

ALTER TABLE public.maintenance_users
  DROP CONSTRAINT IF EXISTS maintenance_users_pkey;

ALTER TABLE public.maintenance_users
  ADD CONSTRAINT maintenance_users_pkey PRIMARY KEY (id);

ALTER TABLE public.maintenance_users
  DROP CONSTRAINT IF EXISTS maintenance_users_user_id_key;

ALTER TABLE public.maintenance_users
  ADD CONSTRAINT maintenance_users_user_id_key UNIQUE (user_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_users_user_id
  ON public.maintenance_users(user_id);

-- ---------------------------------------------------------------------------
-- maintenance_user_archives
-- ---------------------------------------------------------------------------
ALTER TABLE public.maintenance_user_archives
  ADD COLUMN IF NOT EXISTS id UUID;

UPDATE public.maintenance_user_archives
SET id = gen_random_uuid()
WHERE id IS NULL;

ALTER TABLE public.maintenance_user_archives
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL;

ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_pkey;

ALTER TABLE public.maintenance_user_archives
  ADD CONSTRAINT maintenance_user_archives_pkey PRIMARY KEY (id);

ALTER TABLE public.maintenance_user_archives
  DROP CONSTRAINT IF EXISTS maintenance_user_archives_user_id_key;

ALTER TABLE public.maintenance_user_archives
  ADD CONSTRAINT maintenance_user_archives_maintenance_id_key UNIQUE (maintenance_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_user_archives_maintenance_id
  ON public.maintenance_user_archives(maintenance_id);

-- ---------------------------------------------------------------------------
-- teacher_users
-- ---------------------------------------------------------------------------
ALTER TABLE public.teacher_users
  ADD COLUMN IF NOT EXISTS id UUID;

UPDATE public.teacher_users
SET id = gen_random_uuid()
WHERE id IS NULL;

ALTER TABLE public.teacher_users
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL;

ALTER TABLE public.teacher_users
  DROP CONSTRAINT IF EXISTS teacher_users_pkey;

ALTER TABLE public.teacher_users
  ADD CONSTRAINT teacher_users_pkey PRIMARY KEY (id);

ALTER TABLE public.teacher_users
  DROP CONSTRAINT IF EXISTS teacher_users_user_id_key;

ALTER TABLE public.teacher_users
  ADD CONSTRAINT teacher_users_user_id_key UNIQUE (user_id);

CREATE INDEX IF NOT EXISTS idx_teacher_users_user_id
  ON public.teacher_users(user_id);

COMMIT;
