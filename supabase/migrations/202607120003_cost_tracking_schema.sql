-- Create the work_request_costs table
CREATE TABLE IF NOT EXISTS public.work_request_costs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_request_id UUID NOT NULL REFERENCES public.work_requests(id) ON DELETE CASCADE,
    estimated_labor_cost NUMERIC(12, 2) DEFAULT 0.00,
    estimated_material_cost NUMERIC(12, 2) DEFAULT 0.00,
    actual_labor_cost NUMERIC(12, 2) DEFAULT 0.00,
    actual_material_cost NUMERIC(12, 2) DEFAULT 0.00,
    additional_expenses NUMERIC(12, 2) DEFAULT 0.00,
    total_cost NUMERIC(12, 2) GENERATED ALWAYS AS (actual_labor_cost + actual_material_cost + additional_expenses) STORED,
    budget_source TEXT,
    purchase_reference_number TEXT,
    receipt_attachment_url TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_work_request_cost UNIQUE(work_request_id)
);

-- Enable RLS
ALTER TABLE public.work_request_costs ENABLE ROW LEVEL SECURITY;

-- Read policies: Accessible by admins, system_admin, and maybe the requester if needed (but requirement says only admins edit, let's keep reads open to authenticated users for now so it can be seen in dashboard/details if needed, but restrict strictly later if required). We will allow authenticated users to view costs.
CREATE POLICY "Enable read access for authenticated users" 
ON public.work_request_costs FOR SELECT 
TO authenticated 
USING (true);

-- Insert/Update policies: Only system_admin and campus_admin (role 'admin') can insert/update.
CREATE POLICY "Enable insert for admins" 
ON public.work_request_costs FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);

CREATE POLICY "Enable update for admins" 
ON public.work_request_costs FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);

CREATE POLICY "Enable delete for admins" 
ON public.work_request_costs FOR DELETE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);

-- Add update trigger for updated_at
CREATE OR REPLACE FUNCTION update_cost_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.work_request_costs
  FOR EACH ROW EXECUTE PROCEDURE update_cost_updated_at_column();

-- Create a storage bucket for cost receipts if it doesn't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('cost_receipts', 'cost_receipts', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for the bucket
-- Allow public viewing of receipts
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'cost_receipts' );

-- Allow admins to upload receipts
CREATE POLICY "Admin Upload Access" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (
  bucket_id = 'cost_receipts' AND 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);

-- Allow admins to delete/update receipts
CREATE POLICY "Admin Update Access" 
ON storage.objects FOR UPDATE 
TO authenticated 
USING (
  bucket_id = 'cost_receipts' AND 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
    AND (users.role = 'system_admin' OR users.role = 'admin')
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
    AND (users.role = 'system_admin' OR users.role = 'admin')
  )
);
