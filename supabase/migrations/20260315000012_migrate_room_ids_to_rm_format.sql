-- Migrate existing UUID-style room IDs to RM#### auto-increment format.
-- Steps:
--   1. Drop FK constraints that reference rooms(id) so we can update the PK.
--   2. Rename each UUID room to RM0001, RM0002, … in creation order.
--   3. Update every child-table row that referenced the old UUID.
--   4. Re-add FK constraints with the original ON DELETE behaviour.

-- ── 1. Drop FK constraints ────────────────────────────────────────────────────
ALTER TABLE work_requests   DROP CONSTRAINT IF EXISTS work_requests_room_id_fkey;
ALTER TABLE room_schedules  DROP CONSTRAINT IF EXISTS room_schedules_room_id_fkey;
ALTER TABLE qr_code_history DROP CONSTRAINT IF EXISTS qr_code_history_room_id_fkey;

-- ── 2 & 3. Rename UUIDs and update children ──────────────────────────────────
DO $$
DECLARE
  room_rec RECORD;
  new_id   TEXT;
  counter  INT := 1;
BEGIN
  -- Process only rooms whose id is NOT already RM#### format
  FOR room_rec IN
    SELECT id
    FROM   rooms
    WHERE  id !~ '^RM[0-9]+$'
    ORDER  BY created_at ASC
  LOOP
    -- Find the next free RM#### slot
    LOOP
      new_id := 'RM' || LPAD(counter::TEXT, 4, '0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM rooms WHERE id = new_id);
      counter := counter + 1;
    END LOOP;

    -- Update child tables that reference this room
    UPDATE work_requests   SET room_id = new_id WHERE room_id = room_rec.id;
    UPDATE room_schedules  SET room_id = new_id WHERE room_id = room_rec.id;
    UPDATE qr_code_history SET room_id = new_id WHERE room_id = room_rec.id;

    -- Update the room PK itself
    UPDATE rooms SET id = new_id WHERE id = room_rec.id;

    counter := counter + 1;
  END LOOP;
END $$;

-- ── 4. Re-add FK constraints ──────────────────────────────────────────────────
ALTER TABLE work_requests
  ADD CONSTRAINT work_requests_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL;

ALTER TABLE room_schedules
  ADD CONSTRAINT room_schedules_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE;

ALTER TABLE qr_code_history
  ADD CONSTRAINT qr_code_history_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE;
