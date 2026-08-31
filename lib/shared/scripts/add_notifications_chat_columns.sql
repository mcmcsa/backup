-- SQL Script to update app_notifications schema
-- Run this in your Supabase SQL Editor.

ALTER TABLE public.app_notifications 
ADD COLUMN IF NOT EXISTS chat_room_id uuid REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS target_page text;
