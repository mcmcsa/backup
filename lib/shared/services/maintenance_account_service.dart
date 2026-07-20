import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MaintenanceAccount {
  final String userId;
  final String email;
  final String fullName;
  final String? employeeId;
  final String? specialization;
  final String? contactNo;
  final bool isActive;
  final DateTime? archivedAt;
  final DateTime createdAt;
  
  // Availability Fields
  final String availabilityStatus;
  final String? currentLocation;
  final String? currentAssignmentId;
  final DateTime? estimatedCompletionTime;
  final DateTime? lastActiveAt;
  final String? workingHoursStart;
  final String? workingHoursEnd;
  final DateTime? statusUpdatedAt;

  const MaintenanceAccount({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.employeeId,
    required this.specialization,
    required this.contactNo,
    required this.isActive,
    required this.archivedAt,
    required this.createdAt,
    this.availabilityStatus = 'offline',
    this.currentLocation,
    this.currentAssignmentId,
    this.estimatedCompletionTime,
    this.lastActiveAt,
    this.workingHoursStart,
    this.workingHoursEnd,
    this.statusUpdatedAt,
  });
}


class MaintenanceAccountService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<String?> _recoverOrphanMaintenanceAuth({
    required String email,
    required String fullName,
    required String employeeId,
    required String specialization,
    String? contactNo,
    required String password,
  }) async {
    final isolatedClient = SupabaseClient(
      dotenv.env['SUPABASE_URL']!,
      dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

    try {
      final currentUser = _db.auth.currentUser;

      if (currentUser == null) {
        return 'Admin session not found. Please login again.';
      }

      final authResponse = await isolatedClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final orphanedUser = authResponse.user;
      if (orphanedUser == null) {
        return 'Could not recover account. Password may be incorrect.';
      }

      await _db.from('users').upsert({
        'id': orphanedUser.id,
        'email': email,
        'name': fullName.trim(),
        'role': 'maintenance',
        'is_active': true,
      }, onConflict: 'id');

      try {
        await _db.from('maintenance_users').insert({
          'user_id': orphanedUser.id,
          'employee_id': (employeeId.trim().isEmpty ? null : employeeId.trim()),
          'specialization': (specialization.trim().isEmpty
              ? null
              : specialization.trim()),
          'phone': ((contactNo ?? '').trim().isEmpty
              ? null
              : contactNo!.trim()),
          'created_by_admin_id': currentUser.id,
        });
      } catch (profileErr) {
        print('Warning: Could not create maintenance profile: $profileErr');
      }

      return null;
    } catch (err) {
      print('Error recovering orphaned account: $err');
      return 'Unable to recover account: $err';
    } finally {
      isolatedClient.dispose();
    }
  }

  static Future<Map<String, dynamic>?> _findUserByEmail(
    String normalizedEmail,
  ) async {
    return await _db
        .from('users')
        .select('id, role, is_active')
        .eq('email', normalizedEmail)
        .maybeSingle();
  }

  static Map<String, dynamic>? _extractMaintenanceProfile(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<bool> _emailExists(String normalizedEmail) async {
    final rows = await _db
        .from('users')
        .select('id')
        .eq('email', normalizedEmail)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  static Future<bool> _emailExistsForOtherUser(
    String normalizedEmail,
    String userId,
  ) async {
    final rows = await _db
        .from('users')
        .select('id')
        .eq('email', normalizedEmail)
        .neq('id', userId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  static Future<bool> _maintenanceIdExists(String maintenanceId) async {
    final activeRows = await _db
        .from('maintenance_users')
        .select('user_id')
        .eq('employee_id', maintenanceId)
        .limit(1);

    return (activeRows as List).isNotEmpty;
  }

  static Future<bool> _maintenanceIdExistsForOtherUser(
    String maintenanceId,
    String userId,
  ) async {
    final activeRows = await _db
        .from('maintenance_users')
        .select('user_id')
        .eq('employee_id', maintenanceId)
        .neq('user_id', userId)
        .limit(1);

    return (activeRows as List).isNotEmpty;
  }

  static Future<List<MaintenanceAccount>> fetchCreatedByCurrentAdmin() async {
    return _fetchByArchiveState(includeArchived: false);
  }

  static Future<List<MaintenanceAccount>> fetchArchivedByCurrentAdmin() async {
    return _fetchByArchiveState(includeArchived: true);
  }

  static Future<List<MaintenanceAccount>> _fetchByArchiveState({
    required bool includeArchived,
  }) async {
    try {
      final data = await _db.rpc(
        'get_admin_maintenance_accounts',
        params: {'include_archived': includeArchived},
      );

      final list = data is List ? data : <dynamic>[];
      final mapped = <MaintenanceAccount>[];
      for (final row in list) {
        final map = _asMap(row);
        if (map == null) continue;

        mapped.add(
          MaintenanceAccount(
            userId: map['user_id']?.toString() ?? '',
            email: map['email']?.toString() ?? '',
            fullName: map['full_name']?.toString() ?? '',
            employeeId: map['employee_id']?.toString(),
            specialization: map['specialization']?.toString(),
            contactNo: map['phone']?.toString(),
            isActive: map['is_active'] == true,
            archivedAt: DateTime.tryParse(map['archived_at']?.toString() ?? ''),
            createdAt:
                DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.now(),
            availabilityStatus: map['availability_status']?.toString() ?? 'offline',
            currentLocation: map['current_location']?.toString(),
            currentAssignmentId: map['current_assignment_id']?.toString(),
            estimatedCompletionTime: DateTime.tryParse(map['estimated_completion_time']?.toString() ?? ''),
            lastActiveAt: DateTime.tryParse(map['last_active_at']?.toString() ?? ''),
            workingHoursStart: map['working_hours_start']?.toString(),
            workingHoursEnd: map['working_hours_end']?.toString(),
            statusUpdatedAt: DateTime.tryParse(map['status_updated_at']?.toString() ?? ''),
          ),
        );
      }

      if (mapped.isNotEmpty) {
        return mapped;
      }
    } on PostgrestException catch (e) {
      print(
        'RPC Error get_admin_maintenance_accounts (includeArchived=$includeArchived): ${e.message}',
      );
      // Fall back to direct-table queries below.
    }

    if (includeArchived) {
      // Fallback for archived list when RPC/schema is out-of-sync:
      // show inactive maintenance users created by the current admin.
      return _fetchArchivedFallback();
    }

    // Fallback for active list when RPC is missing/failing or returns empty.
    return _fetchActiveFallback();
  }

  static Future<List<MaintenanceAccount>> _fetchActiveFallback() async {
    final rows = await _db
        .from('users')
        .select(
          'id, email, name, is_active, created_at, maintenance:maintenance_users!maintenance_users_user_id_fkey(employee_id, specialization, phone, created_at, availability_status, current_location, current_assignment_id, estimated_completion_time, last_active_at, working_hours_start, working_hours_end, status_updated_at)',
        )
        .eq('role', 'maintenance')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    final list = rows;
    final mapped = <MaintenanceAccount>[];

    for (final row in list) {
      final map = _asMap(row);
      if (map == null) continue;
      final maintenance = _extractMaintenanceProfile(map['maintenance']);

      mapped.add(
        MaintenanceAccount(
          userId: map['id']?.toString() ?? '',
          email: map['email']?.toString() ?? '',
          fullName: map['name']?.toString() ?? '',
          employeeId: maintenance?['employee_id']?.toString(),
          specialization: maintenance?['specialization']?.toString(),
          contactNo: maintenance?['phone']?.toString(),
          isActive: map['is_active'] == true,
          archivedAt: null,
          createdAt:
              DateTime.tryParse(
                maintenance?['created_at']?.toString() ??
                    map['created_at']?.toString() ??
                    '',
              ) ??
              DateTime.now(),
          availabilityStatus: maintenance?['availability_status']?.toString() ?? 'offline',
          currentLocation: maintenance?['current_location']?.toString(),
          currentAssignmentId: maintenance?['current_assignment_id']?.toString(),
          estimatedCompletionTime: DateTime.tryParse(maintenance?['estimated_completion_time']?.toString() ?? ''),
          lastActiveAt: DateTime.tryParse(maintenance?['last_active_at']?.toString() ?? ''),
          workingHoursStart: maintenance?['working_hours_start']?.toString(),
          workingHoursEnd: maintenance?['working_hours_end']?.toString(),
          statusUpdatedAt: DateTime.tryParse(maintenance?['status_updated_at']?.toString() ?? ''),
        ),
      );
    }

    return mapped;
  }

  static Future<List<MaintenanceAccount>> _fetchArchivedFallback() async {
    final rows = await _db
        .from('users')
        .select(
          'id, email, name, is_active, created_at, maintenance:maintenance_users!maintenance_users_user_id_fkey(employee_id, specialization, phone, created_at, availability_status, current_location, current_assignment_id, estimated_completion_time, last_active_at, working_hours_start, working_hours_end, status_updated_at)',
        )
        .eq('role', 'maintenance')
        .eq('is_active', false)
        .order('created_at', ascending: false);

    final list = rows;
    final mapped = <MaintenanceAccount>[];

    for (final row in list) {
      final map = _asMap(row);
      if (map == null) continue;
      final maintenance = _extractMaintenanceProfile(map['maintenance']);

      mapped.add(
        MaintenanceAccount(
          userId: map['id']?.toString() ?? '',
          email: map['email']?.toString() ?? '',
          fullName: map['name']?.toString() ?? '',
          employeeId: maintenance?['employee_id']?.toString(),
          specialization: maintenance?['specialization']?.toString(),
          contactNo: maintenance?['phone']?.toString(),
          isActive: map['is_active'] == true,
          archivedAt: null,
          createdAt:
              DateTime.tryParse(
                maintenance?['created_at']?.toString() ??
                    map['created_at']?.toString() ??
                    '',
              ) ??
              DateTime.now(),
          availabilityStatus: maintenance?['availability_status']?.toString() ?? 'offline',
          currentLocation: maintenance?['current_location']?.toString(),
          currentAssignmentId: maintenance?['current_assignment_id']?.toString(),
          estimatedCompletionTime: DateTime.tryParse(maintenance?['estimated_completion_time']?.toString() ?? ''),
          lastActiveAt: DateTime.tryParse(maintenance?['last_active_at']?.toString() ?? ''),
          workingHoursStart: maintenance?['working_hours_start']?.toString(),
          workingHoursEnd: maintenance?['working_hours_end']?.toString(),
          statusUpdatedAt: DateTime.tryParse(maintenance?['status_updated_at']?.toString() ?? ''),
        ),
      );
    }

    return mapped;
  }

  static Future<int> fetchTeacherUserCount() async {
    final data = await _db.rpc('get_admin_teacher_count');
    if (data is int) return data;
    return int.tryParse(data.toString()) ?? 0;
  }

  static Future<String?> createMaintenanceAccount({
    required String email,
    required String fullName,
    required String employeeId,
    required String specialization,
    String? contactNo,
    required String password,
  }) async {
    final currentUser = _db.auth.currentUser;
    if (currentUser == null) {
      return 'Admin session not found. Please login again.';
    }

    final isolatedClient = SupabaseClient(
      dotenv.env['SUPABASE_URL']!,
      dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedMaintenanceId = employeeId.trim();

      if (await _emailExists(normalizedEmail)) {
        final existingUser = await _findUserByEmail(normalizedEmail);
        if (existingUser != null && existingUser['role'] == 'maintenance') {
          final isActive = existingUser['is_active'] == true;
          if (!isActive) {
            return 'This email belongs to an archived maintenance account. Restore it from Archived tab.';
          }
        }
        return 'This Email is Already Use';
      }

      if (await _maintenanceIdExists(normalizedMaintenanceId)) {
        return 'This ID is Already Exist';
      }

      final adminProfile = await _db
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (adminProfile == null || adminProfile['role'] != 'admin') {
        return 'Only admin can create maintenance accounts.';
      }

      final response = await isolatedClient.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'name': fullName.trim(), 'role': 'maintenance'},
      );

      final newUser = response.user;
      if (newUser == null) {
        return 'Failed to create maintenance account.';
      }

      await _db.from('users').update({'is_active': true}).eq('id', newUser.id);

      await _db.from('maintenance_users').upsert({
        'user_id': newUser.id,
        'employee_id': normalizedMaintenanceId,
        'specialization': specialization.trim(),
        'phone': (contactNo ?? '').trim().isEmpty ? null : contactNo!.trim(),
        'created_by_admin_id': currentUser.id,
      }, onConflict: 'user_id');
      return null;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already') || msg.contains('registered')) {
        final normalizedEmail = email.trim().toLowerCase();
        final existingUser = await _findUserByEmail(normalizedEmail);
        if (existingUser == null) {
          return await _recoverOrphanMaintenanceAuth(
            email: normalizedEmail,
            fullName: fullName.trim(),
            employeeId: employeeId.trim(),
            specialization: specialization.trim(),
            contactNo: contactNo,
            password: password,
          );
        }
        return 'This Email is Already Use';
      }
      if (msg.contains('database error saving new user')) {
        return 'Unable to create account due to database policy restrictions. Please try again after migration update.';
      }
      return e.message;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('maintenance id already exists') ||
          (msg.contains('employee_id') && msg.contains('duplicate'))) {
        return 'This ID is Already Exist';
      }
      if (msg.contains('users_email_key') ||
          (msg.contains('email') && msg.contains('duplicate'))) {
        return 'This Email is Already Use';
      }
      return e.message;
    } catch (_) {
      return 'Unable to create maintenance account right now.';
    } finally {
      isolatedClient.dispose();
    }
  }

  static Future<String?> updateMaintenanceAccount({
    required String userId,
    required String email,
    required String fullName,
    required String employeeId,
    required String specialization,
    String? contactNo,
  }) async {
    final currentUser = _db.auth.currentUser;
    if (currentUser == null) {
      return 'Admin session not found. Please login again.';
    }

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedMaintenanceId = employeeId.trim();

      if (await _emailExistsForOtherUser(normalizedEmail, userId)) {
        return 'This Email is Already Use';
      }

      if (await _maintenanceIdExistsForOtherUser(
        normalizedMaintenanceId,
        userId,
      )) {
        return 'This ID is Already Exist';
      }

      final maintenanceRow = await _db
          .from('maintenance_users')
          .select('created_by_admin_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (maintenanceRow == null) {
        final userRow = await _db
            .from('users')
            .select('id, role')
            .eq('id', userId)
            .maybeSingle();

        if (userRow == null || userRow['role'] != 'maintenance') {
          return 'Maintenance account not found.';
        }
      }

      // Allow any admin to edit any maintenance account
      // (removed ownership check since we show all accounts)

      await _db
          .from('users')
          .update({'email': normalizedEmail, 'name': fullName.trim()})
          .eq('id', userId);

      await _db
          .from('maintenance_users')
          .upsert({
            'user_id': userId,
            'created_by_admin_id': currentUser.id,
            'employee_id': normalizedMaintenanceId,
            'specialization': specialization.trim(),
            'phone': (contactNo ?? '').trim().isEmpty
                ? null
                : contactNo!.trim(),
          }, onConflict: 'user_id')
          .eq('user_id', userId);

      return null;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('maintenance id already exists') ||
          (msg.contains('employee_id') && msg.contains('duplicate'))) {
        return 'This ID is Already Exist';
      }
      if (msg.contains('users_email_key') ||
          (msg.contains('email') && msg.contains('duplicate'))) {
        return 'This Email is Already Use';
      }
      return e.message;
    } catch (_) {
      return 'Unable to update maintenance account right now.';
    }
  }

  static Future<String?> archiveMaintenanceAccount(String userId) async {
    final currentUser = _db.auth.currentUser;
    if (currentUser == null) {
      return 'Admin session not found. Please login again.';
    }

    try {
      await _db.rpc('archive_maintenance_account', params: {'p_user_id': userId});

      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unable to archive maintenance account right now.';
    }
  }

  static Future<String?> restoreMaintenanceAccount(String userId) async {
    final currentUser = _db.auth.currentUser;
    if (currentUser == null) {
      return 'Admin session not found. Please login again.';
    }

    try {
      await _db.rpc('restore_maintenance_account', params: {'p_user_id': userId});

      return null;
    } catch (_) {
      return 'Unable to restore maintenance account right now.';
    }
  }

  static Future<List<MaintenanceAccount>> fetchAllActiveMaintenance() async {
    try {
      return await _fetchByArchiveState(includeArchived: false);
    } catch (e) {
      print('Error fetching active maintenance: $e');
      return [];
    }
  }

  static Future<List<MaintenanceAccount>> fetchAllArchivedMaintenance() async {
    try {
      final rows = await _db
          .from('users')
          .select(
            'id, email, name, is_active, created_at, maintenance:maintenance_users!maintenance_users_user_id_fkey(employee_id, specialization, phone, created_at)',
          )
          .eq('role', 'maintenance')
          .eq('is_active', false)
          .order('created_at', ascending: false);

      final list = rows;
      final mapped = <MaintenanceAccount>[];

      for (final row in list) {
        final map = _asMap(row);
        if (map == null) continue;
        final maintenance = _extractMaintenanceProfile(map['maintenance']);

        mapped.add(
          MaintenanceAccount(
            userId: map['id']?.toString() ?? '',
            email: map['email']?.toString() ?? '',
            fullName: map['name']?.toString() ?? '',
            employeeId: maintenance?['employee_id']?.toString(),
            specialization: maintenance?['specialization']?.toString(),
            contactNo: maintenance?['phone']?.toString(),
            isActive: false,
            archivedAt: null,
            createdAt:
                DateTime.tryParse(
                  maintenance?['created_at']?.toString() ??
                      map['created_at']?.toString() ??
                      '',
                ) ??
                DateTime.now(),
          ),
        );
      }

      return mapped;
    } catch (e) {
      print('Error fetching archived maintenance: $e');
      return [];
    }
  }
}
