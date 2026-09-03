import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../authentication/models/user_model.dart';
import '../../authentication/services/auth_service.dart';

class SystemAdminService {
  static SupabaseClient get _db => Supabase.instance.client;

  // Fetch all users with their role profiles (teacher/maintenance).
  // Role profiles are fetched in separate queries to avoid PostgREST join-level
  // RLS policies that might hide data for inactive users.
  static Future<List<AppUser>> fetchAllUsers() async {
    // 1. Base users table
    final List<dynamic> usersJson = await _db
        .from('users')
        .select('*')
        .order('created_at', ascending: false);

    // 2. Departments lookup
    final deptMap = <String, String>{};
    try {
      final List<dynamic> deptsJson = await _db.from('departments').select('id, name');
      for (final d in deptsJson) {
        if (d is Map && d['id'] != null && d['name'] != null) {
          deptMap[d['id'].toString()] = d['name'].toString();
        }
      }
    } catch (_) {}

    // 3. Teacher profiles (separate query — not filtered by user.is_active)
    final teacherMap = <String, Map<String, dynamic>>{};
    try {
      final List<dynamic> teacherJson = await _db.from('teacher_users').select('*');
      for (final t in teacherJson) {
        if (t is Map && t['user_id'] != null) {
          final row = Map<String, dynamic>.from(t);
          // Resolve department name inline
          final deptId = row['department_id']?.toString();
          if (deptId != null && deptMap.containsKey(deptId)) {
            row['departments'] = {'name': deptMap[deptId]};
          }
          teacherMap[t['user_id'].toString()] = row;
        }
      }
    } catch (_) {}

    // 4. Maintenance profiles (separate query)
    final maintenanceMap = <String, Map<String, dynamic>>{};
    try {
      final List<dynamic> maintJson = await _db.from('maintenance_users').select('*');
      for (final m in maintJson) {
        if (m is Map && m['user_id'] != null) {
          maintenanceMap[m['user_id'].toString()] = Map<String, dynamic>.from(m);
        }
      }
    } catch (_) {}

    // 5. Merge and map to AppUser
    return usersJson.map((json) {
      final map = Map<String, dynamic>.from(json);
      final userId = map['id']?.toString() ?? '';
      if (teacherMap.containsKey(userId)) map['teacher_users'] = teacherMap[userId];
      if (maintenanceMap.containsKey(userId)) map['maintenance_users'] = maintenanceMap[userId];
      return AppUser.fromMap(map, deptMap: deptMap);
    }).toList();
  }

  // Update only the is_active flag — does NOT touch role profiles or any other field.
  static Future<String?> setUserActive(String userId, bool isActive) async {
    try {
      await _db.from('users').update({'is_active': isActive}).eq('id', userId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Update a user's base account. Pass updatePhone:true to write the phone field.
  // Pass updateRoleProfiles:true to also update teacher/maintenance profile tables.
  static Future<String?> updateUserAccount({
    required String id,
    required String email,
    required String name,
    required String role,
    bool? isActive,
    String? departmentId,
    String? position,
    String? employeeId,
    String? phone,
    String? specialization,
    bool updateRoleProfiles = false,
    bool updatePhone = false,
  }) async {
    try {
      // 1. Update public.users profile
      await _db.from('users').update({
        'email': email.trim(),
        'name': name.trim(),
        'role': role,
        if (isActive != null) 'is_active': isActive,
        // Only write phone when the caller explicitly opts in,
        // to prevent silently clearing it when not provided.
        if (updatePhone) 'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      }).eq('id', id);

      // 2. Update role specific tables only when editing profile details
      if (updateRoleProfiles) {
        if (role == 'teacher') {
          await _db.from('teacher_users').upsert({
            'user_id': id,
            'department_id': departmentId,
            'position': position?.trim().isNotEmpty == true ? position!.trim() : null,
            'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
          }, onConflict: 'user_id');
        } else if (role == 'maintenance') {
          await _db.from('maintenance_users').upsert({
            'user_id': id,
            'specialization': specialization?.trim().isNotEmpty == true ? specialization!.trim() : null,
            'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
          }, onConflict: 'user_id');
        }
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
    // ── Step 0: Save admin session tokens BEFORE any auth operations ──────────
    // On Flutter Web, signUp / signInWithPassword on the main Supabase client
    // replaces the current session in the browser. We save the tokens so we
    // can restore the admin session after creating the new user's auth record.
    final adminRefreshToken = _db.auth.currentSession?.refreshToken;

    // Suppress AuthService from reacting to auth state events fired during
    // user creation (prevents redirect to /force-change-password).
    AuthService.beginUserCreation();

    try {
      final normalizedEmail = email.trim().toLowerCase();

      // ── Pre-check: reject if email already exists in public.users ───────────
      final existingUser = await _db
          .from('users')
          .select('id')
          .eq('email', normalizedEmail)
          .maybeSingle();
      if (existingUser != null) {
        return 'An account with this email address already exists.';
      }

      // ── Step 1: Create auth user ─────────────────────────────────────────────
      String? newUserId;
      try {
        final response = await _db.auth.signUp(
          email: normalizedEmail,
          password: password,
          data: {
            'name': name.trim(),
            'role': role,
            'must_change_password': true,
          },
        );
        // signUp signs in as the new user on web — we capture the ID then
        // restore the admin session below.
        newUserId = response.user?.id;
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (!msg.contains('already registered') && !msg.contains('already exists')) {
          return e.message;
        }
      }

      // ── Orphan check ─────────────────────────────────────────────────────────
      // signUp returned null user — the email already exists in Supabase Auth
      // but has no profile in public.users (orphan from a previous failed attempt).
      // We cannot sign in as the orphan without the original password, so we
      // instruct the admin to delete the stale auth entry from the dashboard.
      if (newUserId == null) {
        return 'The email "$normalizedEmail" is already reserved in the '
            'authentication system but has no account profile. '
            'Please go to Supabase Dashboard → Authentication → Users, '
            'delete the entry for this email, then try again.';
      }

      // ── Step 2: Restore the admin session ────────────────────────────────────
      // After signUp/signInWithPassword above, the main Supabase client is now
      // signed in as the new user on web. We restore the admin's tokens so all
      // subsequent DB operations run with admin privileges.
      if (adminRefreshToken != null) {
        try {
          await _db.auth.setSession(adminRefreshToken);
          debugPrint('[SystemAdminService] Admin session restored after user creation.');
        } catch (e) {
          debugPrint('[SystemAdminService] Warning: admin session restore failed: $e');
        }
      }

      // ── Step 3: Create public.users profile ──────────────────────────────────
      try {
        await _db.from('users').upsert({
          'id': newUserId,
          'email': email.trim(),
          'name': name.trim(),
          'role': role,
          'is_active': true,
          'must_change_password': true,
          'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
        }, onConflict: 'id');
      } catch (_) {
        // Fallback: insert without must_change_password column
        await _db.from('users').upsert({
          'id': newUserId,
          'email': email.trim(),
          'name': name.trim(),
          'role': role,
          'is_active': true,
          'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
        }, onConflict: 'id');
      }

      // ── Step 4: Create role-specific profile ─────────────────────────────────
      if (role == 'teacher') {
        await _db.from('teacher_users').upsert({
          'user_id': newUserId,
          'department_id': departmentId,
          'position': position?.trim().isNotEmpty == true ? position!.trim() : null,
          'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
        }, onConflict: 'user_id');
      } else if (role == 'maintenance') {
        await _db.from('maintenance_users').upsert({
          'user_id': newUserId,
          'specialization': specialization?.trim().isNotEmpty == true ? specialization!.trim() : null,
          'employee_id': employeeId?.trim().isNotEmpty == true ? employeeId!.trim() : null,
        }, onConflict: 'user_id');
      }

      debugPrint('[SystemAdminService] User $normalizedEmail created successfully.');
      return null;
    } catch (e) {
      // On any error, still try to restore admin session
      if (adminRefreshToken != null) {
        try {
          await _db.auth.setSession(adminRefreshToken);
        } catch (_) {}
      }
      return e.toString();
    } finally {
      // Always resume auth state handling — the admin session has been restored
      // above so any subsequent auth events will process for the admin.
      AuthService.endUserCreation();
    }
  }
}
