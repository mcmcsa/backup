-- Convert rooms.id from TEXT room code to UUID, while preserving business room code in rooms.code.
-- This migration is written to be safe for existing environments and idempotent where practical.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ensure code remains the human-friendly identifier.
ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS code VARCHAR(50);

UPDATE public.rooms
SET code = id
WHERE (code IS NULL OR btrim(code) = '')
  AND id IS NOT NULL;

ALTER TABLE public.rooms
  ALTER COLUMN code SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_rooms_code ON public.rooms(code);

-- Create a new UUID identifier column for rooms.
ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS id_uuid UUID DEFAULT gen_random_uuid();

UPDATE public.rooms
SET id_uuid = gen_random_uuid()
WHERE id_uuid IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_rooms_id_uuid ON public.rooms(id_uuid);

-- Add UUID foreign key columns on dependent tables.
ALTER TABLE public.qr_code_history ADD COLUMN IF NOT EXISTS room_id_uuid UUID;
ALTER TABLE public.work_requests ADD COLUMN IF NOT EXISTS room_id_uuid UUID;

-- Backfill UUID references from existing text room IDs.
UPDATE public.qr_code_history qh
SET room_id_uuid = r.id_uuid
FROM public.rooms r
WHERE qh.room_id IS NOT NULL
  AND qh.room_id_uuid IS NULL
  AND qh.room_id = r.id;

UPDATE public.work_requests wr
SET room_id_uuid = r.id_uuid
FROM public.rooms r
WHERE wr.room_id IS NOT NULL
  AND wr.room_id_uuid IS NULL
  AND wr.room_id = r.id;

-- Drop old foreign keys pointing to rooms(id text).
DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT tc.table_schema, tc.table_name, tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
     AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_schema = 'public'
      AND ccu.table_name = 'rooms'
      AND ccu.column_name = 'id'
      AND tc.table_name IN ('room_schedules', 'qr_code_history', 'work_requests')
      AND kcu.column_name = 'room_id'
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I',
      rec.table_schema,
      rec.table_name,
      rec.constraint_name
    );
  END LOOP;
END $$;

-- Add new foreign keys to rooms.id_uuid.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'qr_code_history_room_id_uuid_fkey'
  ) THEN
    ALTER TABLE public.qr_code_history
      ADD CONSTRAINT qr_code_history_room_id_uuid_fkey
      FOREIGN KEY (room_id_uuid) REFERENCES public.rooms(id_uuid) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'work_requests_room_id_uuid_fkey'
  ) THEN
    ALTER TABLE public.work_requests
      ADD CONSTRAINT work_requests_room_id_uuid_fkey
      FOREIGN KEY (room_id_uuid) REFERENCES public.rooms(id_uuid) ON DELETE SET NULL;
  END IF;
END $$;

-- Swap dependent columns to keep the same room_id API surface.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'qr_code_history' AND column_name = 'room_id_uuid'
  ) THEN
    ALTER TABLE public.qr_code_history DROP COLUMN IF EXISTS room_id;
    ALTER TABLE public.qr_code_history RENAME COLUMN room_id_uuid TO room_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'work_requests' AND column_name = 'room_id_uuid'
  ) THEN
    ALTER TABLE public.work_requests DROP COLUMN IF EXISTS room_id;
    ALTER TABLE public.work_requests RENAME COLUMN room_id_uuid TO room_id;
  END IF;
END $$;

-- Convert rooms.id to UUID and keep legacy text value only in code.
DO $$
DECLARE
  pk_name TEXT;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rooms' AND column_name = 'id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'rooms' AND column_name = 'id_uuid'
  ) THEN
    SELECT tc.constraint_name
      INTO pk_name
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'rooms'
      AND tc.constraint_type = 'PRIMARY KEY';

    IF pk_name IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.rooms DROP CONSTRAINT IF EXISTS %I', pk_name);
    END IF;

    ALTER TABLE public.rooms DROP COLUMN IF EXISTS id;
    ALTER TABLE public.rooms RENAME COLUMN id_uuid TO id;
    ALTER TABLE public.rooms ADD PRIMARY KEY (id);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_qr_code_history_room_id ON public.qr_code_history(room_id);
CREATE INDEX IF NOT EXISTS idx_work_requests_room_id ON public.work_requests(room_id);
