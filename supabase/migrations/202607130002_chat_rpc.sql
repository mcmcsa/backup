-- Stored function: find an existing direct chat room shared by exactly two users
CREATE OR REPLACE FUNCTION find_direct_chat_room(user_a uuid, user_b uuid)
RETURNS TABLE(id uuid) AS $$
  SELECT r.id
  FROM chat_rooms r
  WHERE r.type = 'direct'
    AND (
      SELECT COUNT(*) FROM chat_participants cp WHERE cp.room_id = r.id
    ) = 2
    AND EXISTS (SELECT 1 FROM chat_participants cp WHERE cp.room_id = r.id AND cp.user_id = user_a)
    AND EXISTS (SELECT 1 FROM chat_participants cp WHERE cp.room_id = r.id AND cp.user_id = user_b)
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;
