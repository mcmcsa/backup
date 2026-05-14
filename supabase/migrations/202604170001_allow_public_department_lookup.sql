-- Expose department names for pre-login registration screens.
-- This keeps full table RLS in place while allowing controlled read access.

CREATE OR REPLACE FUNCTION public.get_departments_public()
RETURNS TABLE (id uuid, name text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT d.id, d.name
  FROM public.departments d
  ORDER BY d.name ASC;
$$;

REVOKE ALL ON FUNCTION public.get_departments_public() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_departments_public() TO anon;
GRANT EXECUTE ON FUNCTION public.get_departments_public() TO authenticated;
