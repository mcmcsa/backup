# Supabase Migration File Breakdown

This is a file-by-file explanation of what each migration in `supabase/migrations/` does.

## 20260308000001_create_departments_table.sql

Creates the `departments` table with `id`, `name`, legacy metadata columns, timestamps, an index on `name`, and row-level security policies.

## 20260308000002_create_buildings_table.sql

Creates the `buildings` table with `id`, `name`, `code`, legacy campus/location fields, timestamps, indexes, and RLS policies.

## 20260308000003_create_users_table.sql

Creates the base `users` table linked to `auth.users`, adds role and profile columns, creates indexes, and defines auth-trigger behavior for inserting new app users.

## 20260308000004_create_rooms_table.sql

Creates the `rooms` table with room identity, building and department foreign keys, room type, capacity, QR data, status, and timestamps.

## 20260308000005_create_request_types_table.sql

Creates the `request_types` lookup table for maintenance request categories.

## 20260308000006_create_work_requests_table.sql

Creates the `work_requests` table for the maintenance workflow, including status, priority, building, department, room, requestor, assignment, inspection, repair, and completion fields.

## 20260308000007_create_room_schedules_table.sql

Creates the `room_schedules` table for scheduled room usage and maintenance windows.

## 20260308000008_create_qr_code_history_table.sql

Creates the `qr_code_history` table to track QR generation and related room/building/department data.

## 20260308000010_add_workflow_tables.sql

Adds workflow support tables for `e_signatures`, `pre_inspection_reports`, and `post_repair_reports`, plus foreign key links from `work_requests` to those workflow tables.

## 20260308000011_add_room_name_department_to_qr_code_history.sql

Extends `qr_code_history` with room name and department fields so QR records preserve readable location context.

## 20260308000012_add_insert_policies_buildings_departments.sql

Adds insert policies for the base `departments` and `buildings` tables.

## 20260315000011_create_app_notifications_table.sql

Creates the `app_notifications` table for in-app notification delivery and targeting.

## 20260315000012_migrate_room_ids_to_rm_format.sql

Migrates existing room identifiers to the `RM####` format and updates room ID-related data.

## 20260321000013_create_role_user_tables.sql

Creates role-specific profile tables: `admin_users`, `maintenance_users`, and `teacher_users`, with RLS and sync triggers that keep them aligned with `users.role`.

## 20260327000014_fix_users_policy_recursion.sql

Fixes recursive `users` RLS policy behavior by moving admin checks into a security-definer helper function.

## 20260327000015_simplify_departments_for_room_identity.sql

Simplifies department identity usage for room lookups, relaxes legacy campus constraints, and creates a lightweight department identity view.

## 20260327000016_add_account_management_fields.sql

Adds account-management fields to role profile tables and updates auth-trigger behavior so faculty verification and active status work correctly.

## 20260327000017_enforce_single_admin_user.sql

Adds a unique partial index to enforce only one admin user in the `users` table.

## 20260327000018_limit_teacher_management_and_maintenance_archive.sql

Adds maintenance archival fields and narrows admin management scope so maintenance accounts are tracked per creating admin, while teacher profile management is reduced to view-only.

## 20260327000019_fix_maintenance_signup_policy.sql

Adjusts maintenance profile RLS policies so newly created maintenance rows can be inserted and later claimed by the creating admin.

## 20260327000020_fix_auth_trigger_rls_for_role_tables.sql

Updates RLS so auth system roles can insert/update `users` and the role profile tables during trigger-based account creation.

## 20260327000021_fix_system_role_policies_by_db_role.sql

Refines those system-role policies further by using explicit database roles for `users`, `admin_users`, `maintenance_users`, and `teacher_users`.

## 20260327000022_create_room_types_table.sql

Creates the `room_types` lookup table and its RLS policies for room classification.

## 20260401000019_create_floors_table.sql

Creates the `floors` lookup table with standard read/write policies.

## 20260401000020_normalize_master_tables_and_remove_seed_data.sql

Normalizes master-data tables, removes legacy seed rows, drops obsolete columns, and cleans up room type and floor legacy fields.

## 20260402000021_apply_base_migration_deltas.sql

Applies catch-up schema changes so already-applied base migrations match the current role, notification, signature, and room status rules.

## 20260402000022_finalize_department_drop_code.sql

Finalizes the department simplification by dropping the `code` column and recreating the lightweight department identity view.

## 20260402000023_add_department_id_to_buildings.sql

Adds `department_id` to `buildings` and indexes it so buildings can be grouped under departments.

## Summary by area

- Facility management: departments, buildings, rooms, room types, floors, room schedules, QR history
- Work request workflow: request types, work requests, notifications, e-signatures, inspection, repair reports
- Auth and accounts: users, admin users, maintenance users, teacher users, and their policies
- Cleanup and normalization: ID migration, master-data normalization, and policy repair migrations