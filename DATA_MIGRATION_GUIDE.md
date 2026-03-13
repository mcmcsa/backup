# Migrating Hardcoded Data to Dynamic Database Loading

## Overview

This guide explains how to migrate existing hardcoded dropdown data in form pages to use dynamically loaded data from the Supabase database.

## Changed Files Summary

### 1. maintenance_history_page.dart ✅ COMPLETED
**Location**: `lib/mobile/admin/ticket/maintenance_history_page.dart`

**Changes Made**:
- Replaced hardcoded demo data with `WorkRequestService.fetchAll()`
- Added loading and error state handling
- Added error messages display

**Before**:
```dart
void _loadHistoryData() {
  _historyItems = [
    WorkRequest(
      id: '5652',
      title: 'AC Unit Filter Replacement',
      // ... hardcoded data
    ),
  ];
}
```

**After**:
```dart
Future<void> _loadHistoryData() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final data = await WorkRequestService.fetchAll();
    
    if (mounted) {
      setState(() {
        _historyItems = data;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }
}
```

## Pages with Hardcoded Dropdown Data (Action Required)

### 1. work_request_form_page.dart (Student/Teacher Version)
**Location**: `lib/mobile/student_teacher/reports/work_request_form_page.dart`

**Hardcoded Lists**:
```dart
final List<String> _buildings = [
  'Main Academic Building',
  'Engineering Building A',
  'Engineering Building B',
  'Science Complex',
  'Administration Building',
];

final List<String> _colleges = [
  'College of Arts and Sciences',
  'College of Engineering',
  'College of Business',
  'College of Education',
  'College of Information Technology',
];

final List<String> _positions = [
  'Student',
  'Professor',
  'Staff',
  'Administrator',
];
```

**Hardcoded Request Types**:
```dart
_buildRadioOption('Ocular Inspection'),
_buildRadioOption('Installation'),
_buildRadioOption('Repair'),
_buildRadioOption('Replacement'),
_buildRadioOption('Others'),
```

**Recommended Migration**:

```dart
import '../../../shared/utils/dropdown_data_helper.dart';

class WorkRequestFormPage extends StatefulWidget {
  // ... existing code ...
}

class _WorkRequestFormPageState extends State<WorkRequestFormPage> {
  final _dropdownHelper = DropdownDataHelper();
  
  List<String> _buildings = [];
  List<String> _departments = [];
  List<String> _requestTypes = [];
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    setState(() => _isLoadingData = true);
    
    try {
      final buildings = await _dropdownHelper.getBuildingNames();
      final departments = await _dropdownHelper.getDepartmentNames();
      final requestTypes = await _dropdownHelper.getRequestTypeNames();
      
      if (mounted) {
        setState(() {
          _buildings = buildings;
          _departments = departments;
          _requestTypes = requestTypes;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading form data: $e')),
        );
      }
    }
  }

  // Use _positions from helper instead of hardcoded
  @override
  Widget build(BuildContext context) {
    final positions = _dropdownHelper.getPositions();
    final colleges = _dropdownHelper.getColleges();
    
    // ... rest of build method ...
  }
}
```

### 2. work_request_form_page.dart (Admin Version)
**Location**: `lib/mobile/admin/ticket/work_request_form_page.dart`

**Hardcoded Buildings**:
```dart
final List<String> _buildings = [
  'Select Building',
  'Main Building',
  'Science Building',
  'Engineering Building',
  'Business Administration',
  'IT Building',
];
```

**Hardcoded Request Types**:
```dart
final List<String> _requestTypes = [
  'Ocular Inspection',
  'Installation',
  'Repair',
  'Replacement',
  'Others',
];
```

**Recommended Migration**: Follow same pattern as above

### 3. work_order_progress_page.dart
**Location**: `lib/mobile/maintenance/task/work_order_progress_page.dart`

**Hardcoded Materials**:
```dart
List<Map<String, dynamic>> materials = [
  {'name': 'Drive Belt (B-42)', 'code': 'DB-42', 'qty': 1},
  {'name': 'Lubricant Spray (WD-40)', 'code': 'LS-40', 'qty': 2},
];
```

**Note**: This hardcoded materials list may be intentional for demonstration. Consider:
- Adding a `materials` table to the database for inventory tracking
- Or keeping it as a local form feature
- Or loading from a shared configuration

## Implementation Pattern (Copy & Paste)

Use this pattern for converting any form page:

```dart
import '../../../shared/utils/dropdown_data_helper.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/request_type_service.dart';

class MyFormPage extends StatefulWidget {
  const MyFormPage({super.key});

  @override
  State<MyFormPage> createState() => _MyFormPageState();
}

class _MyFormPageState extends State<MyFormPage> {
  final _dropdownHelper = DropdownDataHelper();
  
  // Dropdown data
  List<String> _buildings = [];
  List<String> _departments = [];
  List<String> _requestTypes = [];
  List<String> _positions = [];
  
  // Selected values
  String? _selectedBuilding;
  String? _selectedDepartment;
  String? _selectedRequestType;
  String? _selectedPosition;
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      setState(() => _isLoading = true);
      
      final [buildings, departments, requestTypes] = await Future.wait([
        _dropdownHelper.getBuildingNames(),
        _dropdownHelper.getDepartmentNames(),
        _dropdownHelper.getRequestTypeNames(),
      ]);
      
      if (mounted) {
        setState(() {
          _buildings = buildings;
          _departments = departments;
          _requestTypes = requestTypes;
          _positions = _dropdownHelper.getPositions();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load form: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Form')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBuilding,
              items: _buildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (value) => setState(() => _selectedBuilding = value),
              decoration: InputDecoration(labelText: 'Building'),
            ),
            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (value) => setState(() => _selectedDepartment = value),
              decoration: InputDecoration(labelText: 'Department'),
            ),
            // ... more fields ...
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}
```

## Database Setup Required

Before implementing these changes, ensure:

1. ✅ All migration files have been run (see DATABASE_SETUP.md)
2. ✅ Seed data has been imported
3. ✅ Supabase project is properly configured
4. ✅ Row Level Security policies are in place

## Testing Changes

After migration, test:

1. **Data Loading**: Verify data loads without errors
2. **Error Handling**: Disable internet and verify error message displays
3. **Performance**: Check that dropdowns load quickly with caching
4. **Offline**: Test offline fallback behavior
5. **Data Accuracy**: Verify database data matches dropdown selections

## Performance Considerations

### Caching
The `DropdownDataHelper` automatically caches data for 1 hour:
- Reduces database calls
- Improves form load time
- Cache invalidates after 1 hour

### Clear Cache
To force refresh:
```dart
_dropdownHelper.clearCache();
await _loadFormData();
```

### Concurrent Requests
For multiple dropdown loads, use `Future.wait`:
```dart
final [buildings, departments] = await Future.wait([
  _dropdownHelper.getBuildingNames(),
  _dropdownHelper.getDepartmentNames(),
]);
```

## Troubleshooting

### Empty Dropdown Lists
1. Verify database has seed data
2. Check RLS policies allow read access
3. Check Supabase connection
4. Check app logs for errors

### Slow Loading
1. Check database indexes (should be in place from migrations)
2. Verify network speed
3. Consider reducing query results with filters
4. Check for concurrent queries

### Selection Not Saving
1. Ensure `setState()` is called when selection changes
2. Check form validation logic
3. Verify model matches database fields
4. Check service method parameters

## Rollback Plan

If issues occur, revert to hardcoded data temporarily:

```dart
List<String> _getHardcodedBuildings() {
  return [
    'Main Academic Building',
    'Engineering Building A',
    'Engineering Building B',
    'Science Complex',
    'Administration Building',
  ];
}

@override
void initState() {
  super.initState();
  _buildings = _getHardcodedBuildings();
  // ... temporarily bypass dynamic loading
}
```

## Checklist for Migration

- [ ] Update imports to include services and helper
- [ ] Add state variables for dropdown data
- [ ] Add `_loadFormData()` method
- [ ] Update `initState()` to call data loading
- [ ] Update build method to use loaded data
- [ ] Add loading/error state UI
- [ ] Add null-safety checks
- [ ] Test with actual database data
- [ ] Test error scenarios
- [ ] Update related test files if applicable
- [ ] Document any custom logic
- [ ] Review and test on multiple devices

## Next Steps

1. **Priority 1** (Complete ASAP):
   - [ ] Migrate student/teacher work request form
   - [ ] Migrate admin work request form
   - [ ] Migrate dashboard data loading

2. **Priority 2** (Complete within week):
   - [ ] Migrate all other form pages
   - [ ] Migrate room management pages
   - [ ] Migrate analytics pages

3. **Priority 3** (Enhancement):
   - [ ] Add search/filter to dropdown lists
   - [ ] Add pagination for large lists
   - [ ] Add custom grouping (by campus, building, etc.)
   - [ ] Implement advanced caching strategies
