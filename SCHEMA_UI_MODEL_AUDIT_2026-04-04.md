# Schema/UI/Model Connectivity Audit

Date: 2026-04-04
Scope: Supabase migrations vs Dart models, services, and UI pages.

## Executive Result

Connectivity is partial. Core tables are wired, but there are critical mismatches where UI/service attributes do not match migration columns.

## Table Coverage Snapshot

- Connected through service + used in UI: departments, buildings, rooms, request_types, work_requests, room_schedules, qr_code_history, e_signatures, pre_inspection_reports, post_repair_reports, app_notifications, maintenance_users, teacher_users, room_types, floors
- Connected in backend/service, weak UI ownership: users
- Not directly connected by dedicated service/UI flow: admin_users

## Critical Mismatches

### 1) Rooms schema mismatch (insert/update attributes)

Migration schema (`rooms`) uses:
- `code` (required, unique)
- `room_type_id` (UUID FK)
- no `room_number`
- no `room_type` text column

But model/service/UI currently use:
- `room_type` and `room_number`
- no `code` field in `Room.toMap()`

Impact:
- Room create/update may fail or write invalid payload depending on deployed DB state.

## High Mismatches

### 2) Users profile update writes non-existent columns

`users` table columns from migration:
- id, email, name, role, is_active, last_login, created_at, updated_at

Current profile update writes:
- `campus`, `department_id`, `position`, `profile_image` to `users`

Impact:
- Profile update can fail on strict schema.

### 3) Work request status vocabulary drift in UI

DB workflow statuses include:
- pending, approved, in_progress, under_maintenance, completed, rework, cancelled

Many pages/services still use legacy values:
- ongoing, done

Impact:
- Filters/counters become inaccurate.
- Some updates may fail against status constraint.

### 4) Admin users table ownership gap

`admin_users` table exists but has no dedicated service and no explicit CRUD/management flow similar to `maintenance_users` and `teacher_users`.

Impact:
- Admin profile metadata is under-utilized and not consistently represented in UI.

## Medium Mismatches

### 5) Request type UI hardcoded in admin forms

Admin work request form pages still use static request type options instead of fetching from `request_types` table.

Impact:
- UI can drift from database-managed lookup values.

## Already Good / Aligned

- `work_requests` model includes workflow columns added by migration.
- `qr_code_history` model includes added `room_name`, `building`, `department`.
- Workflow report models (`pre_inspection_reports`, `post_repair_reports`, `e_signatures`) are broadly aligned with schema.
- Department schema simplification (name-based identity) is reflected in current model usage.

## Priority Fix Order

1. Normalize `rooms` model/service/UI to `code` + `room_type_id` FK (remove text `room_type` writes).
2. Move profile fields (`department`, `position`, profile metadata) to role tables, not `users` table update payload.
3. Replace all `ongoing`/`done` logic with canonical workflow statuses.
4. Add dedicated admin profile service path for `admin_users`.
5. Convert admin work request forms to dynamic `request_types` query.

## Validation Checklist After Fix

- Create/Edit room succeeds with payload matching migration columns.
- Profile update succeeds without `column does not exist` errors.
- All dashboards and lists return consistent counts for current statuses.
- Admin profile data reads/writes through `admin_users`.
- Request type dropdowns are database-driven in both mobile and web admin forms.
