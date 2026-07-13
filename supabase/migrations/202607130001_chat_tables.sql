-- ============================================================
-- Chat System Tables
-- Created: 2026-07-13
-- ============================================================

-- 1. Chat Rooms (conversations)
CREATE TABLE IF NOT EXISTS chat_rooms (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text,                               -- NULL for DM, set for groups
  type            text NOT NULL DEFAULT 'direct'
                    CHECK (type IN ('direct', 'group')),
  work_request_id uuid REFERENCES work_requests(id) ON DELETE SET NULL,
  created_by      uuid REFERENCES users(id) ON DELETE SET NULL,
  last_message    text,
  last_message_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- 2. Chat Participants
CREATE TABLE IF NOT EXISTS chat_participants (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role         text NOT NULL DEFAULT 'teacher',
  joined_at    timestamptz NOT NULL DEFAULT now(),
  last_read_at timestamptz,
  UNIQUE(room_id, user_id)
);

-- 3. Chat Messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id          uuid NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_name      text NOT NULL,
  sender_role      text NOT NULL DEFAULT 'teacher',
  content          text,
  message_type     text NOT NULL DEFAULT 'text'
                     CHECK (message_type IN ('text', 'image', 'voice', 'file', 'system')),
  attachment_url   text,
  attachment_name  text,
  reply_to_id      uuid REFERENCES chat_messages(id) ON DELETE SET NULL,
  reply_to_content text,
  is_forwarded     boolean NOT NULL DEFAULT false,
  is_pinned        boolean NOT NULL DEFAULT false,
  is_deleted       boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- 4. Typing Indicators (lightweight, no FK constraints needed)
CREATE TABLE IF NOT EXISTS chat_typing (
  room_id    uuid NOT NULL,
  user_id    uuid NOT NULL,
  user_name  text NOT NULL DEFAULT '',
  is_typing  boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_participants_room   ON chat_participants(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user   ON chat_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room       ON chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created    ON chat_messages(room_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_updated       ON chat_rooms(updated_at DESC);

-- Enable RLS
ALTER TABLE chat_rooms        ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_typing        ENABLE ROW LEVEL SECURITY;

-- RLS: chat_rooms - visible to participants
CREATE POLICY "Participants can view rooms" ON chat_rooms
  FOR SELECT USING (
    id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid())
  );

CREATE POLICY "Authenticated can create rooms" ON chat_rooms
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Participants can update room" ON chat_rooms
  FOR UPDATE TO authenticated USING (
    id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid())
  );

-- RLS: chat_participants
CREATE POLICY "Users can view participants in their rooms" ON chat_participants
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM chat_participants cp WHERE cp.user_id = auth.uid())
  );

CREATE POLICY "Authenticated can join rooms" ON chat_participants
  FOR INSERT TO authenticated WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own participation" ON chat_participants
  FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- RLS: chat_messages
CREATE POLICY "Participants can view messages" ON chat_messages
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid())
  );

CREATE POLICY "Participants can send messages" ON chat_messages
  FOR INSERT TO authenticated WITH CHECK (
    sender_id = auth.uid() AND
    room_id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid())
  );

CREATE POLICY "Sender can update their message" ON chat_messages
  FOR UPDATE TO authenticated USING (sender_id = auth.uid());

-- RLS: chat_typing
CREATE POLICY "Participants can view typing" ON chat_typing
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid())
  );

CREATE POLICY "Authenticated can upsert typing" ON chat_typing
  FOR ALL TO authenticated USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Storage bucket for chat attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-attachments',
  'chat-attachments',
  true,
  52428800, -- 50MB limit
  ARRAY['image/jpeg','image/png','image/gif','image/webp','audio/aac','audio/mpeg','audio/m4a','audio/mp4','audio/webm','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','text/plain']
) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public can view chat attachments" ON storage.objects
  FOR SELECT USING (bucket_id = 'chat-attachments');

CREATE POLICY "Authenticated can upload chat attachments" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat-attachments');

CREATE POLICY "Owners can delete chat attachments" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'chat-attachments' AND owner = auth.uid());

-- Enable Realtime for live messaging
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_typing;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_rooms;
