# PSU Maintenance System - Database Setup Guide

## Overview

This document provides comprehensive information about the database schema, setup instructions, and data relationships for the PSU Maintenance System.

## Database Technology

- **Backend**: Supabase (PostgreSQL-based)
- **Access**: Supabase API with Row Level Security (RLS)
- **Authentication**: Supabase Auth integrated with Flutter

## Database Schema

### Core Tables

#### 1. **departments**
Stores information about academic and administrative departments.

```sql
- id: UUID (Primary Key)
- name: VARCHAR(255) - Unique department name
- code: VARCHAR(50) - Unique department code
- campus: VARCHAR(100) - Campus location
- contact_email: VARCHAR(255) - Department contact email
- contact_phone: VARCHAR(20) - Department contact number
- head_name: VARCHAR(255) - Department head name
- created_at: TIMESTAMP - Record creation time
- updated_at: TIMESTAMP - Last update time
```

**Indexes**: name, campus
**RLS**: Authenticated users can read

**Seed Data**:
- College of Arts and Sciences (CAS)
- College of Engineering (COE)
- College of Business (COB)
- College of Education (COED)
- College of Information Technology (CIT)

#### 2. **buildings**
Manages campus buildings and their information.

```sql
- id: UUID (Primary Key)
- name: VARCHAR(255) - Building name
- code: VARCHAR(50) - Unique building code
- campus: VARCHAR(100) - Campus location
- address: TEXT - Building address
- floors: INT - Number of floors (default: 3)
- total_rooms: INT - Total rooms in building
- description: TEXT - Building description
- building_manager: VARCHAR(255) - Building manager name
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

**Indexes**: name, campus, code
**RLS**: Authenticated users can read

**Seed Data**:
- Main Academic Building (MAB)
- Engineering Building A (EBA)
- Engineering Building B (EBB)
- Science Complex (SC)
- Administration Building (AB)

#### 3. **users** (Profiles)
User profiles linked to Supabase Auth users.

```sql
- id: UUID (Primary Key) - References auth.users(id)
- email: VARCHAR(255) - User email (unique)
- name: VARCHAR(255) - User full name
- role: VARCHAR(50) - User role (admin, student_teacher, maintenance)
- campus: VARCHAR(100) - Campus assignment
- department_id: UUID - Foreign key to departments
- position: VARCHAR(100) - Job/academic position
- profile_image: VARCHAR(500) - Profile image URL
- phone: VARCHAR(20) - Contact phone
- is_active: BOOLEAN - Account status
- last_login: TIMESTAMP - Last login time
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

**Indexes**: email, role, department_id, is_active
**RLS**: Users can view their own, admins can view all

#### 4. **rooms**
Facilities, classrooms, labs, and other spaces.

```sql
- id: TEXT (Primary Key) - Room unique identifier
- name: VARCHAR(255) - Room name
- building_id: UUID (NOT NULL) - Foreign key to buildings
- floor: VARCHAR(50) - Floor location
- room_number: VARCHAR(50) - Room number
- seats: INT - Seating capacity (default: 40)
- department_id: UUID - Associated department
- room_type: VARCHAR(100) - Type (Laboratory, Lecture Hall, Seminar Room, Office, Storage, Conference Room)
- status: VARCHAR(50) - Status (available, reserved, maintenance, inactive)
- image_url: VARCHAR(500) - Room photo URL
- description: TEXT - Room description
- qr_code_data: TEXT - Unique QR code data
- equipment: TEXT - Available equipment list
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

**Indexes**: building_id, department_id, status, name
**RLS**: Authenticated users can read; admins can manage

#### 5. **request_types**
Predefined types of maintenance requests.

```sql
- id: UUID (Primary Key)
- name: VARCHAR(255) - Request type name (e.g., "Router Inspection")
- code: VARCHAR(50) - Unique code
- description: TEXT - Type description
- is_active: BOOLEAN - Active status (default: true)
- created_at: TIMESTAMP
```

**Indexes**: name
**RLS**: Authenticated users can read

**Seed Data**:
- Ocular Inspection (OI)
- Installation (INST)
- Repair (REP)
- Replacement (REPL)
- Router Inspection (RI)
- Remediation (REM)
- Preventive Maintenance (PM)
- Emergency Repair (ER)

#### 6. **work_requests**
Maintenance and repair requests submitted by users.

```sql
- id: TEXT (Primary Key) - Request ID
- title: VARCHAR(500) - Request title
- description: TEXT - Detailed description
- type_of_request: VARCHAR(255) - Type of request
- status: VARCHAR(50) - Status (pending, ongoing, done, cancelled)
- priority: VARCHAR(50) - Priority (low, medium, high)
- campus: VARCHAR(100) - Campus location
- building_name: VARCHAR(255) - Building name
- building_id: UUID - Foreign key to buildings
- department: VARCHAR(255) - Department name
- department_id: UUID - Foreign key to departments
- office_room: VARCHAR(100) - Room location
- room_id: TEXT - Foreign key to rooms
- date_submitted: TIMESTAMP - Submission date
- date_completed: TIMESTAMP - Completion date
- date_due: TIMESTAMP - Expected due date
- requestor_name: VARCHAR(255) - Person requesting
- requestor_position: VARCHAR(100) - Requestor's position
- requestor_id: UUID - Foreign key to users
- reported_by: VARCHAR(255) - Person reporting issue
- reported_by_id: UUID - Foreign key to users
- approved_by: VARCHAR(255) - Name of approver
- approved_by_id: UUID - Foreign key to users (approver)
- approved_date: TIMESTAMP - Approval date
- assigned_to_id: UUID - Foreign key to users (assigned staff)
- work_evidence: VARCHAR(500) - Photo/evidence URL
- maintenance_notes: TEXT - Maintenance team notes
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

**Indexes**: status, priority, date_submitted, building_id, department_id, room_id, requestor_id, assigned_to_id
**RLS**: Authenticated users can read; requestors and admins can create; admins can manage all; maintenance staff can update assigned

#### 7. **room_schedules**
Class schedules and maintenance windows for rooms.

```sql
- id: UUID (Primary Key)
- room_id: TEXT (NOT NULL) - Foreign key to rooms
- subject_name: VARCHAR(255) - Class subject name
- instructor: VARCHAR(255) - Instructor name
- scheduled_date: DATE - Schedule date
- start_time: TIME - Start time
- end_time: TIME - End time
- is_maintenance_window: BOOLEAN - Maintenance window flag
- notes: TEXT - Additional notes
- status: VARCHAR(50) - Status (scheduled, confirmed, cancelled)
- created_by_id: UUID - Foreign key to users
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

**Indexes**: room_id, scheduled_date, status
**RLS**: Authenticated users can read and insert; admins can manage all

#### 8. **qr_code_history**
History of QR codes generated and tracked.

```sql
- id: UUID (Primary Key)
- room_id: TEXT - Foreign key to rooms
- qr_code_value: TEXT - QR code value (unique)
- qr_code_image: TEXT - QR code image URL
- created_by_id: UUID (NOT NULL) - Creator user ID
- created_at: TIMESTAMP - Creation date
- scanned_count: INT - Number of times scanned
- last_scanned: TIMESTAMP - Last scan time
- is_active: BOOLEAN - Active status
```

**Indexes**: room_id, created_by_id, is_active
**RLS**: Authenticated users can read; creators can insert; admins can manage all

## Table Relationships

```
departments
  ├── users (department_id)
  ├── rooms (department_id)
  └── work_requests (department_id)

buildings
  ├── rooms (building_id)
  └── work_requests (building_id)

rooms
  ├── room_schedules (room_id)
  ├── qr_code_history (room_id)
  └── work_requests (room_id)

users
  ├── work_requests (requestor_id, reported_by_id, assigned_to_id, approved_by_id)
  ├── room_schedules (created_by_id)
  └── qr_code_history (created_by_id)

request_types
  └── work_requests (type_of_request)
```

## Setting Up Supabase

### 1. Create Supabase Project

1. Go to https://supabase.com
2. Sign in or create account
3. Create a new project
4. Save your project URL and Anon Key

### 2. Update Flutter App Configuration

Update `lib/config/supabase_config.dart`:

```dart
const String supabaseUrl = 'your_project_url';
const String supabaseAnonKey = 'your_anon_key';
```

Or set environment variables in `.env`:

```
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

### 3. Run Migrations

The migration files are located in `supabase/migrations/`:

1. `20260308000001_create_departments_table.sql`
2. `20260308000002_create_buildings_table.sql`
3. `20260308000003_create_users_table.sql`
4. `20260308000004_create_rooms_table.sql`
5. `20260308000005_create_request_types_table.sql`
6. `20260308000006_create_work_requests_table.sql`
7. `20260308000007_create_room_schedules_table.sql`
8. `20260308000008_create_qr_code_history_table.sql`
9. `20260308000009_seed_data.sql` - Optional: Seeds initial data

**Option A: Using Supabase CLI**

```bash
supabase db push
```

**Option B: Manual SQL Execution**

1. Go to Supabase Dashboard → SQL Editor
2. Copy and paste each migration file into the SQL editor
3. Execute them in order

## Service Layer

All database interactions are abstracted through service classes in `lib/shared/services/`:

- `DepartmentService` - Department operations
- `BuildingService` - Building operations
- `RoomService` - Room operations
- `ScheduleService` - Room schedule operations
- `WorkRequestService` - Work request operations
- `RequestTypeService` - Request type operations
- `QRCodeHistoryService` - QR code operations

### Example Usage

```dart
// Fetch all work requests
final requests = await WorkRequestService.fetchAll();

// Fetch completed requests
final completed = await WorkRequestService.fetchByStatus('done');

// Create new request
final newRequest = WorkRequest(...);
await WorkRequestService.insert(newRequest);

// Update request status
await WorkRequestService.updateStatus(requestId, 'ongoing');
```

## Models

All data models are in `lib/shared/models/`:

- `work_request_model.dart`
- `room_model.dart`
- `schedule_model.dart`
- `qr_code_history_model.dart`
- `department_model.dart`
- `building_model.dart`
- `request_type_model.dart`
- `user_model.dart`

Each model includes:
- Constructor
- `fromMap()` factory method
- `toMap()` serialization method
- `copyWith()` for immutable updates

## Data Access Rules (Row Level Security)

### Public Access
- Departments: All authenticated users can read
- Buildings: All authenticated users can read
- Rooms: All authenticated users can read
- Request Types: All authenticated users can read
- Room Schedules: All authenticated users can read
- QR Code History: All authenticated users can read

### Restricted Access
- Users: Can view own profile; admins view all
- Work Requests: Admins can manage all; users can see all; requestors/assigned staff have special access
- QR Code History: Creators can insert their own; admins manage all

## Best Practices

1. **Always use Services**: Never access Supabase directly from UI components
2. **Error Handling**: All service methods should include try-catch blocks
3. **Loading States**: UI components should implement loading and error states
4. **Date Formatting**: Always use ISO8601 for database storage
5. **Authentication**: Check user role before sensitive operations
6. **Async Operations**: Use async/await and check `mounted` before setState

## Common Development Tasks

### Adding New Data

```dart
// Create model instance
final newRoom = Room(
  id: 'ROOM-001',
  name: 'Lab 101',
  building: 'Science Building',
  seats: 30,
  status: 'available',
);

// Save to database
await RoomService.insert(newRoom);
```

### Updating Data

```dart
// Fetch existing data
final room = await RoomService.fetchById('ROOM-001');

// Create updated copy
final updated = room!.copyWith(status: 'maintenance');

// Save changes
await RoomService.update(updated);
```

### Filtering Data

```dart
// Get all pending requests
final pending = await WorkRequestService.fetchByStatus('pending');

// Get high priority requests
final urgent = await WorkRequestService.fetchByPriority('high');

// Get requests for specific building
final building = await BuildingService.fetchByCode('SC');
final requests = await WorkRequestService.fetchByBuilding(building!.id);
```

## Troubleshooting

### Connection Issues
- Verify Supabase URL and Anon Key are correct
- Check internet connection
- Ensure Supabase project is active

### Data Not Appearing
- Verify migrations ran successfully
- Check Row Level Security policies
- Ensure user is authenticated
- Check error messages in app logs

### Performance Issues
- Use appropriate indexes (already defined in migrations)
- Limit query results with pagination
- Avoid N+1 queries - fetch related data together

## Support

For issues or questions:
1. Check Supabase documentation: https://supabase.com/docs
2. Review Flutter Supabase package: https://pub.dev/packages/supabase_flutter
3. Check application logs for error messages

## Future Enhancements

- [ ] Add analytics and reporting tables
- [ ] Implement audit logging
- [ ] Add attachment/file storage integration
- [ ] Implement notification system
- [ ] Add advanced filtering and search
- [ ] Implement data backup strategy
