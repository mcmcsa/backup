-- Add INSERT/UPDATE/DELETE policies for buildings table
DROP POLICY IF EXISTS "Allow authenticated users to insert buildings" ON buildings;
CREATE POLICY "Allow authenticated users to insert buildings"
  ON buildings FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to update buildings" ON buildings;
CREATE POLICY "Allow authenticated users to update buildings"
  ON buildings FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to delete buildings" ON buildings;
CREATE POLICY "Allow authenticated users to delete buildings"
  ON buildings FOR DELETE
  USING (auth.role() = 'authenticated');

-- Add INSERT/UPDATE/DELETE policies for departments table
DROP POLICY IF EXISTS "Allow authenticated users to insert departments" ON departments;
CREATE POLICY "Allow authenticated users to insert departments"
  ON departments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to update departments" ON departments;
CREATE POLICY "Allow authenticated users to update departments"
  ON departments FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Allow authenticated users to delete departments" ON departments;
CREATE POLICY "Allow authenticated users to delete departments"
  ON departments FOR DELETE
  USING (auth.role() = 'authenticated');
