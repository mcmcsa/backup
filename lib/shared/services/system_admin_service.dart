import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../authentication/models/user_model.dart';

class SystemAdminService {
  static SupabaseClient get _db => Supabase.instance.client;

  // Fetch all users with their associated profile details (teacher or maintenance info)
  static Future<List<AppUser>> fetchAllUsers() async {
    final List<dynamic> usersJson = await _db
        .from('users')
        .select('*, teacher_users(*, departments(name)), maintenance_users!maintenance_users_user_id_fkey(*)')
        .order('created_at', ascending: false);

    return usersJson
        .map((json) => AppUser.fromMap(Map<String, dynamic>.from(json)))
        .toList();
  }

  // Update any user's base account and specific profile info
  static Future<String?> updateUserAccount({
    required String id,
    required String email,
    required String name,
    required String role,
    required bool isActive,
    String? departmentId,
    String? position,
    String? employeeId,
    String? phone,
    String? specialization,
  }) async {
    try {
      // 1. Update public.users profile
      await _db.from('users').update({
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        'is_active': isActive,
        'phone': phone?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // 2. Update role specific tables
      if (role == 'teacher') {
        await _db.from('teacher_users').upsert({
          'user_id': id,
          'department_id': departmentId,
          'position': position?.trim() ?? 'Faculty',
          'employee_id': employeeId?.trim(),
        }, onConflict: 'user_id');
      } else if (role == 'maintenance') {
        await _db.from('maintenance_users').upsert({
          'user_id': id,
          'specialization': specialization?.trim() ?? 'General',
          'employee_id': employeeId?.trim(),
        }, onConflict: 'user_id');
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Create a brand new user account (both auth and profile)
  static Future<String?> createUserAccount({
    required String email,
    required String password,
    required String name,
    required String role,
    String? departmentId,
    String? position,
    String? employeeId,
    String? phone,
    String? specialization,
  }) async {
    try {
      final url = '${dotenv.env['SUPABASE_URL']}/auth/v1/signup';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'apikey': dotenv.env['SUPABASE_ANON_KEY']!,
          'Authorization': 'Bearer ${dotenv.env['SUPABASE_ANON_KEY']!}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': {
            'name': name.trim(),
            'role': role,
          },
        }),
      );

      if (response.statusCode >= 400) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        return errorData['message'] ?? errorData['msg'] ?? 'Registration failed.';
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final userMap = responseData['user'] as Map<String, dynamic>?;
      if (userMap == null) return 'Registration failed: no user data returned.';
      final newUserId = userMap['id'] as String?;
      if (newUserId == null) return 'Registration failed: user ID missing.';

      // 2. Create users profile record (it might be created by trigger, but update role/active to be sure)
      await _db.from('users').upsert({
        'id': newUserId,
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        'is_active': true,
        'phone': phone?.trim(),
      }, onConflict: 'id');

      // 3. Create role-specific profile records
      if (role == 'teacher') {
        await _db.from('teacher_users').upsert({
          'user_id': newUserId,
          'department_id': departmentId,
          'position': position?.trim() ?? 'Faculty',
          'employee_id': employeeId?.trim(),
        }, onConflict: 'user_id');
      } else if (role == 'maintenance') {
        await _db.from('maintenance_users').upsert({
          'user_id': newUserId,
          'specialization': specialization?.trim() ?? 'General',
          'employee_id': employeeId?.trim(),
        }, onConflict: 'user_id');
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
