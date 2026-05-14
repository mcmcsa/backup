-- Cleanup legacy maintenance_users columns left from older schema versions.
-- Date: 2026-04-06

-- Preserve any old contact numbers before dropping contact_no.
UPDATE maintenance_users
SET phone = COALESCE(NULLIF(phone, ''), NULLIF(contact_no, ''))
WHERE contact_no IS NOT NULL;

-- Remove columns that are no longer part of the maintenance account model.
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS department;
ALTER TABLE maintenance_users DROP COLUMN IF EXISTS contact_no;
