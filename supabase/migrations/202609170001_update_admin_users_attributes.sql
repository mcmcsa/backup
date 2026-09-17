-- Migration: Update admin_users table attributes to match profile fields and extension schema pattern
-- Adds employee_id, position, surrogate PK id, and updates RLS policies.

BEGIN;

-- 1. Add missing attributes to admin_users
ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS employee_id VARCHAR(100),
  ADD COLUMN IF NOT EXISTS position VARCHAR(100);

-- 2. Add surrogate UUID primary key id (matching teacher_users and maintenance_users)
ALTER TABLE public.admin_users
  ADD COLUMN IF NOT EXISTS id UUID;

UPDATE public.admin_users
SET id = gen_random_uuid()
WHERE id IS NULL;

ALTER TABLE public.admin_users
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN id SET NOT NULL;

-- Ensure user_id unique constraint exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'admin_users_user_id_key' AND conrelid = 'public.admin_users'::regclass
  ) THEN
    ALTER TABLE public.admin_users ADD CONSTRAINT admin_users_user_id_key UNIQUE (user_id);
  END IF;
END $$;

-- Update primary key to surrogate id if currently user_id
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'admin_users_pkey' AND conrelid = 'public.admin_users'::regclass
  ) THEN
    ALTER TABLE public.admin_users DROP CONSTRAINT admin_users_pkey;
    ALTER TABLE public.admin_users ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_users_employee_id ON public.admin_users(employee_id);

-- 3. Update RLS Policies for admin_users
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin users can view own profile" ON public.admin_users;
CREATE POLICY "Admin users can view own profile"
  ON public.admin_users FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin users can update own profile" ON public.admin_users;
CREATE POLICY "Admin users can update own profile"
  ON public.admin_users FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin users can insert own profile" ON public.admin_users;
CREATE POLICY "Admin users can insert own profile"
  ON public.admin_users FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can manage admin user profiles" ON public.admin_users;
CREATE POLICY "Admins can manage admin user profiles"
  ON public.admin_users FOR ALL
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'campadmin')))
  WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'campadmin')));

-- 4. Automatically backfill existing admin/campadmin users into admin_users if missing
INSERT INTO public.admin_users (user_id)
SELECT id FROM public.users
WHERE role IN ('admin', 'campadmin')
ON CONFLICT (user_id) DO NOTHING;

COMMIT;
