-- Diagnose Supabase Auth schema access when password login returns:
--   {"error_code":"unexpected_failure","msg":"Database error querying schema"}
-- Date: 2026-07-03
--
-- This is intentionally read-only. Run it in Supabase SQL Editor and check
-- the output. If auth_schema_ok is false or the schema_migrations row is
-- missing, the project auth schema needs Supabase-side repair/support.

SELECT
  has_schema_privilege('supabase_auth_admin', 'auth', 'USAGE') AS auth_schema_ok,
  has_table_privilege(
    'supabase_auth_admin',
    'auth.users',
    'SELECT, INSERT, UPDATE, DELETE'
  ) AS auth_users_ok,
  has_table_privilege(
    'supabase_auth_admin',
    'auth.schema_migrations',
    'SELECT'
  ) AS auth_schema_migrations_ok,
  to_regclass('auth.schema_migrations') IS NOT NULL AS schema_migrations_exists,
  to_regclass('auth.users') IS NOT NULL AS auth_users_exists;

SELECT
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users'
ORDER BY trigger_name, event_manipulation;
