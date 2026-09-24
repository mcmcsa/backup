-- ==============================================================================
-- Migration: Many-to-Many Department <-> Building Relationship
-- Date: 2026-09-24
-- ==============================================================================

-- 1. Create junction table: public.department_buildings
CREATE TABLE IF NOT EXISTS public.department_buildings (
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (department_id, building_id)
);

-- 2. Indexes for high-performance lookups in both directions
CREATE INDEX IF NOT EXISTS idx_dept_bldgs_department_id 
  ON public.department_buildings(department_id);

CREATE INDEX IF NOT EXISTS idx_dept_bldgs_building_id 
  ON public.department_buildings(building_id);

-- 3. Row Level Security Policies
ALTER TABLE public.department_buildings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read department_buildings" ON public.department_buildings;
CREATE POLICY "Allow authenticated read department_buildings"
  ON public.department_buildings FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Allow admin write department_buildings" ON public.department_buildings;
CREATE POLICY "Allow admin write department_buildings"
  ON public.department_buildings FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 4. Data Migration: Preserve all existing Department -> Building relationships
-- A. From departments.building_id (if the column exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'departments' 
      AND column_name = 'building_id'
  ) THEN
    INSERT INTO public.department_buildings (department_id, building_id)
    SELECT id, building_id
    FROM public.departments
    WHERE building_id IS NOT NULL
    ON CONFLICT (department_id, building_id) DO NOTHING;
  END IF;
END $$;

-- B. From rooms table (ensure any building + department pairings from actual rooms are preserved)
INSERT INTO public.department_buildings (department_id, building_id)
SELECT DISTINCT department_id, building_id
FROM public.rooms
WHERE department_id IS NOT NULL 
  AND building_id IS NOT NULL
ON CONFLICT (department_id, building_id) DO NOTHING;

-- C. From buildings.department_id (legacy column if still present)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'buildings' 
      AND column_name = 'department_id'
  ) THEN
    INSERT INTO public.department_buildings (department_id, building_id)
    SELECT department_id, id
    FROM public.buildings
    WHERE department_id IS NOT NULL
    ON CONFLICT (department_id, building_id) DO NOTHING;
  END IF;
END $$;

-- 5. Backfill teacher_users.department_id from teacher_users.department if department_id is null
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'teacher_users' 
      AND column_name = 'department'
  ) THEN
    UPDATE public.teacher_users tu
    SET department_id = d.id
    FROM public.departments d
    WHERE tu.department_id IS NULL 
      AND tu.department IS NOT NULL 
      AND LOWER(TRIM(d.name)) = LOWER(TRIM(tu.department));
  END IF;
END $$;

-- 6. Remove redundant departments.building_id (only after migration to junction table)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'departments' 
      AND column_name = 'building_id'
  ) THEN
    ALTER TABLE public.departments DROP CONSTRAINT IF EXISTS departments_building_id_fkey;
    DROP INDEX IF EXISTS public.idx_departments_building_id;
    ALTER TABLE public.departments DROP COLUMN IF EXISTS building_id CASCADE;
  END IF;
END $$;
