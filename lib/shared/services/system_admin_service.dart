import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../authentication/models/user_model.dart';
import '../../config/supabase_config.dart';

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
        'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      }).eq('id', id);

      // 2. Update role specific tables
      if (role == 'teacher') {
        await _db.from('teacher_users').upsert({
          'user_id': id,
          'department_id': departmentId,
          'position': position?.trim().isNotEmpty == true ? position!.trim() : 'Faculty',
          'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
        }, onConflict: 'user_id');
      } else if (role == 'maintenance') {
        await _db.from('maintenance_users').upsert({
          'user_id': id,
          'specialization': specialization?.trim().isNotEmpty == true ? specialization!.trim() : 'General',
          'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
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
      final isEnvInitialized = dotenv.isInitialized;
      final url = (isEnvInitialized && dotenv.env['SUPABASE_URL']?.isNotEmpty == true)
          ? dotenv.env['SUPABASE_URL']!
          : supabaseUrl;
      final anonKey = (isEnvInitialized && dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true)
          ? dotenv.env['SUPABASE_ANON_KEY']!
          : supabaseAnonKey;

      final isolatedClient = SupabaseClient(url, anonKey);

      final response = await isolatedClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
          'role': role,
        },
      );

      final newUserId = response.user?.id;
      if (newUserId == null) {
        isolatedClient.dispose();
        return 'Registration failed: user creation returned no result.';
      }

      // 2. Create users profile record (it might be created by trigger, but update role/active to be sure)
      await _db.from('users').upsert({
        'id': newUserId,
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        'is_active': true,
        'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      }, onConflict: 'id');

      // 3. Create role-specific profile records
      if (role == 'teacher') {
        await _db.from('teacher_users').upsert({
          'user_id': newUserId,
          'department_id': departmentId,
          'position': position?.trim().isNotEmpty == true ? position!.trim() : 'Faculty',
          'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
        }, onConflict: 'user_id');
      } else if (role == 'maintenance') {
        await _db.from('maintenance_users').upsert({
          'user_id': newUserId,
          'specialization': specialization?.trim().isNotEmpty == true ? specialization!.trim() : 'General',
          'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
        }, onConflict: 'user_id');
      }

      isolatedClient.dispose();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}

