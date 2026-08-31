-- SQL Script to add the missing column reply_to_sender_name to the chat_messages table.
-- Run this in your Supabase SQL Editor to resolve the schema cache mismatch error.

ALTER TABLE public.chat_messages 
ADD COLUMN IF NOT EXISTS reply_to_sender_name text;
