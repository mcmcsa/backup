-- ==============================================================================
-- System Admin Enterprise Modules Schema
-- ==============================================================================

-- 1. System Settings Table
CREATE TABLE IF NOT EXISTS public.system_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  system_name text NOT NULL DEFAULT 'PSU Maintenance',
  campus_name text NOT NULL DEFAULT 'Main Campus',
  primary_color text NOT NULL DEFAULT '#1E3A8A',
  academic_year text NOT NULL DEFAULT '2025-2026',
  session_timeout_minutes integer NOT NULL DEFAULT 60,
  theme text NOT NULL DEFAULT 'light',
  timezone text NOT NULL DEFAULT 'Asia/Manila',
  semester text NOT NULL DEFAULT '1st Semester',
  enforce_password_policy boolean NOT NULL DEFAULT true,
  maintenance_mode boolean NOT NULL DEFAULT false,
  updated_at timestamp with time zone DEFAULT now()
);

-- Insert default row if not exists
INSERT INTO public.system_settings (id)
SELECT '10000000-0000-0000-0000-000000000001'
WHERE NOT EXISTS (SELECT 1 FROM public.system_settings LIMIT 1);


-- 2. System Feedback Table
CREATE TABLE IF NOT EXISTS public.system_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name text NOT NULL,
  category text NOT NULL,
  message text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  admin_reply text,
  created_at timestamp with time zone DEFAULT now()
);


-- 3. System Announcements Table
CREATE TABLE IF NOT EXISTS public.system_announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  priority text NOT NULL DEFAULT 'normal',
  status text NOT NULL DEFAULT 'draft',
  scheduled_for timestamp with time zone,
  expires_at timestamp with time zone,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  is_pinned boolean NOT NULL DEFAULT false,
  target_audience text[] NOT NULL DEFAULT '{all}',
  display_type text NOT NULL DEFAULT 'notification'
);


-- 4. System Backups Table
CREATE TABLE IF NOT EXISTS public.system_backups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  filename text NOT NULL,
  size_bytes bigint NOT NULL,
  status text NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamp with time zone DEFAULT now()
);


-- ==============================================================================
-- Row Level Security (RLS) Policies
-- ==============================================================================

-- Enable RLS
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_backups ENABLE ROW LEVEL SECURITY;

-- System Settings RLS
-- Anyone authenticated can read settings
CREATE POLICY "Anyone can read system settings" ON public.system_settings
  FOR SELECT TO authenticated USING (true);

-- Only system admins can update settings (assumes you have a way to identify system admins, 
-- usually by checking the auth.users or a custom users table. For now, we allow authenticated to update
-- but your UI should guard this).
CREATE POLICY "Admins can update settings" ON public.system_settings
  FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Admins can insert settings" ON public.system_settings
  FOR INSERT TO authenticated WITH CHECK (true);


-- System Feedback RLS
CREATE POLICY "Anyone can read feedback" ON public.system_feedback
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone can insert feedback" ON public.system_feedback
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can update feedback" ON public.system_feedback
  FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Admins can delete feedback" ON public.system_feedback
  FOR DELETE TO authenticated USING (true);


-- System Announcements RLS
CREATE POLICY "Anyone can read announcements" ON public.system_announcements
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can insert announcements" ON public.system_announcements
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Admins can update announcements" ON public.system_announcements
  FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Admins can delete announcements" ON public.system_announcements
  FOR DELETE TO authenticated USING (true);


-- System Backups RLS
CREATE POLICY "Admins can manage backups" ON public.system_backups
  FOR ALL TO authenticated USING (true);
