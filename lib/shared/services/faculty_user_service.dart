import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'department_service.dart';

class FacultyUserAccount {
  final String userId;
  final String email;
  final String fullName;
  final String? employeeId;
  final String? department;
  final String? position;
  final bool isActive;
  final DateTime createdAt;

  const FacultyUserAccount({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.employeeId,
    required this.department,
    required this.position,
    required this.isActive,
    required this.createdAt,
  });
}

class FacultyUserService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<FacultyUserAccount>> fetchAllFacultyUsers() async {
    // 1. Fetch teacher users from users table
    List<dynamic> usersData = [];
    try {
      usersData = await _db
          .from('users')
          .select('id, email, name, is_active, created_at')
          .eq('role', 'teacher')
          .order('name', ascending: true);
    } catch (e) {
      debugPrint('Error fetching users in FacultyUserService: $e');
    }

    if (usersData.isEmpty) return [];

    // 2. Fetch departments lookup (id -> name)
    final deptIdToName = <String, String>{};
    try {
      final deptsData = await _db.from('departments').select('id, name');
      for (final d in deptsData) {
        if (d['id'] != null && d['name'] != null) {
          final idStr = d['id'].toString();
          final nameStr = d['name'].toString().trim();
          deptIdToName[idStr] = nameStr;
          deptIdToName[idStr.toLowerCase()] = nameStr;
        }
      }
    } catch (e) {
      debugPrint('Error fetching departments in FacultyUserService: $e');
    }

    // 3. Fetch teacher_users records
    final teacherMap = <String, Map<String, dynamic>>{};
    try {
      final teachersData = await _db
          .from('teacher_users')
          .select('*');
      for (final t in teachersData) {
        if (t['user_id'] != null) {
          teacherMap[t['user_id'].toString()] = Map<String, dynamic>.from(t);
        }
      }
    } catch (e) {
      debugPrint('Error fetching teacher_users in FacultyUserService: $e');
    }

    // 4. Fallback lookup: check if user submitted work_requests with department_id
    final workReqDeptMap = <String, String>{};
    try {
      final wrData = await _db
          .from('work_requests')
          .select('requestor_id, department_id')
          .not('department_id', 'is', null);
      for (final wr in wrData) {
        if (wr['requestor_id'] != null && wr['department_id'] != null) {
          final reqId = wr['requestor_id'].toString();
          final dId = wr['department_id'].toString();
          if (deptIdToName.containsKey(dId)) {
            workReqDeptMap[reqId] = deptIdToName[dId]!;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching work_requests department fallback: $e');
    }

    return usersData.map((row) {
      final userMap = Map<String, dynamic>.from(row as Map);
      final userId = userMap['id']?.toString() ?? '';
      final teacherProfile = teacherMap[userId];

      String? deptName;

      // 1. Direct text in teacherProfile (department / department_name)
      final directDept = teacherProfile?['department']?.toString().trim();
      if (directDept != null &&
          directDept.isNotEmpty &&
          directDept.toLowerCase() != 'null' &&
          directDept.toLowerCase() != 'no department' &&
          directDept != '-') {
        deptName = directDept;
      }
      final directDeptName = teacherProfile?['department_name']?.toString().trim();
      if (deptName == null &&
          directDeptName != null &&
          directDeptName.isNotEmpty &&
          directDeptName.toLowerCase() != 'null' &&
          directDeptName.toLowerCase() != 'no department' &&
          directDeptName != '-') {
        deptName = directDeptName;
      }

      // 2. department_id from teacher_users resolved via departments table
      final deptId = teacherProfile?['department_id']?.toString().trim();
      if (deptName == null && deptId != null && deptId.isNotEmpty && deptId.toLowerCase() != 'null') {
        if (deptIdToName.containsKey(deptId)) {
          deptName = deptIdToName[deptId];
        } else if (deptIdToName.containsKey(deptId.toLowerCase())) {
          deptName = deptIdToName[deptId.toLowerCase()];
        }
      }

      // If directDept was an ID, resolve it
      if (deptName != null && deptIdToName.containsKey(deptName)) {
        deptName = deptIdToName[deptName];
      }

      // 3. Fallback: department from users table if present
      if (deptName == null) {
        final uDept = userMap['department']?.toString().trim();
        if (uDept != null &&
            uDept.isNotEmpty &&
            uDept.toLowerCase() != 'null' &&
            uDept.toLowerCase() != 'no department') {
          deptName = deptIdToName[uDept] ?? uDept;
        }
      }

      // 4. Fallback: department resolved from teacher's work requests
      if (deptName == null && workReqDeptMap.containsKey(userId)) {
        deptName = workReqDeptMap[userId];
      }

      final resolvedDepartment = deptName ?? 'No Department';

      return FacultyUserAccount(
        userId: userId,
        email: userMap['email']?.toString() ?? '',
        fullName: userMap['name']?.toString() ?? 'Unnamed',
        employeeId: teacherProfile?['employee_id']?.toString(),
        department: resolvedDepartment,
        position: teacherProfile?['position']?.toString() ?? 'Faculty',
        isActive: userMap['is_active'] == true,
        createdAt: DateTime.tryParse(userMap['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
    }).toList();
  }

  static Future<void> updateFacultyUser({
    required String userId,
    required String fullName,
    required String department,
    required bool isActive,
    String? employeeId,
  }) async {
    await _db.from('users').update({
      'name': fullName,
      'is_active': isActive,
    }).eq('id', userId);

    String? deptId;
    final normalized = department.trim();
    if (normalized.isNotEmpty && normalized != 'No Department' && normalized != 'None') {
      final dept = await DepartmentService.findOrCreateByName(normalized);
      deptId = dept.id;
    }

    final updateData = <String, dynamic>{
      'user_id': userId,
      'department_id': deptId,
      if (employeeId != null && employeeId.trim().isNotEmpty)
        'employee_id': employeeId.trim(),
    };

    await _db.from('teacher_users').upsert(updateData, onConflict: 'user_id');
  }
}
