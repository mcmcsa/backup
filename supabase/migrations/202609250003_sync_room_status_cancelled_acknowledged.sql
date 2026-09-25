-- Migration: 202609250003_sync_room_status_cancelled_acknowledged.sql
-- Description: Update sync_room_status_on_work_request trigger function to treat
-- 'cancelled' and 'acknowledged' as terminal states so room status returns to available
-- when a request is cancelled by requestor or acknowledged by Department Head.

CREATE OR REPLACE FUNCTION public.sync_room_status_on_work_request()
RETURNS TRIGGER AS $$
DECLARE
  v_room_id UUID;
  v_has_active BOOLEAN;
BEGIN
  -- Determine which room_id to check.
  IF TG_OP = 'DELETE' THEN
    v_room_id := OLD.room_id::uuid;
  ELSE
    v_room_id := NEW.room_id::uuid;
  END IF;

  -- If a room_id exists, recalculate its status based on active work requests
  IF v_room_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id::uuid = v_room_id
        AND LOWER(status) NOT IN ('completed', 'declined', 'cancelled', 'acknowledged')
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
  IF TG_OP = 'UPDATE'
     AND OLD.room_id IS NOT NULL
     AND OLD.room_id <> ''
     AND OLD.room_id <> NEW.room_id
  THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id::uuid = OLD.room_id::uuid
        AND LOWER(status) NOT IN ('completed', 'declined', 'cancelled', 'acknowledged')
    ) INTO v_has_active;

    IF v_has_active THEN
      UPDATE public.rooms
      SET status = 'maintenance',
          updated_at = CURRENT_TIMESTAMP
      WHERE id = OLD.room_id::uuid;
    ELSE
      UPDATE public.rooms
      SET status = 'available',
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

-- Re-create trigger
DROP TRIGGER IF EXISTS trigger_sync_room_status ON public.work_requests;
CREATE TRIGGER trigger_sync_room_status
AFTER INSERT OR UPDATE OR DELETE ON public.work_requests
FOR EACH ROW
EXECUTE FUNCTION public.sync_room_status_on_work_request();
