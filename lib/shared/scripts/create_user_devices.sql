-- SQL Script: Run this in Supabase SQL Editor to enable FCM Device Token storage
-- Project: PSU E-ayos

CREATE TABLE IF NOT EXISTS public.user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_platform UNIQUE (user_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_fcm_token ON public.user_devices(fcm_token);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own device tokens" ON public.user_devices;
CREATE POLICY "Users can manage their own device tokens"
ON public.user_devices
FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role full access on user_devices" ON public.user_devices;
CREATE POLICY "Service role full access on user_devices"
ON public.user_devices
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
