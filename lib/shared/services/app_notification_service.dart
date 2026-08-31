import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification_model.dart';
import 'work_request_service.dart';
import 'room_service.dart';

class AppNotificationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'app_notifications';

  static String? _nestedText(dynamic map, String key) {
    if (map == null) return null;
    if (map is Map) return map[key]?.toString();
    if (map is List && map.isNotEmpty) {
      final first = map.first;
      if (first is Map) return first[key]?.toString();
    }
    return null;
  }

  static Future<String> _getRoomStr(String workRequestId) async {
    try {
      final response = await _db
          .from('work_requests')
          .select('room_id, room:rooms(code, name), building:buildings(name)')
          .eq('id', workRequestId)
          .maybeSingle();

      if (response != null) {
        final roomId = response['room_id'] as String?;
        final roomMap = response['room'];
        final buildingMap = response['building'];

        final roomName = _nestedText(roomMap, 'name');
        final roomCode = _nestedText(roomMap, 'code');
        final buildingName = _nestedText(buildingMap, 'name');

        if (roomName != null && roomName.isNotEmpty) {
          final label = (roomCode != null && roomCode.isNotEmpty) ? '$roomCode - $roomName' : roomName;
          if (buildingName != null && buildingName.isNotEmpty) {
            return '$label in $buildingName';
          }
          return label;
        }

        // Try fetching the room via RoomService as a fallback
        if (roomId != null && roomId.isNotEmpty) {
          final room = await RoomService.fetchById(roomId);
          if (room != null) {
            final label = room.code.isNotEmpty ? '${room.code} - ${room.name}' : room.name;
            if (buildingName != null && buildingName.isNotEmpty) {
              return '$label in $buildingName';
            }
            return label;
          }
        }
      }
    } catch (_) {}
    return 'the work request';
  }

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
    String? targetPage,
  }) async {
    final payload = {
      'title': _truncate(title),
      'message': _truncate(message),
      'type': type,
      'target_role': normalizeRole(targetRole),
      'work_request_id': workRequestId,
      'target_page': targetPage,
      'is_read': false,
    };

    await _db.from(_table).insert(payload);
  }

  static String _truncate(String? s, {int max = 490}) {
    if (s == null) return '';
    if (s.length <= max) return s;
    return '${s.substring(0, max - 3)}...';
  }

  static Future<void> createForUser({
    required String targetUserId,
    required String title,
    required String message,
    required String type,
    String? workRequestId,
    String? targetPage,
  }) async {
    final payload = {
      'title': _truncate(title),
      'message': _truncate(message),
      'type': type,
      // Keep target_role within DB check-constraint values while using target_user_id for direct delivery.
      'target_role': 'all',
      'target_user_id': targetUserId,
      'work_request_id': workRequestId,
      'target_page': targetPage,
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
    String? targetPage,
  }) async {
    if (targetRoles.isEmpty) return;
    final payload = targetRoles
        .map(
          (r) => {
            'title': _truncate(title),
            'message': _truncate(message),
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
    final roomStr = await _getRoomStr(workRequestId);
    final targetMaintenanceId = assignedMaintenanceId?.trim();
    if (targetMaintenanceId != null && targetMaintenanceId.isNotEmpty) {
      await createForUser(
        targetUserId: targetMaintenanceId,
        title: 'Work Request Approved',
        message:
            'Work request for $roomStr was approved by $adminName and assigned to you.',
        type: 'work_request_approved',
        workRequestId: workRequestId,
      );
      return;
    }

    await createForRole(
      targetRole: 'maintenance',
      title: 'Work Request Approved',
      message:
          'Work request for $roomStr was approved by $adminName. Please check pending assignments.',
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
    final roomStr = await _getRoomStr(workRequestId);
    final normalizedAdminId = adminId?.trim();
    final normalizedRequestorId = requestorId?.trim();
    final futures = <Future<void>>[];

    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: normalizedAdminId,
          title: 'Work Request Accepted by Maintenance',
          message:
              '$maintenanceName accepted work request in $roomStr. Status is now Under Maintenance.',
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
              '$maintenanceName accepted work request in $roomStr. Status is now Under Maintenance.',
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
              'Your request for $roomStr has been accepted by $maintenanceName and is now under maintenance.',
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
    final roomStr = await _getRoomStr(workRequestId);
    final normalizedAdminId = adminId?.trim();

    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      await createForUser(
        targetUserId: normalizedAdminId,
        title: 'Work Request Completion Submitted',
        message:
            '$maintenanceName submitted completion confirmation for $roomStr.',
        type: 'work_request_completion_submitted',
        workRequestId: workRequestId,
      );
      return;
    }

    await createForRole(
      targetRole: 'admin',
      title: 'Work Request Completion Submitted',
      message:
          '$maintenanceName submitted completion confirmation for $roomStr.',
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
    final roomStr = await _getRoomStr(workRequestId);
    final normalizedRequestorId = requestorId?.trim();

    if (normalizedRequestorId != null && normalizedRequestorId.isNotEmpty) {
      await createForUser(
        targetUserId: normalizedRequestorId,
        title: 'Work Request Ready for Your Confirmation',
        message:
            '$adminName signed completion confirmation for $roomStr. You can now review and sign the confirm work request form.',
        type: 'work_request_completion_ready_for_requestor',
        workRequestId: workRequestId,
      );
      return;
    }

    await createForRole(
      targetRole: 'teacher',
      title: 'Work Request Ready for Your Confirmation',
      message:
          '$adminName signed completion confirmation for $roomStr. Please review and sign the confirm work request form.',
      type: 'work_request_completion_ready_for_requestor',
      workRequestId: workRequestId,
    );
  }

  static Future<void> markAsRead(String id) async {
    await _db.from(_table).update({'is_read': true}).eq('id', id);
  }

  static Future<String?> _getRequestorId(String workRequestId) async {
    try {
      final response = await _db
          .from('work_requests')
          .select('requestor_id')
          .eq('id', workRequestId)
          .maybeSingle();
      if (response != null) {
        return response['requestor_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> notifyPreInspectionApproved({
    required String workRequestId,
    required String maintenanceId,
    required String adminName,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    await createForUser(
      targetUserId: maintenanceId,
      title: 'Pre-Inspection Approved',
      message: '$adminName has approved your pre-inspection report for $roomStr. You can now start the repair.',
      type: 'work_request_approved',
      workRequestId: workRequestId,
      targetPage: '/tasks',
    );
    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null) {
      await createForUser(
        targetUserId: requestorId,
        title: 'Pre-Inspection Approved',
        message: 'The pre-inspection report for $roomStr was approved by $adminName. Work will proceed.',
        type: 'work_request_approved',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  static Future<void> notifyPreInspectionDeclined({
    required String workRequestId,
    required String maintenanceId,
    required String adminName,
    required String notes,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    await createForUser(
      targetUserId: maintenanceId,
      title: 'Pre-Inspection Declined',
      message: '$adminName has declined your pre-inspection report for $roomStr. Reason: $notes.',
      type: 'work_request_declined',
      workRequestId: workRequestId,
      targetPage: '/tasks',
    );
    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null) {
      await createForUser(
        targetUserId: requestorId,
        title: 'Work Request Declined',
        message: 'The work request for $roomStr was declined during pre-inspection by $adminName. Reason: $notes.',
        type: 'work_request_declined',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  static Future<void> notifyPostRepairRework({
    required String workRequestId,
    required String maintenanceId,
    required String adminName,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    await createForUser(
      targetUserId: maintenanceId,
      title: 'Post-Repair Rework Required',
      message: '$adminName requested rework on your post-repair report for $roomStr.',
      type: 'work_request_declined',
      workRequestId: workRequestId,
      targetPage: '/tasks',
    );
    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null) {
      await createForUser(
        targetUserId: requestorId,
        title: 'Rework Required',
        message: 'The post-repair evaluation for $roomStr requires rework as decided by $adminName.',
        type: 'work_request_declined',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  static Future<void> notifyPostRepairCompleted({
    required String workRequestId,
    required String maintenanceId,
    required String adminName,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    await createForUser(
      targetUserId: maintenanceId,
      title: 'Post-Repair Completed',
      message: '$adminName marked the repair for $roomStr as completed.',
      type: 'work_request_completed',
      workRequestId: workRequestId,
      targetPage: '/tasks',
    );
    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null) {
      await createForUser(
        targetUserId: requestorId,
        title: 'Work Completed & Verified',
        message: 'The maintenance work for $roomStr has been completed and verified by $adminName.',
        type: 'work_request_completed',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  static Future<void> notifyPreInspectionSubmittedToAdmin({
    required String workRequestId,
    required String maintenanceName,
    String? adminId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    if (adminId != null && adminId.isNotEmpty) {
      await createForUser(
        targetUserId: adminId,
        title: 'Pre-Inspection Submitted',
        message: '$maintenanceName has submitted a pre-inspection report for $roomStr.',
        type: 'pre_inspection_submitted',
        workRequestId: workRequestId,
        targetPage: '/tickets',
      );
    }
    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null) {
      await createForUser(
        targetUserId: requestorId,
        title: 'Pre-Inspection Filed',
        message: 'A pre-inspection report for $roomStr has been filed by $maintenanceName and is awaiting admin review.',
        type: 'work_request_inspected',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  static Future<void> notifyPostRepairSubmittedToAdmin({
    required String workRequestId,
    required String maintenanceName,
    String? adminId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    if (adminId != null && adminId.isNotEmpty) {
      await createForUser(
        targetUserId: adminId,
        title: 'Post-Repair Evaluation Submitted',
        message: '$maintenanceName has submitted a post-repair evaluation for $roomStr.',
        type: 'post_repair_submitted',
        workRequestId: workRequestId,
        targetPage: '/tickets',
      );
    }
    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null) {
      await createForUser(
        targetUserId: requestorId,
        title: 'Post-Repair Submitted',
        message: 'A post-repair evaluation for $roomStr has been submitted by $maintenanceName and is awaiting admin evaluation.',
        type: 'post_repair_submitted',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  static Future<void> notifyNewChatMessage({
    required String targetUserId,
    required String senderName,
    required String chatRoomId,
    required String messageContent,
  }) async {
    String? workRequestId;
    try {
      final response = await _db
          .from('chat_rooms')
          .select('work_request_id')
          .eq('id', chatRoomId)
          .maybeSingle();
      if (response != null) {
        workRequestId = response['work_request_id'] as String?;
      }
    } catch (_) {}

    final roomStr = workRequestId != null ? await _getRoomStr(workRequestId) : 'Chat';
    await createForUser(
      targetUserId: targetUserId,
      title: 'New Message ($roomStr)',
      message: '$senderName: $messageContent',
      type: 'new_chat_message',
      workRequestId: workRequestId,
      targetPage: '/collaboration',
    );
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
    return (data as List?)?.length ?? 0;
  }
}




