-- Reassert surrogate PK + one-to-one unique user_id on extension tables.
-- Safe to re-run.

BEGIN;

-- maintenance_users
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

-- maintenance_user_archives
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

ALTER TABLE public.maintenance_user_archives
  DROP COLUMN IF EXISTS user_id,
  DROP COLUMN IF EXISTS employee_id,
  DROP COLUMN IF EXISTS specialization,
  DROP COLUMN IF EXISTS phone,
  DROP COLUMN IF EXISTS profile_image,
  DROP COLUMN IF EXISTS created_by_admin_id,
  DROP COLUMN IF EXISTS created_at,
  DROP COLUMN IF EXISTS updated_at;

DROP TRIGGER IF EXISTS trg_maintenance_user_archives_updated_at ON public.maintenance_user_archives;

-- teacher_users
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

COMMIT;
