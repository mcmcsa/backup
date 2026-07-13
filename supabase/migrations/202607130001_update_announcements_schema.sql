-- Update system_announcements table to support internal announcements features

ALTER TABLE public.system_announcements
ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS target_audience text[] NOT NULL DEFAULT '{all}',
ADD COLUMN IF NOT EXISTS display_type text NOT NULL DEFAULT 'notification';

-- Allow RLS for the system_announcements table if not already enabled
ALTER TABLE public.system_announcements ENABLE ROW LEVEL SECURITY;

-- Policies for system_announcements
-- Anyone authenticated can view published announcements
DROP POLICY IF EXISTS "View published announcements" ON public.system_announcements;
CREATE POLICY "View published announcements" ON public.system_announcements
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        status = 'published' AND
        (expires_at IS NULL OR expires_at > now()) AND
        (scheduled_for IS NULL OR scheduled_for <= now())
    );

-- Admins can view all announcements
DROP POLICY IF EXISTS "Admins can view all announcements" ON public.system_announcements;
CREATE POLICY "Admins can view all announcements" ON public.system_announcements
    FOR SELECT USING (
        auth.jwt() ->> 'role' IN ('system_admin', 'campus_admin')
    );

-- Admins can insert/update/delete announcements
DROP POLICY IF EXISTS "Admins can insert announcements" ON public.system_announcements;
CREATE POLICY "Admins can insert announcements" ON public.system_announcements
    FOR INSERT WITH CHECK (
        auth.jwt() ->> 'role' IN ('system_admin', 'campus_admin')
    );

DROP POLICY IF EXISTS "Admins can update announcements" ON public.system_announcements;
CREATE POLICY "Admins can update announcements" ON public.system_announcements
    FOR UPDATE USING (
        auth.jwt() ->> 'role' IN ('system_admin', 'campus_admin')
    );

DROP POLICY IF EXISTS "Admins can delete announcements" ON public.system_announcements;
CREATE POLICY "Admins can delete announcements" ON public.system_announcements
    FOR DELETE USING (
        auth.jwt() ->> 'role' IN ('system_admin', 'campus_admin')
    );
