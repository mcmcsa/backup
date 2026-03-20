import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification_model.dart';

class AppNotificationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'app_notifications';

  static String normalizeRole(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'studentteacher':
      case 'student_teacher':
        return 'student_teacher';
      case 'admin':
        return 'admin';
      case 'maintenance':
        return 'maintenance';
      default:
        return roleName.toLowerCase();
    }
  }

  static Future<List<AppNotification>> fetchForUser({
    required String role,
    required String userId,
  }) async {
    final normalizedRole = normalizeRole(role);
    final data = await _db
        .from(_table)
        .select()
        .or(
          'target_role.eq.all,target_role.eq.$normalizedRole,target_user_id.eq.$userId',
        )
        .order('created_at', ascending: false);

    return (data as List).map((e) => AppNotification.fromMap(e)).toList();
  }

  static Future<void> createForRole({
    required String targetRole,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
    String? statusSnapshot,
  }) async {
    await _db.from(_table).insert({
      'title': title,
      'message': message,
      'type': type,
      'target_role': normalizeRole(targetRole),
      'work_request_id': workRequestId,
      'status_snapshot': statusSnapshot,
      'is_read': false,
    });
  }

  static Future<void> createForUser({
    required String targetUserId,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
    String? statusSnapshot,
  }) async {
    await _db.from(_table).insert({
      'title': title,
      'message': message,
      'type': type,
      'target_role': 'direct',
      'target_user_id': targetUserId,
      'work_request_id': workRequestId,
      'status_snapshot': statusSnapshot,
      'is_read': false,
    });
  }

  static Future<void> createForRoles({
    required List<String> targetRoles,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
    String? statusSnapshot,
  }) async {
    if (targetRoles.isEmpty) return;
    final payload = targetRoles
        .map(
          (r) => {
            'title': title,
            'message': message,
            'type': type,
            'target_role': normalizeRole(r),
            'work_request_id': workRequestId,
            'status_snapshot': statusSnapshot,
            'is_read': false,
          },
        )
        .toList();

    await _db.from(_table).insert(payload);
  }

  static Future<void> markAsRead(String id) async {
    await _db.from(_table).update({'is_read': true}).eq('id', id);
  }

  static Future<void> markAllAsRead({
    required String role,
    required String userId,
  }) async {
    final normalizedRole = normalizeRole(role);
    await _db
        .from(_table)
        .update({'is_read': true})
        .or(
          'target_role.eq.all,target_role.eq.$normalizedRole,target_user_id.eq.$userId',
        );
  }

  static Future<void> markWorkRequestAsRead({
    required String role,
    required String userId,
    required String workRequestId,
  }) async {
    final normalizedRole = normalizeRole(role);
    await _db
        .from(_table)
        .update({'is_read': true})
        .eq('work_request_id', workRequestId)
        .eq('is_read', false)
        .or(
          'target_role.eq.all,target_role.eq.$normalizedRole,target_user_id.eq.$userId',
        );
  }

  static Future<int> getUnreadCount({
    required String role,
    required String userId,
  }) async {
    final normalizedRole = normalizeRole(role);
    final data = await _db
        .from(_table)
        .select('id')
        .eq('is_read', false)
        .or(
          'target_role.eq.all,target_role.eq.$normalizedRole,target_user_id.eq.$userId',
        );
    return (data as List).length;
  }
}
