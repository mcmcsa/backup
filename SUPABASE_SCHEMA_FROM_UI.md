# Supabase Schema From Current UI

This schema is inferred from the current app structure, shared services, and page ownership. It focuses on the tables needed by the active UI, not the deleted migration history.

## 1) Necessary Database Tables

### Authentication and accounts

- `users`
- `maintenance_users`
- `teacher_users`

### Facility and location management

- `departments`
- `buildings`
- `room_types`
- `floors`
- `rooms`
- `room_schedules`
- `qr_code_history`

### Work request and workflow

- `request_types`
- `work_requests`
- `e_signatures`
- `pre_inspection_reports`
- `post_repair_reports`
- `app_notifications`

## 2) Table Design

### `users`

Primary user profile table linked to `auth.users`.

- `id` UUID, primary key, references `auth.users(id)`
- `email` VARCHAR(255), unique, not null
- `name` VARCHAR(255), not null
- `role` VARCHAR(50), not null, allowed values: `admin`, `teacher`, `maintenance`
- `is_active` BOOLEAN, default `true`
- `last_login` TIMESTAMP WITH TIME ZONE, nullable
- `created_at` TIMESTAMP WITH TIME ZONE, default current timestamp
- `updated_at` TIMESTAMP WITH TIME ZONE, default current timestamp

### `maintenance_users`

Maintenance staff profile table.

- `user_id` UUID, primary key, references `users(id)`
- `specialization` VARCHAR(150), nullable
- `shift_schedule` VARCHAR(100), nullable
- `employee_id` VARCHAR(100), nullable
- `contact_no` VARCHAR(20), nullable
- `profile_image` VARCHAR(500), nullable
- `created_by_admin_id` UUID, nullable, references `users(id)`
- `archived_at` TIMESTAMP WITH TIME ZONE, nullable
- `archived_by_admin_id` UUID, nullable, references `users(id)`
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `teacher_users`

Faculty profile table.

- `user_id` UUID, primary key, references `users(id)`
- `department` VARCHAR(150), nullable
- `position` VARCHAR(100), nullable
- `employee_id` VARCHAR(100), nullable
- `phone` VARCHAR(20), nullable
- `profile_image` VARCHAR(500), nullable
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `departments`

Department master table.

- `id` UUID, primary key
- `name` VARCHAR(255), unique, not null
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `buildings`

Building master table.

- `id` UUID, primary key
- `name` VARCHAR(255), not null
- `code` VARCHAR(50), unique, not null
- `department_id` UUID, nullable, references `departments(id)`
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `room_types`

Room classification lookup table.

- `id` UUID, primary key
- `name` VARCHAR(255), unique, not null
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `floors`

Floor lookup table.

- `id` UUID, primary key
- `name` VARCHAR(100), unique, not null
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `rooms`

Room inventory table.

- `id` TEXT, primary key
- `code` VARCHAR(50), unique, not null
- `name` VARCHAR(255), not null
- `department_id` UUID, nullable, references `departments(id)`
- `building_id` UUID, not null, references `buildings(id)`
- `floor` VARCHAR(50), not null
- `seats` INT, not null
- `room_type_id` UUID, nullable, references `room_types(id)`
- `status` VARCHAR(50), allowed values: `available`, `reserved`, `maintenance`, `inactive`
- `image_url` VARCHAR(500), nullable
- `qr_code_data` TEXT, unique, nullable
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `room_schedules`

Room usage and maintenance schedule table.

- `id` UUID, primary key
- `room_id` TEXT, not null, references `rooms(id)`
- `subject_name` VARCHAR(255), not null
- `instructor` VARCHAR(255), not null
- `scheduled_date` DATE, not null
- `start_time` TIME, not null
- `end_time` TIME, not null
- `is_maintenance_window` BOOLEAN, default `false`
- `notes` TEXT, nullable
- `status` VARCHAR(50), allowed values: `scheduled`, `confirmed`, `cancelled`
- `created_by_id` UUID, nullable, references `users(id)`
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `qr_code_history`

QR code issuance and scan history table.

- `id` UUID, primary key
- `room_id` TEXT, nullable, references `rooms(id)`
- `qr_code_value` TEXT, unique, not null
- `qr_code_image` TEXT, nullable
- `created_by_id` UUID, not null, references `users(id)`
- `room_name` TEXT, nullable
- `building` TEXT, nullable
- `department` TEXT, nullable
- `created_at` TIMESTAMP WITH TIME ZONE
- `scanned_count` INT, default `0`
- `last_scanned` TIMESTAMP WITH TIME ZONE, nullable
- `is_active` BOOLEAN, default `true`

### `request_types`

Request category lookup table.

- `id` UUID, primary key
- `name` VARCHAR(255), unique, not null
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `work_requests`

Main maintenance request table.

- `id` TEXT, primary key
- `title` VARCHAR(500), not null
- `description` TEXT, not null
- `type_of_request` VARCHAR(255), not null
- `status` VARCHAR(50), allowed values: `pending`, `approved`, `in_progress`, `under_maintenance`, `completed`, `rework`, `cancelled`
- `priority` VARCHAR(50), allowed values: `low`, `medium`, `high`
- `building_name` VARCHAR(255), not null
- `building_id` UUID, nullable, references `buildings(id)`
- `department` VARCHAR(255), not null
- `department_id` UUID, nullable, references `departments(id)`
- `office_room` VARCHAR(100), not null
- `room_id` TEXT, nullable, references `rooms(id)`
- `date_submitted` TIMESTAMP WITH TIME ZONE, default current timestamp
- `date_completed` TIMESTAMP WITH TIME ZONE, nullable
- `date_due` TIMESTAMP WITH TIME ZONE, nullable
- `requestor_name` VARCHAR(255), not null
- `requestor_position` VARCHAR(100), not null
- `requestor_id` UUID, nullable, references `users(id)`
- `reported_by` VARCHAR(255), nullable
- `reported_by_id` UUID, nullable, references `users(id)`
- `approved_by` VARCHAR(255), nullable
- `approved_by_id` UUID, nullable, references `users(id)`
- `approved_date` TIMESTAMP WITH TIME ZONE, nullable
- `assigned_to_id` UUID, nullable, references `users(id)`
- `accepted_by_id` UUID, nullable, references `users(id)`
- `accepted_by_name` VARCHAR(255), nullable
- `accepted_date` TIMESTAMP WITH TIME ZONE, nullable
- `maintenance_start_time` TIMESTAMP WITH TIME ZONE, nullable
- `maintenance_end_time` TIMESTAMP WITH TIME ZONE, nullable
- `pre_inspection_id` UUID, nullable
- `post_repair_id` UUID, nullable
- `rework_count` INT, default `0`
- `rework_notes` TEXT, nullable
- `work_evidence` VARCHAR(500), nullable
- `maintenance_notes` TEXT, nullable
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `e_signatures`

Electronic signature records tied to requests.

- `id` UUID, primary key
- `work_request_id` TEXT, not null, references `work_requests(id)`
- `signer_id` UUID, not null, references `users(id)`
- `signer_name` VARCHAR(255), not null
- `signer_role` VARCHAR(50), allowed values: `admin`, `maintenance`, `teacher`
- `signature_type` VARCHAR(50), allowed values: `approval`, `acceptance`, `pre_inspection`, `post_repair`, `completion`
- `signature_data` TEXT, not null
- `signed_at` TIMESTAMP WITH TIME ZONE, default current timestamp
- `notes` TEXT, nullable
- `created_at` TIMESTAMP WITH TIME ZONE

### `pre_inspection_reports`

Pre-inspection workflow table.

- `id` UUID, primary key
- `work_request_id` TEXT, not null, references `work_requests(id)`
- `inspector_id` UUID, not null, references `users(id)`
- `inspector_name` VARCHAR(255), not null
- `inspection_date` TIMESTAMP WITH TIME ZONE, default current timestamp
- `condition_found` TEXT, not null
- `description` TEXT, nullable
- `root_cause` TEXT, nullable
- `severity_level` VARCHAR(50), allowed values: `Minor`, `Moderate`, `Critical`
- `recommended_action` VARCHAR(255), nullable
- `materials_needed` TEXT, nullable
- `estimated_time` VARCHAR(100), nullable
- `photo_evidence` TEXT, nullable
- `admin_approved` BOOLEAN, default `false`
- `admin_approved_by` UUID, nullable, references `users(id)`
- `admin_approved_date` TIMESTAMP WITH TIME ZONE, nullable
- `status` VARCHAR(50), allowed values: `submitted`, `approved`, `rejected`
- `notes` TEXT, nullable
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `post_repair_reports`

Post-repair workflow table.

- `id` UUID, primary key
- `work_request_id` TEXT, not null, references `work_requests(id)`
- `technician_id` UUID, not null, references `users(id)`
- `technician_name` VARCHAR(255), not null
- `repair_date` TIMESTAMP WITH TIME ZONE, default current timestamp
- `work_performed` TEXT, not null
- `materials_used` TEXT, nullable
- `photo_before` TEXT, nullable
- `photo_after` TEXT, nullable
- `repair_duration` VARCHAR(100), nullable
- `repair_status` VARCHAR(50), allowed values: `completed`, `partial`, `needs_followup`
- `technician_notes` TEXT, nullable
- `admin_evaluation` VARCHAR(50), allowed values: `satisfied`, `rework`
- `admin_evaluation_notes` TEXT, nullable
- `admin_evaluated_by` UUID, nullable, references `users(id)`
- `admin_evaluated_date` TIMESTAMP WITH TIME ZONE, nullable
- `status` VARCHAR(50), allowed values: `submitted`, `evaluated`, `rework`
- `created_at` TIMESTAMP WITH TIME ZONE
- `updated_at` TIMESTAMP WITH TIME ZONE

### `app_notifications`

In-app notification table.

- `id` UUID, primary key
- `title` VARCHAR(255), not null
- `message` TEXT, not null
- `type` VARCHAR(50), default `info`
- `target_role` VARCHAR(50), allowed values: `all`, `admin`, `teacher`, `maintenance`
- `target_user_id` UUID, nullable, references `users(id)`
- `work_request_id` TEXT, nullable, references `work_requests(id)`
- `is_read` BOOLEAN, default `false`
- `created_at` TIMESTAMP WITH TIME ZONE

## 3) Primary Keys and Foreign Keys

### Primary keys

- `users.id`
- `maintenance_users.user_id`
- `teacher_users.user_id`
- `departments.id`
- `buildings.id`
- `room_types.id`
- `floors.id`
- `rooms.id`
- `room_schedules.id`
- `qr_code_history.id`
- `request_types.id`
- `work_requests.id`
- `e_signatures.id`
- `pre_inspection_reports.id`
- `post_repair_reports.id`
- `app_notifications.id`

### Foreign keys

- `users.id` -> `auth.users.id`
- `maintenance_users.user_id` -> `users.id`
- `teacher_users.user_id` -> `users.id`
- `buildings.department_id` -> `departments.id`
- `rooms.building_id` -> `buildings.id`
- `rooms.department_id` -> `departments.id`
- `rooms.room_type_id` -> `room_types.id`
- `room_schedules.room_id` -> `rooms.id`
- `room_schedules.created_by_id` -> `users.id`
- `qr_code_history.room_id` -> `rooms.id`
- `qr_code_history.created_by_id` -> `users.id`
- `work_requests.building_id` -> `buildings.id`
- `work_requests.department_id` -> `departments.id`
- `work_requests.room_id` -> `rooms.id`
- `work_requests.requestor_id` -> `users.id`
- `work_requests.reported_by_id` -> `users.id`
- `work_requests.approved_by_id` -> `users.id`
- `work_requests.assigned_to_id` -> `users.id`
- `work_requests.accepted_by_id` -> `users.id`
- `e_signatures.work_request_id` -> `work_requests.id`
- `e_signatures.signer_id` -> `users.id`
- `pre_inspection_reports.work_request_id` -> `work_requests.id`
- `pre_inspection_reports.inspector_id` -> `users.id`
- `pre_inspection_reports.admin_approved_by` -> `users.id`
- `post_repair_reports.work_request_id` -> `work_requests.id`
- `post_repair_reports.technician_id` -> `users.id`
- `post_repair_reports.admin_evaluated_by` -> `users.id`
- `app_notifications.target_user_id` -> `users.id`
- `app_notifications.work_request_id` -> `work_requests.id`

## 4) Relationships / ERD Explanation

### One-to-one profile structure

- Each row in `users` represents one authenticated account.
- `maintenance_users` and `teacher_users` extend `users` with role-specific profile fields.
- `users.role` determines which role table should contain the matching profile row.

### Facility hierarchy

- One `department` can have many `buildings`.
- One `building` can have many `rooms`.
- One `room_type` can be assigned to many `rooms`.
- One `floor` value can be reused by many `rooms`.

### Room operations

- One `room` can have many `room_schedules`.
- One `room` can have many `qr_code_history` records.

### Work request workflow

- One `request_type` can be used by many `work_requests`.
- One `work_request` can have many `e_signatures`.
- One `work_request` can have one `pre_inspection_reports` record and one `post_repair_reports` record through the stored ID references.
- One `work_request` can generate many `app_notifications`.

### Text ERD summary

```text
auth.users
  └─ users
  ├─ maintenance_users
  └─ teacher_users

departments ──< buildings ──< rooms >── room_types
      └──────< rooms
rooms ──< room_schedules
rooms ──< qr_code_history

request_types ──< work_requests ──< e_signatures
work_requests ──< pre_inspection_reports
work_requests ──< post_repair_reports
work_requests ──< app_notifications
users ──< room_schedules
users ──< qr_code_history
users ──< work_requests (requestor / reporter / approver / assignee / accepter)
```

## 5) SQL CREATE TABLE Statements

The SQL below is a normalized baseline. It is suitable as a new schema start point for the current UI.

```sql
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'teacher', 'maintenance')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  specialization VARCHAR(150),
  shift_schedule VARCHAR(100),
  department VARCHAR(150),
  employee_id VARCHAR(100),
  contact_no VARCHAR(20),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  archived_at TIMESTAMP WITH TIME ZONE,
  archived_by_admin_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS teacher_users (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  department VARCHAR(150),
  position VARCHAR(100),
  employee_id VARCHAR(100),
  phone VARCHAR(20),
  profile_image VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS buildings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL UNIQUE,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS room_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  code VARCHAR(50) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  code VARCHAR(50) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  building_id UUID NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  floor VARCHAR(50) NOT NULL,
  room_type_id UUID REFERENCES room_types(id) ON DELETE SET NULL,
  seats INT NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'maintenance', 'inactive')),
  image_url VARCHAR(500),
  qr_code_data TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS room_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  subject_name VARCHAR(255) NOT NULL,
  instructor VARCHAR(255) NOT NULL,
  scheduled_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_maintenance_window BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  status VARCHAR(50) NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'cancelled')),
  created_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS qr_code_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT REFERENCES rooms(id) ON DELETE CASCADE,
  qr_code_value TEXT NOT NULL UNIQUE,
  qr_code_image TEXT,
  created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_name TEXT,
  building TEXT,
  department TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scanned_count INT NOT NULL DEFAULT 0,
  last_scanned TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS request_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS work_requests (
  id TEXT PRIMARY KEY,
  title VARCHAR(500) NOT NULL,
  description TEXT NOT NULL,
  type_of_request VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'in_progress', 'under_maintenance', 'completed', 'rework', 'cancelled')),
  priority VARCHAR(50) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  building_name VARCHAR(255) NOT NULL,
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  department VARCHAR(255) NOT NULL,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  office_room VARCHAR(100) NOT NULL,
  room_id TEXT REFERENCES rooms(id) ON DELETE SET NULL,
  date_submitted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_completed TIMESTAMP WITH TIME ZONE,
  date_due TIMESTAMP WITH TIME ZONE,
  requestor_name VARCHAR(255) NOT NULL,
  requestor_position VARCHAR(100) NOT NULL,
  requestor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reported_by VARCHAR(255),
  reported_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_by VARCHAR(255),
  approved_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved_date TIMESTAMP WITH TIME ZONE,
  assigned_to_id UUID REFERENCES users(id) ON DELETE SET NULL,
  accepted_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  accepted_by_name VARCHAR(255),
  accepted_date TIMESTAMP WITH TIME ZONE,
  maintenance_start_time TIMESTAMP WITH TIME ZONE,
  maintenance_end_time TIMESTAMP WITH TIME ZONE,
  pre_inspection_id UUID,
  post_repair_id UUID,
  rework_count INT NOT NULL DEFAULT 0,
  rework_notes TEXT,
  work_evidence VARCHAR(500),
  maintenance_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS e_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  signer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signer_name VARCHAR(255) NOT NULL,
  signer_role VARCHAR(50) NOT NULL CHECK (signer_role IN ('admin', 'maintenance', 'teacher')),
  signature_type VARCHAR(50) NOT NULL CHECK (signature_type IN ('approval', 'acceptance', 'pre_inspection', 'post_repair', 'completion')),
  signature_data TEXT NOT NULL,
  signed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS pre_inspection_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  inspector_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inspector_name VARCHAR(255) NOT NULL,
  inspection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  condition_found TEXT NOT NULL,
  description TEXT,
  root_cause TEXT,
  severity_level VARCHAR(50) NOT NULL DEFAULT 'Minor' CHECK (severity_level IN ('Minor', 'Moderate', 'Critical')),
  recommended_action VARCHAR(255),
  materials_needed TEXT,
  estimated_time VARCHAR(100),
  photo_evidence TEXT,
  admin_approved BOOLEAN NOT NULL DEFAULT false,
  admin_approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_approved_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'approved', 'rejected')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS post_repair_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_request_id TEXT NOT NULL REFERENCES work_requests(id) ON DELETE CASCADE,
  technician_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  technician_name VARCHAR(255) NOT NULL,
  repair_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  work_performed TEXT NOT NULL,
  materials_used TEXT,
  photo_before TEXT,
  photo_after TEXT,
  repair_duration VARCHAR(100),
  repair_status VARCHAR(50) NOT NULL DEFAULT 'completed' CHECK (repair_status IN ('completed', 'partial', 'needs_followup')),
  technician_notes TEXT,
  admin_evaluation VARCHAR(50) CHECK (admin_evaluation IN ('satisfied', 'rework')),
  admin_evaluation_notes TEXT,
  admin_evaluated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  admin_evaluated_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'evaluated', 'rework')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'info',
  target_role VARCHAR(50) NOT NULL DEFAULT 'all' CHECK (target_role IN ('all', 'admin', 'teacher', 'maintenance')),
  target_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  work_request_id TEXT REFERENCES work_requests(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

## 6) Notes

- This schema is normalized for the current UI and current app services.
- If you want, I can also turn this into a Supabase-ready migration folder again.
- If you are rebuilding from scratch, create the tables in this order:
  1. `users`
  2. role extension tables (`maintenance_users`, `teacher_users`)
  3. facility lookup tables
  4. `rooms` and scheduling tables
  5. request/workflow tables