-- Sync room status automatically when a work request is submitted, updated, or deleted.
-- SECURITY DEFINER is used to bypass RLS policies on the rooms table, allowing
-- teachers and technicians (who normally cannot edit rooms) to trigger status changes.

CREATE OR REPLACE FUNCTION public.sync_room_status_on_work_request()
RETURNS TRIGGER AS $$
DECLARE
  v_room_id TEXT;
  v_has_active BOOLEAN;
BEGIN
  -- Determine which room_id to check.
  IF TG_OP = 'DELETE' THEN
    v_room_id := OLD.room_id;
  ELSE
    v_room_id := NEW.room_id;
  END IF;

  -- If a room_id exists, recalculate its status based on active work requests
  IF v_room_id IS NOT NULL AND v_room_id <> '' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id = v_room_id
        AND LOWER(status) NOT IN ('completed', 'declined')
    ) INTO v_has_active;

    IF v_has_active THEN
      UPDATE public.rooms
      SET status = 'maintenance',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = v_room_id;
    ELSE
      UPDATE public.rooms
      SET status = 'available',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = v_room_id;
    END IF;
  END IF;

  -- If it's an UPDATE and the room_id itself changed, also update the old room
  IF TG_OP = 'UPDATE' AND OLD.room_id IS NOT NULL AND OLD.room_id <> '' AND OLD.room_id <> NEW.room_id THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id = OLD.room_id
        AND LOWER(status) NOT IN ('completed', 'declined')
    ) INTO v_has_active;

    IF v_has_active THEN
      UPDATE public.rooms
      SET status = 'maintenance',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = OLD.room_id;
    ELSE
      UPDATE public.rooms
      SET status = 'available',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = OLD.room_id;
    END IF;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on work_requests table
DROP TRIGGER IF EXISTS trigger_sync_room_status ON public.work_requests;
CREATE TRIGGER trigger_sync_room_status
AFTER INSERT OR UPDATE OR DELETE ON public.work_requests
FOR EACH ROW
EXECUTE FUNCTION public.sync_room_status_on_work_request();

-- One-time synchronization of all existing rooms based on active work requests
UPDATE public.rooms r
SET status = CASE 
  WHEN EXISTS (
    SELECT 1 FROM public.work_requests wr
    WHERE wr.room_id = r.id
      AND LOWER(wr.status) NOT IN ('completed', 'declined')
  ) THEN 'maintenance'::text
  ELSE 'available'::text
END;
