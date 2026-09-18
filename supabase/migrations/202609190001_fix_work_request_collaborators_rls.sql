-- Migration: Fix Row-Level Security policies on work_request_collaborators and work_request_costs for campadmin
-- Date: 2026-09-19

-- 1. Update work_request_collaborators policies
DROP POLICY IF EXISTS "Enable insert for admins" ON public.work_request_collaborators;
DROP POLICY IF EXISTS "Enable delete for admins" ON public.work_request_collaborators;

CREATE POLICY "Enable insert for admins" 
ON public.work_request_collaborators FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

CREATE POLICY "Enable delete for admins" 
ON public.work_request_collaborators FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

-- 2. Update work_request_costs policies
DROP POLICY IF EXISTS "Enable insert for admins" ON public.work_request_costs;
DROP POLICY IF EXISTS "Enable update for admins" ON public.work_request_costs;
DROP POLICY IF EXISTS "Enable delete for admins" ON public.work_request_costs;

CREATE POLICY "Enable insert for admins" 
ON public.work_request_costs FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

CREATE POLICY "Enable update for admins" 
ON public.work_request_costs FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

CREATE POLICY "Enable delete for admins" 
ON public.work_request_costs FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

-- 3. Update storage policies for cost_receipts bucket
DROP POLICY IF EXISTS "Admin Upload Access" ON storage.objects;
DROP POLICY IF EXISTS "Admin Update Access" ON storage.objects;
DROP POLICY IF EXISTS "Admin Delete Access" ON storage.objects;

CREATE POLICY "Admin Upload Access" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (
  bucket_id = 'cost_receipts' AND 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

CREATE POLICY "Admin Update Access" 
ON storage.objects FOR UPDATE 
TO authenticated 
USING (
  bucket_id = 'cost_receipts' AND 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);

CREATE POLICY "Admin Delete Access" 
ON storage.objects FOR DELETE 
TO authenticated 
USING (
  bucket_id = 'cost_receipts' AND 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role IN ('system_admin', 'admin', 'campadmin'))
  )
);
