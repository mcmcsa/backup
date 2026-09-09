-- Remove deprecated buildings.code column.
-- Run in Supabase SQL Editor.
-- Safe to run repeatedly.

BEGIN;

-- 1. Drop index if exists
DROP INDEX IF EXISTS public.idx_buildings_code;

-- 2. Drop unique constraint if exists
ALTER TABLE public.buildings DROP CONSTRAINT IF EXISTS buildings_code_key;

-- 3. Drop the code column completely
ALTER TABLE public.buildings DROP COLUMN IF EXISTS code CASCADE;

COMMIT;
