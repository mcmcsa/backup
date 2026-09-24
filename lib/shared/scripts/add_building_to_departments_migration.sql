-- Migration: Connect Departments to Buildings
-- 1. Add building_id column to public.departments
ALTER TABLE public.departments
  ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL;

-- 2. Create index for fast lookups of departments by building
CREATE INDEX IF NOT EXISTS idx_departments_building_id ON public.departments(building_id);

-- 3. Reverse-link existing relationships if buildings previously had department_id
UPDATE public.departments d
SET building_id = b.id
FROM public.buildings b
WHERE b.department_id = d.id AND d.building_id IS NULL;
