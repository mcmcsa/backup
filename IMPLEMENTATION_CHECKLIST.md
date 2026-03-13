# Database Implementation Checklist

## Pre-Implementation

- [ ] Supabase account created
- [ ] Supabase project created
- [ ] Project URL obtained
- [ ] Anon Key obtained
- [ ] Browser access verified to Supabase dashboard

## Supabase Configuration

- [ ] Update `lib/config/supabase_config.dart` with project credentials
- [ ] OR create `.env` file with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- [ ] Test connection in `main.dart` initialization
- [ ] Verify "Supabase initialized successfully" log message

## Database Migrations

Execute migrations in this order:

### Step 1: Run Individual Migrations
```bash
# Option A: Using Supabase CLI
supabase db push

# Option B: Manual SQL Execution
# Go to Supabase Dashboard → SQL Editor → Run each file
```

- [ ] `20260308000001_create_departments_table.sql` executed
  - [ ] Verify departments table exists
  - [ ] Verify RLS enabled
  - [ ] Verify indexes created

- [ ] `20260308000002_create_buildings_table.sql` executed
  - [ ] Verify buildings table exists
  - [ ] Verify foreign key relationships

- [ ] `20260308000003_create_users_table.sql` executed
  - [ ] Verify users table created
  - [ ] Verify RLS policies in place
  - [ ] Verify department relationship

- [ ] `20260308000004_create_rooms_table.sql` executed
  - [ ] Verify rooms table created
  - [ ] Verify building and department relationships
  - [ ] Verify status enum works

- [ ] `20260308000005_create_request_types_table.sql` executed
  - [ ] Verify request_types table created
  - [ ] Verify is_active field works

- [ ] `20260308000006_create_work_requests_table.sql` executed
  - [ ] Verify work_requests table created
  - [ ] Verify all relationships configured
  - [ ] Verify status validation works

- [ ] `20260308000007_create_room_schedules_table.sql` executed
  - [ ] Verify room_schedules table created
  - [ ] Verify relationship to rooms

- [ ] `20260308000008_create_qr_code_history_table.sql` executed
  - [ ] Verify qr_code_history table created
  - [ ] Verify unique constraint on qr_code_value

### Step 2: Seed Initial Data
- [ ] `20260308000009_seed_data.sql` executed
  - [ ] Verify 5 departments created
  - [ ] Verify 5 buildings created
  - [ ] Verify 8 request types created

## Database Verification

### Check Table Structure
In Supabase Dashboard → Table Editor:

- [ ] departments: 9 columns (including timestamps)
- [ ] buildings: 10 columns
- [ ] users: 12 columns
- [ ] rooms: 14 columns
- [ ] request_types: 5 columns
- [ ] work_requests: 26 columns
- [ ] room_schedules: 10 columns
- [ ] qr_code_history: 8 columns

### Check Indexes
In Supabase Dashboard → SQL Editor:

```sql
-- Verify indexes exist
SELECT * FROM pg_indexes WHERE schemaname = 'public';
```

- [ ] departments: name, campus
- [ ] buildings: name, campus, code
- [ ] users: email, role, department_id, is_active
- [ ] rooms: building_id, department_id, status, name
- [ ] request_types: name
- [ ] work_requests: status, priority, date_submitted, building_id, etc.
- [ ] room_schedules: room_id, scheduled_date, status
- [ ] qr_code_history: room_id, created_by_id, is_active

### Check RLS Policies
In Supabase Dashboard → Authentication → Policies:

- [ ] All tables have RLS enabled
- [ ] SELECT policies allow appropriate access
- [ ] INSERT policies restrict correctly
- [ ] UPDATE policies match requirements
- [ ] DELETE policies restricted to admins

## Models Verification

Check `lib/shared/models/`:

- [ ] user_model.dart exists and has fromMap/toMap
- [ ] department_model.dart created
- [ ] building_model.dart created
- [ ] room_model.dart updated with copyWith
- [ ] work_request_model.dart updated with new fields
- [ ] schedule_model.dart updated
- [ ] request_type_model.dart created
- [ ] qr_code_history_model.dart updated

## Services Verification

Check `lib/shared/services/`:

- [ ] work_request_service.dart updated with new methods
- [ ] room_service.dart updated with new methods
- [ ] schedule_service.dart updated
- [ ] qr_code_history_service.dart uses Supabase
- [ ] department_service.dart created
- [ ] building_service.dart created
- [ ] request_type_service.dart created

Each service should have:
- [ ] `fetchAll()` method
- [ ] `fetchBy*()` filtering methods
- [ ] `fetchById()` method
- [ ] `insert()` method
- [ ] `update()` method
- [ ] `delete()` method
- [ ] Error handling with try-catch

## Utilities Verification

- [ ] `lib/shared/utils/dropdown_data_helper.dart` created
- [ ] Helper has getBuildingNames() method
- [ ] Helper has getDepartmentNames() method
- [ ] Helper has getRequestTypeNames() method
- [ ] Helper has caching logic
- [ ] Helper has constant getters (getPositions, getColleges, etc.)

## Documentation Verification

- [ ] DATABASE_SETUP.md created (comprehensive guide)
- [ ] DATA_MIGRATION_GUIDE.md created (migration instructions)
- [ ] DATABASE_IMPLEMENTATION_SUMMARY.md created (quick reference)
- [ ] This checklist file created

## Integration Testing

### Test Authentication
```dart
// In main.dart or test file
final user = Supabase.instance.client.auth.currentUser;
print('Authenticated: ${user != null}');
```

- [ ] Authentication works
- [ ] Current user can be retrieved

### Test Fetching Data

```dart
// Test each service
import 'package:psu_maintsystem/shared/services/work_request_service.dart';

void testServices() async {
  try {
    // Test Work Request Service
    final requests = await WorkRequestService.fetchAll();
    print('Work Requests: ${requests.length}');
    
    // Test Department Service
    final departments = await DepartmentService.fetchAll();
    print('Departments: ${departments.length}');
    
    // Test Building Service
    final buildings = await BuildingService.fetchAll();
    print('Buildings: ${buildings.length}');
    
  } catch (e) {
    print('Error: $e');
  }
}
```

- [ ] WorkRequestService.fetchAll() returns data or empty list
- [ ] DepartmentService.fetchAll() returns seed data (5 items)
- [ ] BuildingService.fetchAll() returns seed data (5 items)
- [ ] RequestTypeService.fetchAll() returns seed data (8 items)
- [ ] No database connection errors
- [ ] No RLS permission errors

### Test Creating Data

```dart
// Test insert operations
final newRoom = Room(
  id: 'TEST-001',
  name: 'Test Room',
  building: 'Main Building',
  seats: 30,
  status: 'available',
);

try {
  await RoomService.insert(newRoom);
  print('Room created successfully');
} catch (e) {
  print('Error creating room: $e');
}
```

- [ ] Can create new work requests
- [ ] Can create new rooms
- [ ] Can create new schedules
- [ ] Can save QR codes

### Test Updating Data

- [ ] Can update work request status
- [ ] Can update room status
- [ ] Can update schedule
- [ ] Changes persist in database

### Test Error Handling

- [ ] Network error shows appropriate message
- [ ] RLS violation prevents unauthorized access
- [ ] Invalid data shows validation error
- [ ] Missing fields shows required field error

## UI Integration

- [ ] maintenance_history_page.dart loads data dynamically ✅
- [ ] admin dashboard loads data dynamically ✅
- [ ] All forms show loading state during data fetch
- [ ] All forms show error state if data load fails
- [ ] All dropdowns use DropdownDataHelper or service
- [ ] No sample/hardcoded data visible in UI

## Performance Testing

- [ ] Dashboard loads in < 2 seconds
- [ ] Dropdown data appears in < 1 second
- [ ] Form submission completes in < 2 seconds
- [ ] Lists scroll smoothly without lag
- [ ] No memory leaks with repeated operations

## Security Testing

- [ ] Unauthenticated users cannot access data
- [ ] Users can only see/edit their own data (where applicable)
- [ ] Admin users can access all data
- [ ] Sensitive endpoints require authentication
- [ ] RLS policies are enforced

## Deployment Checklist

Before deploying to production:

- [ ] All migrations executed on production Supabase
- [ ] Seed data populated
- [ ] Environment variables set correctly
- [ ] RLS policies reviewed for security
- [ ] Backup/restore procedures documented
- [ ] Performance tested with realistic data volume
- [ ] Error handling verified
- [ ] Logging configured appropriately
- [ ] User roles and permissions tested
- [ ] Documentation up to date

## Rollback Plan

If issues occur:

- [ ] Identify problematic migration
- [ ] Create rollback migration file
- [ ] Revert to previous working state
- [ ] Analyze and fix issues
- [ ] Create new migration
- [ ] Test thoroughly before redeployment

### Rollback Example

```sql
-- If a migration causes issues, create a rollback:
DROP TABLE IF EXISTS problematic_table CASCADE;

-- Recreate from previous version or restore from backup
```

## Post-Deployment

- [ ] Monitor Supabase logs for errors
- [ ] Check database performance metrics
- [ ] Gather user feedback on functionality
- [ ] Plan next phase improvements
- [ ] Document lessons learned
- [ ] Schedule regular database maintenance

## Sign-Off

Implementation completed by: ________________  
Date: ________________  
Verified by: ________________  
Date: ________________  

---

## Notes

Use this space for any additional notes, issues encountered, or special configurations:

```
[Notes section]




```

---

**Document Version**: 1.0  
**Last Updated**: March 8, 2026  
**Status**: Ready for Implementation
