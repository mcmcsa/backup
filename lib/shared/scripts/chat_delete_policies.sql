-- Run this in Supabase SQL Editor if you want database-level delete permissions:
-- Enables users to delete conversations they participate in

DROP POLICY IF EXISTS "Participants can delete rooms" ON public.chat_rooms;
CREATE POLICY "Participants can delete rooms" ON public.chat_rooms
  FOR DELETE TO authenticated
  USING (
    id IN (SELECT room_id FROM public.chat_participants WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Users can leave rooms" ON public.chat_participants;
CREATE POLICY "Users can leave rooms" ON public.chat_participants
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
