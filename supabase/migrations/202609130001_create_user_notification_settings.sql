-- Migration: Create user_notification_settings table
-- Date: 2026-09-13
-- Purpose: Persist per-user notification preferences (master switch, email, push) across all user roles

CREATE TABLE IF NOT EXISTS public.user_notification_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    email_notifications BOOLEAN NOT NULL DEFAULT false,
    push_notifications BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast user lookup
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id 
ON public.user_notification_settings(user_id);

-- Enable Row Level Security
ALTER TABLE public.user_notification_settings ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view settings (needed so senders can check recipient's push/email preferences)
DROP POLICY IF EXISTS "Authenticated users can view notification settings" ON public.user_notification_settings;
CREATE POLICY "Authenticated users can view notification settings"
ON public.user_notification_settings
FOR SELECT
TO authenticated
USING (true);

-- Allow users to insert/update their own notification settings
DROP POLICY IF EXISTS "Users can manage their own notification settings" ON public.user_notification_settings;
CREATE POLICY "Users can manage their own notification settings"
ON public.user_notification_settings
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access on user_notification_settings" ON public.user_notification_settings;
CREATE POLICY "Service role full access on user_notification_settings"
ON public.user_notification_settings
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
