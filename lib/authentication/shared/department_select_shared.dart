import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/services/department_service.dart';

class DepartmentSelectShared {
  static Future<List<String>> loadDepartmentNames() async {
    List<String> directNames = const [];
    try {
      final departments = await DepartmentService.fetchAll();
      directNames = departments
          .map((department) => department.name.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (directNames.isNotEmpty) return directNames;
    } on PostgrestException {
      // Continue to fallback below.
    }

    // Registration is accessible before login, so use public RPC fallback.
    try {
      final response = await Supabase.instance.client.rpc('get_departments_public');
      final rows = (response as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      final rpcNames = rows
          .map((row) => (row['name'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (rpcNames.isNotEmpty) return rpcNames;
    } on PostgrestException {
      // If RPC is not deployed yet, keep returning whatever direct query had.
    }

    return directNames;
  }

  static String? validateDepartment({
    required List<String> options,
    required String? selectedDepartment,
  }) {
    if (options.isEmpty) {
      return 'No departments available. Ask admin to create one.';
    }
    if ((selectedDepartment ?? '').trim().isEmpty) {
      return 'Department is required';
    }
    return null;
  }

  static String? validateExistingDepartment({
    required List<String> options,
    required String? departmentText,
  }) {
    if (options.isEmpty) {
      return 'No departments available. Ask admin to create one.';
    }

    final value = (departmentText ?? '').trim();
    if (value.isEmpty) {
      return 'Department is required';
    }

    final exists = options.any((option) => option.toLowerCase() == value.toLowerCase());
    if (!exists) {
      return 'Please select an existing department';
    }
    return null;
  }
}
