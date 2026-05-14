# Supabase Migration and Page Ownership Map

This document organizes all migrations by feature area and maps each area to the app pages that depend on it.

## Current Database Scope

- Total tables defined in migrations: 17
- Migration folder: `supabase/migrations/`

### Tables (Current)

1. departments
2. buildings
3. users
4. rooms
5. request_types
6. work_requests
7. room_schedules
8. qr_code_history
9. e_signatures
10. pre_inspection_reports
11. post_repair_reports
12. app_notifications
13. admin_users
14. maintenance_users
15. teacher_users
16. room_types
17. floors

## Combined Page Sets In Use

These are the active page groups that cover the migration-backed tables. The individual split pages still exist in the workspace, but the combined pages are the primary entry points.

- Facility management: `DepartmentBuildingManagementPage` covers `departments`, `buildings`, `room_types`, and `floors`.
- Room management: `RoomManagementPage` covers `rooms`, with add/edit/schedule/history subpages tied to the same room schema.
- Work request flow: the admin and teacher work-request pages are grouped around `request_types`, `work_requests`, `e_signatures`, `pre_inspection_reports`, `post_repair_reports`, and `app_notifications`.
- User and account management: `UsersPage`, `MaintenanceManagementPage`, and profile/auth pages cover `users`, `admin_users`, `maintenance_users`, and `teacher_users`.
- Scanner and QR flow: teacher scanner pages cover `rooms` and `qr_code_history`.

### Split pages that are now subsumed by combined screens

- `DepartmentManagementPage`
- `BuildingManagementPage`
- `RoomTypeManagementPage`

These pages still exist in the folder, but they are functionally replaced by the combined facility management flow.

## Table To Page Combination Matrix

This is the direct mapping you asked for: each table is grouped with the page set that uses it.

### `departments`

- Primary pages: `DepartmentBuildingManagementPage`
- Subsumed pages: `DepartmentManagementPage`
- Related pages: `RoomManagementPage`, room add/edit pages, teacher work-request form pages

### `buildings`

- Primary pages: `DepartmentBuildingManagementPage`
- Subsumed pages: `BuildingManagementPage`
- Related pages: `RoomManagementPage`, room add/edit pages, teacher work-request form pages

### `room_types`

- Primary pages: `DepartmentBuildingManagementPage`
- Subsumed pages: `RoomTypeManagementPage`
- Related pages: `RoomManagementPage`, room add/edit pages

### `floors`

- Primary pages: `DepartmentBuildingManagementPage`
- Related pages: `RoomManagementPage`, room add/edit pages

### `rooms`

- Primary pages: `RoomManagementPage`
- Related pages: `AddRoomPage`, `EditRoomPage`, `ViewSchedulePage`, `QRCodeHistoryPage`, teacher scanner pages

### `qr_code_history`

- Primary pages: `QRCodeHistoryPage`, teacher scanner pages

### `room_schedules`

- Primary pages: `RoomManagementPage`, `ViewSchedulePage`, `AddSchedulePage`, `EditSchedulePage`, `ScheduleManagementPageWeb`

### `request_types`

- Primary pages: work-request form pages
- Related pages: work request admin and teacher pages that show request-type choices

### `work_requests`

- Primary pages: `WorkRequestsPage`, `ApprovalQueuePage`, `RequestDetailsPage`, `ViewQueuePage`, `MaintenanceHistoryPage`, teacher reports, maintenance task pages

### `e_signatures`

- Primary pages: approval and inspection/review pages in admin and maintenance flows

### `pre_inspection_reports`

- Primary pages: pre-inspection form/review pages

### `post_repair_reports`

- Primary pages: post-repair form/evaluation pages

### `app_notifications`

- Primary pages: notifications pages and the app bar notification flow

### `users`

- Primary pages: auth and profile pages
- Related pages: admin user listing pages, faculty/maintenance management pages

### `admin_users`

- Primary pages: admin profile and admin account visibility inside settings/profile flows

### `maintenance_users`

- Primary pages: `MaintenanceManagementPage`, maintenance profile pages

### `teacher_users`

- Primary pages: `UsersPage`, `UsersPageWeb`, teacher profile pages

## 1) Location and Room Master Data

### Migrations

- 20260308000001_create_departments_table.sql
- 20260308000002_create_buildings_table.sql
- 20260308000004_create_rooms_table.sql
- 20260308000007_create_room_schedules_table.sql
- 20260308000008_create_qr_code_history_table.sql
- 20260308000011_add_room_name_department_to_qr_code_history.sql
- 20260315000012_migrate_room_ids_to_rm_format.sql
- 20260327000015_simplify_departments_for_room_identity.sql
- 20260327000022_create_room_types_table.sql
- 20260401000019_create_floors_table.sql
- 20260401000020_normalize_master_tables_and_remove_seed_data.sql
- 20260402000022_finalize_department_drop_code.sql
- 20260402000023_add_department_id_to_buildings.sql

### Tables owned

- departments
- buildings
- rooms
- room_schedules
- qr_code_history
- room_types
- floors

### Primary pages that belong here

- lib/mobile/admin/rooms/*
- lib/web/admin/rooms/*
- lib/mobile/admin/departments/*
- lib/mobile/admin/buildings/*
- lib/mobile/teacher/scanner/*

### Primary services

- DepartmentService
- BuildingService
- RoomService
- ScheduleService
- QRCodeHistoryService
- RoomTypeService
- FloorService

## 2) Work Request and Maintenance Workflow

### Migrations

- 20260308000005_create_request_types_table.sql
- 20260308000006_create_work_requests_table.sql
- 20260308000010_add_workflow_tables.sql
- 20260315000011_create_app_notifications_table.sql
- 20260327000018_limit_teacher_management_and_maintenance_archive.sql

### Tables owned

- request_types
- work_requests
- e_signatures
- pre_inspection_reports
- post_repair_reports
- app_notifications

### Primary pages that belong here

- lib/mobile/teacher/reports/*
- lib/mobile/admin/ticket/*
- lib/mobile/admin/maintenance/*
- lib/mobile/maintenance/task/*
- lib/mobile/maintenance/history/*
- lib/web/admin/ticket/*
- lib/web/admin/maintenance/*
- lib/web/admin/tickets/*
- lib/mobile/admin/shared/notifications_page.dart
- lib/web/admin/shared/notifications_page.dart

### Primary services

- WorkRequestService
- RequestTypeService
- ESignatureService
- PreInspectionService
- PostRepairService
- AppNotificationService

## 3) Authentication, Accounts, and Role Access

### Migrations

- 20260308000003_create_users_table.sql
- 20260321000013_create_role_user_tables.sql
- 20260327000014_fix_users_policy_recursion.sql
- 20260327000016_add_account_management_fields.sql
- 20260327000017_enforce_single_admin_user.sql
- 20260327000019_fix_maintenance_signup_policy.sql
- 20260327000020_fix_auth_trigger_rls_for_role_tables.sql
- 20260327000021_fix_system_role_policies_by_db_role.sql

### Tables owned

- users
- admin_users
- maintenance_users
- teacher_users

### Primary pages that belong here

- lib/authentication/screens/*
- lib/mobile/admin/users/*
- lib/web/admin/users/*
- lib/mobile/admin/profile/*
- lib/web/admin/profile/*
- lib/mobile/teacher/profile/*
- lib/mobile/maintenance/profile/*

### Primary services

- AuthService
- MaintenanceAccountService
- FacultyUserService

## 4) Cross-Cutting Baseline and Delta Alignments

### Migrations

- 20260308000012_add_insert_policies_buildings_departments.sql
- 20260402000021_apply_base_migration_deltas.sql

### Purpose

- Align policy and schema deltas after base migration sequence
- Keep existing pages stable while schema evolves

## Page Ownership Quick Matrix

- Admin Rooms/Buildings/Departments pages: location and room master data migrations
- Teacher Scanner pages: rooms and qr_code_history migrations
- Teacher Reports pages: work_requests and workflow tables migrations
- Maintenance Task pages: work_requests plus pre/post workflow migrations
- Admin Ticket and Maintenance pages: workflow migrations plus notifications
- Users/Profile/Auth pages: users and role tables migrations with policy fixes

## Recommended Working Rule

When you add or edit a page:

1. Identify its primary service in `lib/shared/services/`.
2. Identify the underlying table(s) used by that service.
3. Add a migration in the correct feature area above.
4. Keep timestamp order globally, but use feature naming in filename for clarity.

Example filename style:

- `YYYYMMDDHHMMSS_rooms_add_room_status_index.sql`
- `YYYYMMDDHHMMSS_workflow_add_rework_reason.sql`
- `YYYYMMDDHHMMSS_accounts_add_user_last_login.sql`

## Notes

- Migration execution must still follow timestamp order.
- This organization is for ownership and maintenance clarity, not changing Supabase execution behavior.

## Migration File Inventory

One line per migration file, grouped by the table(s) it owns or adjusts.

- `20260308000001_create_departments_table.sql` -> `departments` -> `DepartmentBuildingManagementPage`
- `20260308000002_create_buildings_table.sql` -> `buildings` -> `DepartmentBuildingManagementPage`
- `20260308000003_create_users_table.sql` -> `users` -> auth/profile pages and account management pages
- `20260308000004_create_rooms_table.sql` -> `rooms` -> `RoomManagementPage`, room add/edit pages, scanner pages
- `20260308000005_create_request_types_table.sql` -> `request_types` -> work-request form pages
- `20260308000006_create_work_requests_table.sql` -> `work_requests` -> teacher reports, admin ticket pages, maintenance task pages
- `20260308000007_create_room_schedules_table.sql` -> `room_schedules` -> room schedule pages
- `20260308000008_create_qr_code_history_table.sql` -> `qr_code_history` -> QR history and scanner pages
- `20260308000010_add_workflow_tables.sql` -> `e_signatures`, `pre_inspection_reports`, `post_repair_reports` -> approval, inspection, and repair workflow pages
- `20260308000011_add_room_name_department_to_qr_code_history.sql` -> `qr_code_history` -> QR history and scanner pages
- `20260308000012_add_insert_policies_buildings_departments.sql` -> policy-only for `departments` and `buildings`
- `20260315000011_create_app_notifications_table.sql` -> `app_notifications` -> notifications pages
- `20260315000012_migrate_room_ids_to_rm_format.sql` -> `rooms` -> room management and scanner pages
- `20260321000013_create_role_user_tables.sql` -> `admin_users`, `maintenance_users`, `teacher_users` -> users/profile/account pages
- `20260327000014_fix_users_policy_recursion.sql` -> policy-only for `users`
- `20260327000015_simplify_departments_for_room_identity.sql` -> `departments` identity cleanup -> facility management pages
- `20260327000016_add_account_management_fields.sql` -> `teacher_users`, `maintenance_users` -> users/profile/account pages
- `20260327000017_enforce_single_admin_user.sql` -> `users` admin constraint -> admin/profile pages
- `20260327000018_limit_teacher_management_and_maintenance_archive.sql` -> `teacher_users`, `maintenance_users` -> `UsersPage`, `MaintenanceManagementPage`
- `20260327000019_fix_maintenance_signup_policy.sql` -> policy-only for `maintenance_users`
- `20260327000020_fix_auth_trigger_rls_for_role_tables.sql` -> policy-only for `users`, `admin_users`, `maintenance_users`, `teacher_users`
- `20260327000021_fix_system_role_policies_by_db_role.sql` -> policy-only for `users`, `admin_users`, `maintenance_users`, `teacher_users`
- `20260327000022_create_room_types_table.sql` -> `room_types` -> `DepartmentBuildingManagementPage`
- `20260401000019_create_floors_table.sql` -> `floors` -> `DepartmentBuildingManagementPage`
- `20260401000020_normalize_master_tables_and_remove_seed_data.sql` -> `departments`, `buildings`, `request_types`, `room_types`, `floors`, `rooms` cleanup -> combined facility, room, and work-request pages
- `20260402000021_apply_base_migration_deltas.sql` -> cross-cutting delta for `users`, `app_notifications`, `e_signatures`, `rooms`
- `20260402000022_finalize_department_drop_code.sql` -> `departments` -> combined facility management page
- `20260402000023_add_department_id_to_buildings.sql` -> `buildings` -> combined facility management page

### Practical combined-screen summary

- Facility management pages combine `departments`, `buildings`, `room_types`, and `floors`.
- Room management pages combine `rooms`, `room_schedules`, and `qr_code_history`.
- Teacher and admin request pages combine `request_types`, `work_requests`, `e_signatures`, `pre_inspection_reports`, `post_repair_reports`, and `app_notifications`.
- Auth and account pages combine `users`, `admin_users`, `maintenance_users`, and `teacher_users`.

### Clean table view

| Migration file | Table(s) | Combined page group |
| --- | --- | --- |
| `20260308000001_create_departments_table.sql` | `departments` | Facility management |
| `20260308000002_create_buildings_table.sql` | `buildings` | Facility management |
| `20260308000003_create_users_table.sql` | `users` | Auth and account management |
| `20260308000004_create_rooms_table.sql` | `rooms` | Room management |
| `20260308000005_create_request_types_table.sql` | `request_types` | Work request flow |
| `20260308000006_create_work_requests_table.sql` | `work_requests` | Work request flow |
| `20260308000007_create_room_schedules_table.sql` | `room_schedules` | Room management |
| `20260308000008_create_qr_code_history_table.sql` | `qr_code_history` | Room management and scanner flow |
| `20260308000010_add_workflow_tables.sql` | `e_signatures`, `pre_inspection_reports`, `post_repair_reports` | Work request flow |
| `20260308000011_add_room_name_department_to_qr_code_history.sql` | `qr_code_history` | Room management and scanner flow |
| `20260308000012_add_insert_policies_buildings_departments.sql` | policy updates for `departments`, `buildings` | Facility management |
| `20260315000011_create_app_notifications_table.sql` | `app_notifications` | Work request flow |
| `20260315000012_migrate_room_ids_to_rm_format.sql` | `rooms` | Room management |
| `20260321000013_create_role_user_tables.sql` | `admin_users`, `maintenance_users`, `teacher_users` | Auth and account management |
| `20260327000014_fix_users_policy_recursion.sql` | policy-only for `users` | Auth and account management |
| `20260327000015_simplify_departments_for_room_identity.sql` | `departments` identity cleanup | Facility management |
| `20260327000016_add_account_management_fields.sql` | `teacher_users`, `maintenance_users` | Auth and account management |
| `20260327000017_enforce_single_admin_user.sql` | `users` admin constraint | Auth and account management |
| `20260327000018_limit_teacher_management_and_maintenance_archive.sql` | `teacher_users`, `maintenance_users` | Auth and account management |
| `20260327000019_fix_maintenance_signup_policy.sql` | policy-only for `maintenance_users` | Auth and account management |
| `20260327000020_fix_auth_trigger_rls_for_role_tables.sql` | policy-only for `users`, `admin_users`, `maintenance_users`, `teacher_users` | Auth and account management |
| `20260327000021_fix_system_role_policies_by_db_role.sql` | policy-only for `users`, `admin_users`, `maintenance_users`, `teacher_users` | Auth and account management |
| `20260327000022_create_room_types_table.sql` | `room_types` | Facility management |
| `20260401000019_create_floors_table.sql` | `floors` | Facility management |
| `20260401000020_normalize_master_tables_and_remove_seed_data.sql` | `departments`, `buildings`, `request_types`, `room_types`, `floors`, `rooms` cleanup | Facility, room, and request flows |
| `20260402000021_apply_base_migration_deltas.sql` | cross-cutting deltas for `users`, `app_notifications`, `e_signatures`, `rooms` | Auth, workflow, and room management |
| `20260402000022_finalize_department_drop_code.sql` | `departments` | Facility management |
| `20260402000023_add_department_id_to_buildings.sql` | `buildings` | Facility management |

### How to read this table

- If a migration file is in the same combined page group, it should usually be owned by the same feature area in the app.
- Policy-only migrations still belong to the table they protect, even when they do not change columns.
- Cross-cutting delta migrations should be treated as fixes for multiple page groups, not as standalone feature screens.
