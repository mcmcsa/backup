-- PostgreSQL Trigger to automate Room Status transitions based on Work Requests
-- This script should be executed in the Supabase SQL Editor.
-- It bypasses client-side RLS limitations by using SECURITY DEFINER.

CREATE OR REPLACE FUNCTION public.handle_work_request_room_status()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. When a new work request is inserted (reported), set room status to 'maintenance' (Unavailable)
  IF TG_OP = 'INSERT' THEN
    IF NEW.room_id IS NOT NULL THEN
      UPDATE public.rooms
      SET status = 'maintenance'
      WHERE id = NEW.room_id;
    END IF;
  
  -- 2. When a work request is updated (e.g. status changes)
  ELSIF TG_OP = 'UPDATE' THEN
    -- If status changes to 'completed', set room status back to 'available'
    IF NEW.status = 'completed' AND OLD.status <> 'completed' THEN
      IF NEW.room_id IS NOT NULL THEN
        UPDATE public.rooms
        SET status = 'available'
        WHERE id = NEW.room_id;
      END IF;
    -- If status changes from 'completed' back to ongoing/rework, set room status to 'maintenance'
    ELSIF NEW.status <> 'completed' AND OLD.status = 'completed' THEN
      IF NEW.room_id IS NOT NULL THEN
        UPDATE public.rooms
        SET status = 'maintenance'
        WHERE id = NEW.room_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists to avoid duplication
DROP TRIGGER IF EXISTS on_work_request_room_status ON public.work_requests;

-- Create the trigger on work_requests table
CREATE TRIGGER on_work_request_room_status
  AFTER INSERT OR UPDATE ON public.work_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_work_request_room_status();
