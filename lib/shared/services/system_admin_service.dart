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
      // 1. Update the base user record
      await _db.from('users').update({
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        'is_active': isActive,
      }).eq('id', id);

      // 2. Manage profile tables based on the updated role
      if (role == 'teacher') {
        // Upsert into teacher_users, delete from maintenance_users
        await _db.from('teacher_users').upsert({
          'user_id': id,
          'department_id': departmentId,
          'position': position?.trim(),
          'employee_id': employeeId?.trim(),
          'phone': phone?.trim(),
        }, onConflict: 'user_id');

        await _db.from('maintenance_users').delete().eq('user_id', id);
      } else if (role == 'maintenance') {
        // Upsert into maintenance_users, delete from teacher_users
        await _db.from('maintenance_users').upsert({
          'user_id': id,
          'specialization': specialization?.trim(),
          'employee_id': employeeId?.trim(),
          'phone': phone?.trim(),
        }, onConflict: 'user_id');

        await _db.from('teacher_users').delete().eq('user_id', id);
      } else {
        // If system admin or campadmin, clean up specific profiles if they exist
        await _db.from('teacher_users').delete().eq('user_id', id);
        await _db.from('maintenance_users').delete().eq('user_id', id);
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Create a new user with any role
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
    SupabaseClient? isolatedClient;
    try {
      // Create an isolated client to avoid overriding the admin's session
      isolatedClient = SupabaseClient(
        dotenv.env['SUPABASE_URL']!,
        dotenv.env['SUPABASE_ANON_KEY']!,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );

      // 1. Call auth signUp to create auth record using the isolated client
      final response = await isolatedClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'role': role,
        },
      );

      final newUser = response.user;
      if (newUser == null) return 'Registration failed.';

      // 2. Create users profile record (it might be created by trigger, but update role/active to be sure)
      await _db.from('users').upsert({
        'id': newUser.id,
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        'is_active': true,
      }, onConflict: 'id');

      // 3. Create role-specific profile records
      if (role == 'teacher') {
        await _db.from('teacher_users').upsert({
          'user_id': newUser.id,
          'department_id': departmentId,
          'position': position?.trim() ?? 'Faculty',
          'employee_id': employeeId?.trim(),
          'phone': phone?.trim(),
        }, onConflict: 'user_id');
      } else if (role == 'maintenance') {
        await _db.from('maintenance_users').upsert({
          'user_id': newUser.id,
          'specialization': specialization?.trim() ?? 'General',
          'employee_id': employeeId?.trim(),
          'phone': phone?.trim(),
        }, onConflict: 'user_id');
      }

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      isolatedClient?.dispose();
    }
  }
}
