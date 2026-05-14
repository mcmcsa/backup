-- Remove deprecated floors.code column.
-- Safe to run repeatedly.

BEGIN;

ALTER TABLE public.floors DROP COLUMN IF EXISTS code CASCADE;

COMMIT;
