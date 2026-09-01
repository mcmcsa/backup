CREATE OR REPLACE FUNCTION public.sync_room_status_on_work_request()
RETURNS TRIGGER AS $$
DECLARE
  v_room_id UUID;
  v_has_active BOOLEAN;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_room_id := OLD.room_id::uuid;
  ELSE
    v_room_id := NEW.room_id::uuid;
  END IF;
  IF v_room_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id::uuid = v_room_id
        AND LOWER(status) NOT IN ('completed', 'declined')
    ) INTO v_has_active;
    IF v_has_active THEN
      UPDATE public.rooms SET status = 'maintenance', updated_at = CURRENT_TIMESTAMP WHERE id = v_room_id;
    ELSE
      UPDATE public.rooms SET status = 'available', updated_at = CURRENT_TIMESTAMP WHERE id = v_room_id;
    END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.room_id IS NOT NULL AND OLD.room_id <> '' AND OLD.room_id <> NEW.room_id THEN
    SELECT EXISTS (
      SELECT 1 FROM public.work_requests
      WHERE room_id::uuid = OLD.room_id::uuid
        AND LOWER(status) NOT IN ('completed', 'declined')
    ) INTO v_has_active;
    IF v_has_active THEN
      UPDATE public.rooms SET status = 'maintenance', updated_at = CURRENT_TIMESTAMP WHERE id = OLD.room_id::uuid;
    ELSE
      UPDATE public.rooms SET status = 'available', updated_at = CURRENT_TIMESTAMP WHERE id = OLD.room_id::uuid;
    END IF;
  END IF;
  RETURN NULL;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_sync_room_status ON public.work_requests;
CREATE TRIGGER trigger_sync_room_status
AFTER INSERT OR UPDATE OR DELETE ON public.work_requests
FOR EACH ROW
EXECUTE FUNCTION public.sync_room_status_on_work_request();
