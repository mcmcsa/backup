-- Fix: operator does not exist: uuid = text (code: 42883)
-- The sync_room_status_on_work_request trigger function declared v_room_id as TEXT,
-- but rooms.id is UUID. PostgreSQL will not implicitly cast TEXT -> UUID in equality
-- comparisons, so every INSERT/UPDATE on work_requests threw this error and prevented
-- teachers from submitting work requests.
--
-- Fix: cast work_requests.room_id to UUID when assigning / comparing against rooms.id.

CREATE OR REPLACE FUNCTION public.sync_room_status_on_work_request()
RETURNS TRIGGER AS $$
DECLARE
  v_room_id UUID;   -- was TEXT, changed to UUID to match rooms.id type
  v_has_active BOOLEAN;
BEGIN
  -- Determine which room_id to check.
  -- work_requests.room_id may be stored as TEXT (UUID string), so cast explicitly.
  IF TG_OP = ''DELETE'' THEN
    v_room_id := OLD.room_id::uuid;
  ELSE
    v_room_id := NEW.room_id::uuid;
  END IF;

  -- If a room_id exists, recalculate its status based on active work requests
  IF v_room_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id::uuid = v_room_id
        AND LOWER(status) NOT IN (''completed'', ''declined'')
    ) INTO v_has_active;

    IF v_has_active THEN
      UPDATE public.rooms
      SET status = ''maintenance'',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = v_room_id;
    ELSE
      UPDATE public.rooms
      SET status = ''available'',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = v_room_id;
    END IF;
  END IF;

  -- If it''s an UPDATE and the room_id itself changed, also update the old room
  IF TG_OP = ''UPDATE''
     AND OLD.room_id IS NOT NULL
     AND OLD.room_id <> ''''
     AND OLD.room_id <> NEW.room_id
  THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id::uuid = OLD.room_id::uuid
        AND LOWER(status) NOT IN (''completed'', ''declined'')
    ) INTO v_has_active;

    IF v_has_active THEN
      UPDATE public.rooms
      SET status = ''maintenance'',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = OLD.room_id::uuid;
    ELSE
      UPDATE public.rooms
      SET status = ''available'',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = OLD.room_id::uuid;
    END IF;
  END IF;

  RETURN NULL;
EXCEPTION
  WHEN invalid_text_representation THEN
    -- room_id is not a valid UUID string; skip room status sync silently
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create the trigger (function signature unchanged, so this is a no-op on the trigger itself)
DROP TRIGGER IF EXISTS trigger_sync_room_status ON public.work_requests;
CREATE TRIGGER trigger_sync_room_status
AFTER INSERT OR UPDATE OR DELETE ON public.work_requests
FOR EACH ROW
EXECUTE FUNCTION public.sync_room_status_on_work_request();
