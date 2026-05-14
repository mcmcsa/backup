-- Ensure legacy environments have all columns used by the mobile/web room flows.

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS code VARCHAR(50);
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS department_snapshot VARCHAR(150);
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS floor_id UUID;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS floor_snapshot VARCHAR(50);
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS room_type_id UUID;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS image_url VARCHAR(500);
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS qr_code_data TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'available';

-- Backfill code where absent to keep old rows compatible with app assumptions.
UPDATE public.rooms
SET code = id
WHERE (code IS NULL OR btrim(code) = '')
  AND id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_rooms_floor_id'
  ) THEN
    ALTER TABLE public.rooms
      ADD CONSTRAINT fk_rooms_floor_id
      FOREIGN KEY (floor_id) REFERENCES public.floors(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_rooms_room_type_id'
  ) THEN
    ALTER TABLE public.rooms
      ADD CONSTRAINT fk_rooms_room_type_id
      FOREIGN KEY (room_type_id) REFERENCES public.room_types(id) ON DELETE SET NULL;
  END IF;
END $$;
