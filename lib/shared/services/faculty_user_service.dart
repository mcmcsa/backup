import 'package:supabase_flutter/supabase_flutter.dart';

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
    final usersData = await _db
        .from('users')
        .select('id, email, name, is_active, created_at')
        .eq('role', 'teacher')
        .order('created_at', ascending: false);

    final teacherRows = await _db
        .from('teacher_users')
        .select('user_id, department_id, position, employee_id, departments(name)');

    final teacherMap = <String, Map<String, dynamic>>{};
    for (final row in (teacherRows as List)) {
      final data = Map<String, dynamic>.from(row as Map);
      final userId = data['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        teacherMap[userId] = data;
      }
    }

    return (usersData as List).map((row) {
      final userMap = Map<String, dynamic>.from(row as Map);
      final userId = userMap['id']?.toString() ?? '';
      final teacherProfile = teacherMap[userId];
      final departmentMap = teacherProfile?['departments'] is Map
          ? Map<String, dynamic>.from(teacherProfile!['departments'] as Map)
          : null;

      return FacultyUserAccount(
        userId: userId,
        email: userMap['email']?.toString() ?? '',
        fullName: userMap['name']?.toString() ?? '',
        employeeId: teacherProfile?['employee_id']?.toString(),
        department:
          departmentMap?['name']?.toString() ??
          teacherProfile?['department_id']?.toString(),
        position: teacherProfile?['position']?.toString(),
        isActive: userMap['is_active'] == true,
        createdAt:
            DateTime.tryParse(userMap['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }
}
