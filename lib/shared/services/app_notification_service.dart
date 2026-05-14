import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification_model.dart';

class AppNotificationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'app_notifications';

  static String _visibilityFilter({
    required String normalizedRole,
    required String userId,
  }) {
    return 'target_user_id.eq.$userId,and(target_user_id.is.null,target_role.eq.all),and(target_user_id.is.null,target_role.eq.$normalizedRole)';
  }

  static String normalizeRole(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'teacher':
        return 'teacher';
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
        .or(_visibilityFilter(normalizedRole: normalizedRole, userId: userId))
        .order('created_at', ascending: false);

    return (data as List).map((e) => AppNotification.fromMap(e)).toList();
  }

  static Future<void> createForRole({
    required String targetRole,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
  }) async {
    final payload = {
      'title': title,
      'message': message,
      'type': type,
      'target_role': normalizeRole(targetRole),
      'work_request_id': workRequestId,
      'is_read': false,
    };

    await _db.from(_table).insert(payload);
  }

  static Future<void> createForUser({
    required String targetUserId,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
  }) async {
    final payload = {
      'title': title,
      'message': message,
      'type': type,
      // Keep target_role within DB check-constraint values while using target_user_id for direct delivery.
      'target_role': 'all',
      'target_user_id': targetUserId,
      'work_request_id': workRequestId,
      'is_read': false,
    };

    await _db.from(_table).insert(payload);
  }

  static Future<void> createForRoles({
    required List<String> targetRoles,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
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
            'is_read': false,
          },
        )
        .toList();

    await _db.from(_table).insert(payload);
  }

  /// Notify maintenance when admin approves a work request.
  static Future<void> notifyApprovedToMaintenance({
    required String workRequestId,
    required String adminName,
    String? assignedMaintenanceId,
  }) async {
    final targetMaintenanceId = assignedMaintenanceId?.trim();
    if (targetMaintenanceId != null && targetMaintenanceId.isNotEmpty) {
      await createForUser(
        targetUserId: targetMaintenanceId,
        title: 'Work Request Approved',
        message:
            'Work request $workRequestId was approved by $adminName and assigned to you.',
        type: 'work_request_approved',
        workRequestId: workRequestId,
      );
      return;
    }

    await createForRole(
      targetRole: 'maintenance',
      title: 'Work Request Approved',
      message:
          'Work request $workRequestId was approved by $adminName. Please check pending assignments.',
      type: 'work_request_approved',
      workRequestId: workRequestId,
    );
  }

  /// Notify admin and requestor after maintenance accepts the request.
  static Future<void> notifyAcceptedToAdminAndRequestor({
    required String workRequestId,
    required String maintenanceName,
    String? adminId,
    String? requestorId,
  }) async {
    final normalizedAdminId = adminId?.trim();
    final normalizedRequestorId = requestorId?.trim();
    final futures = <Future<void>>[];

    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: normalizedAdminId,
          title: 'Work Request Accepted by Maintenance',
          message:
              '$maintenanceName accepted work request $workRequestId. Status is now Under Maintenance.',
          type: 'work_request_accepted',
          workRequestId: workRequestId,
        ),
      );
    } else {
      futures.add(
        createForRole(
          targetRole: 'admin',
          title: 'Work Request Accepted by Maintenance',
          message:
              '$maintenanceName accepted work request $workRequestId. Status is now Under Maintenance.',
          type: 'work_request_accepted',
          workRequestId: workRequestId,
        ),
      );
    }

    if (normalizedRequestorId != null && normalizedRequestorId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: normalizedRequestorId,
          title: 'Request Under Maintenance',
          message:
              'Your request $workRequestId has been accepted by $maintenanceName and is now under maintenance.',
          type: 'work_request_accepted',
          workRequestId: workRequestId,
        ),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Notify admin when maintenance submits a completion confirmation signature.
  static Future<void> notifyCompletionSubmittedToAdmin({
    required String workRequestId,
    required String maintenanceName,
    String? adminId,
  }) async {
    final normalizedAdminId = adminId?.trim();

    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      await createForUser(
        targetUserId: normalizedAdminId,
        title: 'Work Request Completion Submitted',
        message:
            '$maintenanceName submitted completion confirmation for work request $workRequestId.',
        type: 'work_request_completion_submitted',
        workRequestId: workRequestId,
      );
      return;
    }

    await createForRole(
      targetRole: 'admin',
      title: 'Work Request Completion Submitted',
      message:
          '$maintenanceName submitted completion confirmation for work request $workRequestId.',
      type: 'work_request_completion_submitted',
      workRequestId: workRequestId,
    );
  }

  /// Notify the reporting user when admin submits completion confirmation signature.
  static Future<void> notifyAdminCompletionSubmittedToRequestor({
    required String workRequestId,
    required String adminName,
    String? requestorId,
  }) async {
    final normalizedRequestorId = requestorId?.trim();

    if (normalizedRequestorId != null && normalizedRequestorId.isNotEmpty) {
      await createForUser(
        targetUserId: normalizedRequestorId,
        title: 'Work Request Ready for Your Confirmation',
        message:
            '$adminName signed completion confirmation for work request $workRequestId. You can now review and sign the confirm work request form.',
        type: 'work_request_completion_ready_for_requestor',
        workRequestId: workRequestId,
      );
      return;
    }

    await createForRole(
      targetRole: 'teacher',
      title: 'Work Request Ready for Your Confirmation',
      message:
          '$adminName signed completion confirmation for work request $workRequestId. Please review and sign the confirm work request form.',
      type: 'work_request_completion_ready_for_requestor',
      workRequestId: workRequestId,
    );
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
        .or(_visibilityFilter(normalizedRole: normalizedRole, userId: userId));
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
        .or(_visibilityFilter(normalizedRole: normalizedRole, userId: userId));
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
        .or(_visibilityFilter(normalizedRole: normalizedRole, userId: userId));
    return (data as List).length;
  }
}
