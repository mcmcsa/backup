-- PostgreSQL Script to fix infinite recursion in chat_participants RLS policies
-- Execute this script in your Supabase SQL Editor.
-- It moves the room participation check into a SECURITY DEFINER function to bypass RLS recursion.

-- 1. Helper function (runs with definer security to bypass policy triggers)
CREATE OR REPLACE FUNCTION public.check_user_in_chat_room(target_room_id uuid, target_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.chat_participants 
    WHERE chat_participants.room_id = target_room_id 
      AND chat_participants.user_id = target_user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop existing recursive policies
DROP POLICY IF EXISTS "Users can view participants in their rooms" ON public.chat_participants;
DROP POLICY IF EXISTS "Participants can view rooms" ON public.chat_rooms;
DROP POLICY IF EXISTS "Participants can update room" ON public.chat_rooms;
DROP POLICY IF EXISTS "Participants can view messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Participants can send messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Participants can view typing" ON public.chat_typing;

-- 3. Re-create policies using the SECURITY DEFINER check
CREATE POLICY "Users can view participants in their rooms" ON public.chat_participants
  FOR SELECT USING (
    public.check_user_in_chat_room(room_id, auth.uid())
  );

CREATE POLICY "Participants can view rooms" ON public.chat_rooms
  FOR SELECT USING (
    public.check_user_in_chat_room(id, auth.uid())
  );

CREATE POLICY "Participants can update room" ON public.chat_rooms
  FOR UPDATE TO authenticated USING (
    public.check_user_in_chat_room(id, auth.uid())
  );

CREATE POLICY "Participants can view messages" ON public.chat_messages
  FOR SELECT USING (
    public.check_user_in_chat_room(room_id, auth.uid())
  );

CREATE POLICY "Participants can send messages" ON public.chat_messages
  FOR INSERT TO authenticated WITH CHECK (
    sender_id = auth.uid() AND
    public.check_user_in_chat_room(room_id, auth.uid())
  );

CREATE POLICY "Participants can view typing" ON public.chat_typing
  FOR SELECT USING (
    public.check_user_in_chat_room(room_id, auth.uid())
  );
