-- Migration: Allow authenticated users to insert app_notifications
-- Date: 2026-08-31
-- Reason: The previous INSERT policy only allowed admins to insert notifications.
-- Maintenance technicians need to notify admins when submitting post-repair reports.
-- Any authenticated user can insert a notification; the SELECT policy restricts reads.

DROP POLICY IF EXISTS app_notifications_insert_policy ON public.app_notifications;
CREATE POLICY app_notifications_insert_policy ON public.app_notifications
FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);
