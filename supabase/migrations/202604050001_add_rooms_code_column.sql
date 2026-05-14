-- Add missing rooms.code column for environments that were created before code existed.

ALTER TABLE public.rooms
ADD COLUMN IF NOT EXISTS code VARCHAR(50);

-- Backfill code using id for existing records.
UPDATE public.rooms
SET code = id
WHERE code IS NULL OR btrim(code) = '';

-- Enforce not-null after backfill.
ALTER TABLE public.rooms
ALTER COLUMN code SET NOT NULL;

-- Keep uniqueness aligned with app expectations.
CREATE UNIQUE INDEX IF NOT EXISTS idx_rooms_code ON public.rooms(code);
