-- Migration: Add profile_image and phone columns to users table
-- These columns are already used by auth_service.dart (updateProfile) and chat_service.dart.
-- This migration ensures the schema is consistent with what the app expects.
-- Safe to re-run (uses IF NOT EXISTS).

BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS profile_image TEXT,
  ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

COMMIT;
