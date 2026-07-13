-- 1. Collaborators Table
CREATE TABLE IF NOT EXISTS public.work_request_collaborators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.maintenance_users(user_id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('primary', 'secondary')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'removed')),
    invited_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    responded_at TIMESTAMPTZ,
    CONSTRAINT unique_collaborator UNIQUE(work_request_id, user_id)
);

ALTER TABLE public.work_request_collaborators ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for collaborators" 
ON public.work_request_collaborators FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Enable insert for admins" 
ON public.work_request_collaborators FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);

CREATE POLICY "Enable update for all authenticated" 
ON public.work_request_collaborators FOR UPDATE 
TO authenticated 
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable delete for admins" 
ON public.work_request_collaborators FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);


-- 2. Shared Task Checklist
CREATE TABLE IF NOT EXISTS public.work_request_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
    task_description TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT false NOT NULL,
    completed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at TIMESTAMPTZ
);

ALTER TABLE public.work_request_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for authenticated users" 
ON public.work_request_tasks FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);


-- 3. Shared Notes / Attachments
CREATE TABLE IF NOT EXISTS public.work_request_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    attachment_urls TEXT[],
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.work_request_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all for authenticated users" 
ON public.work_request_notes FOR ALL 
TO authenticated 
USING (true) 
WITH CHECK (true);


-- 4. Activity Timeline
CREATE TABLE IF NOT EXISTS public.work_request_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    details TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.work_request_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read for authenticated users" 
ON public.work_request_activities FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Enable insert for authenticated users" 
ON public.work_request_activities FOR INSERT 
TO authenticated 
WITH CHECK (true);
