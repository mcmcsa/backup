-- Migration: Drop department_id column from buildings table
-- Run this in your Supabase SQL Editor:
-- Architecture: Departments belong to Buildings (departments.building_id), NOT the other way around.

-- 1. Drop the foreign key constraint
ALTER TABLE IF EXISTS public.buildings 
  DROP CONSTRAINT IF EXISTS buildings_department_id_fkey;

-- 2. Drop index if exists
DROP INDEX IF EXISTS public.idx_buildings_department_id;

-- 3. Drop column department_id from buildings
ALTER TABLE IF EXISTS public.buildings 
  DROP COLUMN IF EXISTS department_id CASCADE;
