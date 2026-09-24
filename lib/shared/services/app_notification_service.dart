import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification_model.dart';
import 'app_settings_service.dart';
import 'email_notification_service.dart';
import 'room_service.dart';

class AppNotificationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'app_notifications';

  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  static Stream<void> get changes => _changesController.stream;

  static void notifyChange() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  /// Centralized Supabase Realtime subscription for the notifications table
  static RealtimeChannel subscribeToNotifications({
    required VoidCallback onUpdate,
  }) {
    final channelName =
        'realtime:app_notifs_${DateTime.now().millisecondsSinceEpoch}';
    final channel = _db.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) {
            notifyChange();
            onUpdate();
          },
        )
        .subscribe();

    return channel;
  }

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
          .select('room_id, room_name, room_code, building_name, title, room:rooms(code, name), building:buildings(name)')
          .eq('id', workRequestId)
          .maybeSingle();

      if (response != null) {
        final roomId = response['room_id'] as String?;
        final directRoomName = response['room_name'] as String?;
        final directRoomCode = response['room_code'] as String?;
        final directBuildingName = response['building_name'] as String?;
        final directTitle = response['title'] as String?;

        final roomMap = response['room'];
        final buildingMap = response['building'];

        final roomName = directRoomName?.isNotEmpty == true
            ? directRoomName
            : _nestedText(roomMap, 'name');
        final roomCode = directRoomCode?.isNotEmpty == true
            ? directRoomCode
            : _nestedText(roomMap, 'code');
        final buildingName = directBuildingName?.isNotEmpty == true
            ? directBuildingName
            : _nestedText(buildingMap, 'name');

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

        if (directTitle != null && directTitle.trim().isNotEmpty) {
          return directTitle.trim();
        }
      }
    } catch (_) {}
    return 'the work request';
  }

  static String _visibilityFilter({
    required String normalizedRole,
    required String userId,
  }) {
    if (normalizedRole == 'campadmin' || normalizedRole == 'admin') {
      return 'target_user_id.eq.$userId,and(target_user_id.is.null,target_role.in.(all,admin,campadmin))';
    }
    if (normalizedRole == 'maintenance') {
      // Maintenance users only see personal notifications and global announcements.
      // Unassigned or pending work request notifications are never shown.
      return 'target_user_id.eq.$userId,and(target_user_id.is.null,target_role.eq.all)';
    }
    return 'target_user_id.eq.$userId,and(target_user_id.is.null,target_role.eq.all),and(target_user_id.is.null,target_role.eq.$normalizedRole)';
  }

  static String normalizeRole(String roleName) {
    switch (roleName.toLowerCase().trim()) {
      case 'teacher':
      case 'faculty':
        return 'teacher';
      case 'admin':
        return 'admin';
      case 'campadmin':
      case 'campus_admin':
        return 'campadmin';
      case 'maintenance':
        return 'maintenance';
      case 'all':
      case 'everyone':
        return 'all';
      default:
        return roleName.toLowerCase().trim();
    }
  }

  static Future<List<AppNotification>> fetchForUser({
    required String role,
    required String userId,
    bool ignoreSettings = false,
  }) async {
    if (!ignoreSettings) {
      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: userId);
      if (!isEnabled) {
        return [];
      }
    }
    final normalizedRole = normalizeRole(role);
    final data = await _db
        .from(_table)
        .select()
        .or(_visibilityFilter(normalizedRole: normalizedRole, userId: userId))
        .order('created_at', ascending: false);

    var raw = (data as List).map((e) => AppNotification.fromMap(e)).toList();
    if (normalizedRole == 'maintenance') {
      raw = raw.where((notif) {
        final t = notif.type.toLowerCase();
        final title = notif.title.toLowerCase();
        final msg = notif.message.toLowerCase();
        // Never notify maintenance about submitted or pending work requests
        if (t == 'work_request_submitted') return false;
        if (title.contains('work request submitted') || title.contains('new work request')) return false;
        if (msg.contains('pending admin review') || msg.contains('pending review') || msg.contains('pending approval')) return false;
        return true;
      }).toList();
    }
    return deduplicateNotifications(raw);
  }

  static String _actionGroup(String type, String title) {
    final t = type.toLowerCase();
    final ttl = title.toLowerCase();
    if (t == 'work_request_accepted' ||
        ttl.contains('accepted') ||
        ttl.contains('under maintenance')) {
      return 'accepted';
    }
    if (t == 'pre_inspection_submitted' ||
        t == 'work_request_inspected' ||
        ttl.contains('pre-inspection') ||
        ttl.contains('pre inspection')) {
      return 'pre_inspection';
    }
    if (t == 'post_repair_submitted' ||
        t == 'work_request_repaired' ||
        ttl.contains('post-repair') ||
        ttl.contains('post repair')) {
      return 'post_repair';
    }
    if (t == 'work_request_completed' ||
        t == 'work_request_finished' ||
        ttl.contains('completed') ||
        ttl.contains('verified')) {
      return 'completed';
    }
    if (t == 'work_request_declined' ||
        ttl.contains('declined') ||
        ttl.contains('rejected')) {
      return 'declined';
    }
    if (t == 'work_request_approved' || ttl.contains('approved')) {
      return 'approved';
    }
    if (t == 'work_request_submitted' || ttl.contains('submitted')) {
      return 'submitted';
    }
    return t;
  }

  /// Deduplicate notifications to prevent duplicate alerts from dual dispatch,
  /// role broadcasts, or concurrent events.
  static List<AppNotification> deduplicateNotifications(List<AppNotification> list) {
    final result = <AppNotification>[];
    for (final notif in list) {
      final isDuplicate = result.any((existing) {
        final isExistingChat = existing.type == 'chat' ||
            existing.type == 'chat_message' ||
            existing.type == 'new_chat_message';
        final isNotifChat = notif.type == 'chat' ||
            notif.type == 'chat_message' ||
            notif.type == 'new_chat_message';

        if (isExistingChat && isNotifChat) {
          if (existing.targetUserId != notif.targetUserId) return false;
          final sameRoom = (existing.chatRoomId != null &&
                  existing.chatRoomId == notif.chatRoomId) ||
              (existing.targetPage != null &&
                  existing.targetPage == notif.targetPage);
          if (sameRoom) {
            final timeDiff = existing.createdAt.difference(notif.createdAt).abs();
            if (existing.message == notif.message && timeDiff.inMinutes < 10) {
              return true;
            }
            if (timeDiff.inSeconds <= 5) {
              return true;
            }
          }
        }

        // 1. Same work ticket and same workflow transition within 15 minutes
        if (existing.workRequestId != null &&
            notif.workRequestId != null &&
            existing.workRequestId == notif.workRequestId) {
          final group1 = _actionGroup(existing.type, existing.title);
          final group2 = _actionGroup(notif.type, notif.title);
          if (group1 == group2) {
            final timeDiff = existing.createdAt.difference(notif.createdAt).abs();
            if (timeDiff.inMinutes <= 15) {
              return true;
            }
          }
        }

        // 2. Exact same message within 15 minutes
        if (existing.message.trim().isNotEmpty &&
            existing.message.trim() == notif.message.trim()) {
          final timeDiff = existing.createdAt.difference(notif.createdAt).abs();
          if (timeDiff.inMinutes <= 15) {
            return true;
          }
        }

        // 3. Same title and same ticket within 15 minutes
        if (existing.title.trim().isNotEmpty &&
            existing.title.trim().toLowerCase() == notif.title.trim().toLowerCase() &&
            existing.workRequestId == notif.workRequestId &&
            existing.createdAt.difference(notif.createdAt).abs().inMinutes <= 15) {
          return true;
        }

        return false;
      });

      if (!isDuplicate) {
        result.add(notif);
      }
    }
    return result;
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

    final inserted = await _db.from(_table).insert(payload).select('id').maybeSingle();
    notifyChange();
    final notifId = inserted != null ? inserted['id']?.toString() : null;
    final fcmRecord = {
      ...payload,
      'id': notifId,
    };

    try {
      await _db.functions.invoke('push-notifications', body: {'record': fcmRecord});
    } catch (_) {}

    try {
      await EmailNotificationService.sendRoleNotificationEmails(
        targetRoles: [targetRole],
        title: title,
        message: message,
        workRequestId: workRequestId,
        type: type,
      );
    } catch (_) {}
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
    String? actorUserId,
  }) async {
    final currentUserId = actorUserId ?? _db.auth.currentUser?.id;
    if (currentUserId != null && targetUserId.trim() == currentUserId.trim()) {
      debugPrint('[AppNotificationService] Suppressing self-notification for user $targetUserId (actor: $currentUserId)');
      return;
    }

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

    final inserted = await _db.from(_table).insert(payload).select('id').maybeSingle();
    notifyChange();
    final notifId = inserted != null ? inserted['id']?.toString() : null;
    final fcmRecord = {
      ...payload,
      'id': notifId,
    };

    // Push notification check: if (enableNotifications === true && pushNotifications === true) -> push
    try {
      final canPush = await AppSettingsService.canReceivePush(userId: targetUserId);
      if (canPush) {
        await _db.functions.invoke('push-notifications', body: {'record': fcmRecord});
      }
    } catch (_) {}

    // Email notification check: if (enableNotifications === true && emailNotifications === true) -> email
    try {
      final canEmail = await AppSettingsService.canReceiveEmail(userId: targetUserId);
      if (canEmail) {
        await EmailNotificationService.sendNotificationEmail(
          targetUserId: targetUserId,
          title: title,
          message: message,
          workRequestId: workRequestId,
          type: type,
        );
      }
    } catch (_) {}
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

    // Normalize and remove duplicate synonymous roles (e.g. campadmin and admin)
    final normalizedRoles = targetRoles.map(normalizeRole).toSet().toList();
    if (normalizedRoles.contains('campadmin') && normalizedRoles.contains('admin')) {
      normalizedRoles.remove('admin'); // Only insert campadmin once
    }
    if (normalizedRoles.isEmpty) return;

    final payload = normalizedRoles
        .map(
          (r) => {
            'title': _truncate(title),
            'message': _truncate(message),
            'type': type,
            'target_role': r,
            'work_request_id': workRequestId,
            'target_page': targetPage,
            'is_read': false,
          },
        )
        .toList();

    final insertedList = await _db.from(_table).insert(payload).select('id, target_role');
    notifyChange();
    final idMap = <String, String>{};
    for (final item in insertedList) {
      final r = item['target_role']?.toString();
      final id = item['id']?.toString();
      if (r != null && id != null) idMap[r] = id;
    }

    try {
      for (final p in payload) {
        final r = p['target_role']?.toString();
        final fcmRecord = {
          ...p,
          if (r != null && idMap.containsKey(r)) 'id': idMap[r],
        };
        await _db.functions.invoke('push-notifications', body: {'record': fcmRecord});
      }
    } catch (_) {}

    try {
      await EmailNotificationService.sendRoleNotificationEmails(
        targetRoles: targetRoles,
        title: title,
        message: message,
        workRequestId: workRequestId,
        type: type,
      );
    } catch (_) {}
  }

  /// Notify Campus Admins and the Requestor when a new work request is submitted.
  /// Per security and visibility rules, maintenance is NEVER notified of unassigned requests.
  static Future<void> notifyWorkRequestSubmitted({
    required String workRequestId,
    required String roomName,
    required String buildingName,
    required String requestorName,
    String? requestorId,
  }) async {
    final title = 'New Work Request Submitted';
    final adminMessage = 'New request for $roomName in $buildingName from $requestorName.';

    // 1. Notify Campus Admin role ONCE
    await createForRole(
      targetRole: 'campadmin',
      title: title,
      message: adminMessage,
      type: 'work_request_submitted',
      workRequestId: workRequestId,
      targetPage: '/tickets',
    );

    // 3. Notify the reporting user / Requestor for confirmation
    var targetReqId = requestorId?.trim();
    if (targetReqId == null || targetReqId.isEmpty) {
      targetReqId = await _getRequestorId(workRequestId);
    }
    if (targetReqId != null && targetReqId.isNotEmpty) {
      await createForUser(
        targetUserId: targetReqId,
        title: 'Work Request Submitted',
        message: 'Your request for $roomName in $buildingName has been submitted and is pending admin review.',
        type: 'work_request_submitted',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  /// Notify maintenance and requestor when admin approves a work request.
  static Future<void> notifyApprovedToMaintenance({
    required String workRequestId,
    required String adminName,
    String? assignedMaintenanceId,
    String? assignedMaintenanceName,
    String? requestorId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    final targetMaintenanceId = assignedMaintenanceId?.trim();

    String? maintName = assignedMaintenanceName?.trim();
    if ((maintName == null || maintName.isEmpty) && targetMaintenanceId != null && targetMaintenanceId.isNotEmpty) {
      try {
        final res = await _db.from('users').select('name').eq('id', targetMaintenanceId).maybeSingle();
        if (res != null && res['name'] != null) {
          maintName = res['name'].toString().trim();
        }
      } catch (_) {}
    }

    // Direct notification to the assigned technician
    if (targetMaintenanceId != null && targetMaintenanceId.isNotEmpty) {
      await createForUser(
        targetUserId: targetMaintenanceId,
        title: 'Work Request Approved',
        message:
            'Work request for $roomStr was approved by $adminName and assigned to you.',
        type: 'work_request_approved',
        workRequestId: workRequestId,
        targetPage: '/tasks',
      );
    }

    // Notify Requestor for transparency (explicitly stating who was assigned)
    var targetReqId = requestorId?.trim();
    if (targetReqId == null || targetReqId.isEmpty) {
      targetReqId = await _getRequestorId(workRequestId);
    }
    if (targetReqId != null && targetReqId.isNotEmpty) {
      final assignedText = (maintName != null && maintName.isNotEmpty)
          ? maintName
          : 'maintenance staff';
      await createForUser(
        targetUserId: targetReqId,
        title: 'Work Request Approved',
        message:
            'Your work request for $roomStr was approved by $adminName and assigned to $assignedText.',
        type: 'work_request_approved',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  /// Notify admin and requestor after maintenance accepts the request.
  static Future<void> notifyAcceptedToAdminAndRequestor({
    required String workRequestId,
    required String maintenanceName,
    String? maintenanceUserId,
    String? adminId,
    String? requestorId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    final actorId = maintenanceUserId?.trim() ?? _db.auth.currentUser?.id;
    final normalizedAdminId = adminId?.trim();
    var normalizedRequestorId = requestorId?.trim();
    if (normalizedRequestorId == null || normalizedRequestorId.isEmpty) {
      normalizedRequestorId = await _getRequestorId(workRequestId);
    }
    final bool isAdminSameAsRequestor = (normalizedAdminId != null &&
        normalizedRequestorId != null &&
        normalizedAdminId == normalizedRequestorId);
    final futures = <Future<void>>[];

    // 1. Notify Campus Admin ONCE
    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      if (actorId == null || normalizedAdminId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedAdminId,
            title: 'Work Request Accepted by Maintenance',
            message:
                '$maintenanceName accepted work request in $roomStr. Status is now Under Maintenance.',
            type: 'work_request_accepted',
            workRequestId: workRequestId,
            targetPage: '/tickets',
            actorUserId: actorId,
          ),
        );
      }
    } else {
      futures.add(
        createForRole(
          targetRole: 'campadmin',
          title: 'Work Request Accepted by Maintenance',
          message:
              '$maintenanceName accepted work request in $roomStr. Status is now Under Maintenance.',
          type: 'work_request_accepted',
          workRequestId: workRequestId,
          targetPage: '/tickets',
        ),
      );
    }

    // 2. Notify Requestor ONCE (only if requestor is not the same user as admin)
    if (!isAdminSameAsRequestor &&
        normalizedRequestorId != null &&
        normalizedRequestorId.isNotEmpty) {
      if (actorId == null || normalizedRequestorId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedRequestorId,
            title: 'Request Under Maintenance',
            message:
                'Your request for $roomStr has been accepted by $maintenanceName and is now under maintenance.',
            type: 'work_request_accepted',
            workRequestId: workRequestId,
            targetPage: '/reports',
            actorUserId: actorId,
          ),
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Notify admin and requestor when maintenance submits a completion confirmation signature.
  static Future<void> notifyCompletionSubmittedToAdmin({
    required String workRequestId,
    required String maintenanceName,
    String? maintenanceUserId,
    String? adminId,
    String? requestorId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    final actorId = maintenanceUserId?.trim() ?? _db.auth.currentUser?.id;
    final normalizedAdminId = adminId?.trim();
    var normalizedRequestorId = requestorId?.trim();
    if (normalizedRequestorId == null || normalizedRequestorId.isEmpty) {
      normalizedRequestorId = await _getRequestorId(workRequestId);
    }

    final bool isAdminSameAsRequestor = (normalizedAdminId != null &&
        normalizedRequestorId != null &&
        normalizedAdminId == normalizedRequestorId);
    final futures = <Future<void>>[];

    // 1. Notify Campus Admin ONCE
    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      if (actorId == null || normalizedAdminId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedAdminId,
            title: 'Work Request Completion Submitted',
            message:
                '$maintenanceName submitted completion confirmation for $roomStr.',
            type: 'work_request_completion_submitted',
            workRequestId: workRequestId,
            targetPage: '/tickets',
            actorUserId: actorId,
          ),
        );
      }
    } else {
      futures.add(
        createForRole(
          targetRole: 'campadmin',
          title: 'Work Request Completion Submitted',
          message:
              '$maintenanceName submitted completion confirmation for $roomStr.',
          type: 'work_request_completion_submitted',
          workRequestId: workRequestId,
          targetPage: '/tickets',
        ),
      );
    }

    // 2. Notify Requestor ONCE (only if requestor is not the same user as admin)
    if (!isAdminSameAsRequestor &&
        normalizedRequestorId != null &&
        normalizedRequestorId.isNotEmpty) {
      if (actorId == null || normalizedRequestorId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedRequestorId,
            title: 'Repair Completed by Maintenance',
            message:
                '$maintenanceName has finished the repair work for $roomStr and submitted completion confirmation.',
            type: 'work_request_completion_submitted',
            workRequestId: workRequestId,
            targetPage: '/reports',
            actorUserId: actorId,
          ),
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Notify the reporting user and maintenance when admin submits completion confirmation signature.
  static Future<void> notifyAdminCompletionSubmittedToRequestor({
    required String workRequestId,
    required String adminName,
    String? requestorId,
    String? maintenanceId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    var normalizedRequestorId = requestorId?.trim();
    if (normalizedRequestorId == null || normalizedRequestorId.isEmpty) {
      normalizedRequestorId = await _getRequestorId(workRequestId);
    }

    final futures = <Future<void>>[];

    if (normalizedRequestorId != null && normalizedRequestorId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: normalizedRequestorId,
          title: 'Work Request Ready for Your Confirmation',
          message:
              '$adminName signed completion confirmation for $roomStr. You can now review and sign the confirm work request form.',
          type: 'work_request_completion_ready_for_requestor',
          workRequestId: workRequestId,
          targetPage: '/reports',
        ),
      );
    } else {
      futures.add(
        createForRole(
          targetRole: 'teacher',
          title: 'Work Request Ready for Your Confirmation',
          message:
              '$adminName signed completion confirmation for $roomStr. Please review and sign the confirm work request form.',
          type: 'work_request_completion_ready_for_requestor',
          workRequestId: workRequestId,
          targetPage: '/reports',
        ),
      );
    }

    var targetMaintId = maintenanceId?.trim();
    if (targetMaintId == null || targetMaintId.isEmpty) {
      targetMaintId = await _getMaintenanceId(workRequestId);
    }
    if (targetMaintId != null && targetMaintId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: targetMaintId,
          title: 'Work Request Completed by Admin',
          message: '$adminName signed completion confirmation for $roomStr.',
          type: 'work_request_completed',
          workRequestId: workRequestId,
          targetPage: '/tasks',
        ),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<void> markAsRead(String id) async {
    try {
      final notifData = await _db
          .from(_table)
          .select('type, target_page, target_user_id')
          .eq('id', id)
          .maybeSingle();

      await _db.from(_table).update({'is_read': true}).eq('id', id);

      if (notifData != null) {
        final targetPage = notifData['target_page']?.toString() ?? '';
        final targetUserId = notifData['target_user_id']?.toString();
        if (targetPage.startsWith('chat_room_id:') && targetUserId != null) {
          await _db
              .from(_table)
              .update({'is_read': true})
              .eq('target_page', targetPage)
              .eq('target_user_id', targetUserId)
              .eq('is_read', false);
        }
      }
    } catch (_) {
      await _db.from(_table).update({'is_read': true}).eq('id', id);
    }
  }

  static Future<void> markChatRoomAsRead({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _db
          .from(_table)
          .update({'is_read': true})
          .eq('target_page', 'chat_room_id:$roomId')
          .eq('target_user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  static Future<String?> _getRequestorId(String workRequestId) async {
    try {
      final response = await _db
          .from('work_requests')
          .select('requestor_id, reported_by_id')
          .eq('id', workRequestId)
          .maybeSingle();
      if (response != null) {
        final rId = response['requestor_id']?.toString().trim();
        if (rId != null && rId.isNotEmpty && rId != 'null') return rId;
        final repId = response['reported_by_id']?.toString().trim();
        if (repId != null && repId.isNotEmpty && repId != 'null') return repId;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _getMaintenanceId(String workRequestId) async {
    try {
      final response = await _db
          .from('work_requests')
          .select('assigned_to_id')
          .eq('id', workRequestId)
          .maybeSingle();
      if (response != null) {
        final aId = response['assigned_to_id']?.toString().trim();
        if (aId != null && aId.isNotEmpty && aId != 'null') return aId;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> notifyPreInspectionApproved({
    required String workRequestId,
    String? maintenanceId,
    required String adminName,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    var targetMaintId = maintenanceId?.trim();
    if (targetMaintId == null || targetMaintId.isEmpty) {
      targetMaintId = await _getMaintenanceId(workRequestId);
    }

    final futures = <Future<void>>[];

    if (targetMaintId != null && targetMaintId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: targetMaintId,
          title: 'Pre-Inspection Approved',
          message: '$adminName has approved your pre-inspection report for $roomStr. You can now start the repair.',
          type: 'work_request_approved',
          workRequestId: workRequestId,
          targetPage: '/tasks',
        ),
      );
    }

    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null && requestorId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: requestorId,
          title: 'Pre-Inspection Approved',
          message: 'The pre-inspection report for $roomStr was approved by $adminName. Work will proceed.',
          type: 'work_request_approved',
          workRequestId: workRequestId,
          targetPage: '/reports',
        ),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<void> notifyPreInspectionDeclined({
    required String workRequestId,
    String? maintenanceId,
    required String adminName,
    required String notes,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    var targetMaintId = maintenanceId?.trim();
    if (targetMaintId == null || targetMaintId.isEmpty) {
      targetMaintId = await _getMaintenanceId(workRequestId);
    }

    final futures = <Future<void>>[];

    if (targetMaintId != null && targetMaintId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: targetMaintId,
          title: 'Pre-Inspection Declined',
          message: '$adminName has declined your pre-inspection report for $roomStr. Reason: $notes.',
          type: 'work_request_declined',
          workRequestId: workRequestId,
          targetPage: '/tasks',
        ),
      );
    }

    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null && requestorId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: requestorId,
          title: 'Work Request Declined',
          message: 'The work request for $roomStr was declined during pre-inspection by $adminName. Reason: $notes.',
          type: 'work_request_declined',
          workRequestId: workRequestId,
          targetPage: '/reports',
        ),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<void> notifyPostRepairRework({
    required String workRequestId,
    String? maintenanceId,
    required String adminName,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    var targetMaintId = maintenanceId?.trim();
    if (targetMaintId == null || targetMaintId.isEmpty) {
      targetMaintId = await _getMaintenanceId(workRequestId);
    }

    final futures = <Future<void>>[];

    if (targetMaintId != null && targetMaintId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: targetMaintId,
          title: 'Post-Repair Rework Required',
          message: '$adminName requested rework on your post-repair report for $roomStr.',
          type: 'work_request_declined',
          workRequestId: workRequestId,
          targetPage: '/tasks',
        ),
      );
    }

    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null && requestorId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: requestorId,
          title: 'Rework Required',
          message: 'The post-repair evaluation for $roomStr requires rework as decided by $adminName.',
          type: 'work_request_declined',
          workRequestId: workRequestId,
          targetPage: '/reports',
        ),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<void> notifyPostRepairCompleted({
    required String workRequestId,
    String? maintenanceId,
    required String adminName,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    var targetMaintId = maintenanceId?.trim();
    if (targetMaintId == null || targetMaintId.isEmpty) {
      targetMaintId = await _getMaintenanceId(workRequestId);
    }

    final futures = <Future<void>>[];

    if (targetMaintId != null && targetMaintId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: targetMaintId,
          title: 'Post-Repair Completed',
          message: '$adminName marked the repair for $roomStr as completed.',
          type: 'work_request_completed',
          workRequestId: workRequestId,
          targetPage: '/tasks',
        ),
      );
    }

    final requestorId = await _getRequestorId(workRequestId);
    if (requestorId != null && requestorId.isNotEmpty) {
      futures.add(
        createForUser(
          targetUserId: requestorId,
          title: 'Work Completed & Verified',
          message: 'The maintenance work for $roomStr has been completed and verified by $adminName.',
          type: 'work_request_completed',
          workRequestId: workRequestId,
          targetPage: '/reports',
        ),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<void> notifyPreInspectionSubmittedToAdmin({
    required String workRequestId,
    required String maintenanceName,
    String? maintenanceUserId,
    String? adminId,
    String? requestorId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    final actorId = maintenanceUserId?.trim() ?? _db.auth.currentUser?.id;
    final normalizedAdminId = adminId?.trim();
    var normalizedRequestorId = requestorId?.trim();
    if (normalizedRequestorId == null || normalizedRequestorId.isEmpty) {
      normalizedRequestorId = await _getRequestorId(workRequestId);
    }

    final bool isAdminSameAsRequestor = (normalizedAdminId != null &&
        normalizedRequestorId != null &&
        normalizedAdminId == normalizedRequestorId);
    final futures = <Future<void>>[];

    // 1. Notify Campus Admin ONCE
    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      if (actorId == null || normalizedAdminId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedAdminId,
            title: 'Pre-Inspection Submitted',
            message: '$maintenanceName has submitted a pre-inspection report for $roomStr.',
            type: 'pre_inspection_submitted',
            workRequestId: workRequestId,
            targetPage: '/tickets',
            actorUserId: actorId,
          ),
        );
      }
    } else {
      futures.add(
        createForRole(
          targetRole: 'campadmin',
          title: 'Pre-Inspection Submitted',
          message: '$maintenanceName has submitted a pre-inspection report for $roomStr.',
          type: 'pre_inspection_submitted',
          workRequestId: workRequestId,
          targetPage: '/tickets',
        ),
      );
    }

    // 2. Notify Requestor ONCE (only if requestor is not the same user as admin)
    if (!isAdminSameAsRequestor &&
        normalizedRequestorId != null &&
        normalizedRequestorId.isNotEmpty) {
      if (actorId == null || normalizedRequestorId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedRequestorId,
            title: 'Pre-Inspection Filed',
            message: 'A pre-inspection report for $roomStr has been filed by $maintenanceName and is awaiting admin review.',
            type: 'work_request_inspected',
            workRequestId: workRequestId,
            targetPage: '/reports',
            actorUserId: actorId,
          ),
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  static Future<void> notifyPostRepairSubmittedToAdmin({
    required String workRequestId,
    required String maintenanceName,
    String? maintenanceUserId,
    String? adminId,
    String? requestorId,
  }) async {
    final roomStr = await _getRoomStr(workRequestId);
    final actorId = maintenanceUserId?.trim() ?? _db.auth.currentUser?.id;
    final normalizedAdminId = adminId?.trim();
    var normalizedRequestorId = requestorId?.trim();
    if (normalizedRequestorId == null || normalizedRequestorId.isEmpty) {
      normalizedRequestorId = await _getRequestorId(workRequestId);
    }

    final bool isAdminSameAsRequestor = (normalizedAdminId != null &&
        normalizedRequestorId != null &&
        normalizedAdminId == normalizedRequestorId);
    final futures = <Future<void>>[];

    // 1. Notify Campus Admin ONCE
    if (normalizedAdminId != null && normalizedAdminId.isNotEmpty) {
      if (actorId == null || normalizedAdminId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedAdminId,
            title: 'Post-Repair Evaluation Submitted',
            message: '$maintenanceName has submitted a post-repair evaluation for $roomStr.',
            type: 'post_repair_submitted',
            workRequestId: workRequestId,
            targetPage: '/tickets',
            actorUserId: actorId,
          ),
        );
      }
    } else {
      futures.add(
        createForRole(
          targetRole: 'campadmin',
          title: 'Post-Repair Evaluation Submitted',
          message: '$maintenanceName has submitted a post-repair evaluation for $roomStr.',
          type: 'post_repair_submitted',
          workRequestId: workRequestId,
          targetPage: '/tickets',
        ),
      );
    }

    // 2. Notify Requestor ONCE (only if requestor is not the same user as admin)
    if (!isAdminSameAsRequestor &&
        normalizedRequestorId != null &&
        normalizedRequestorId.isNotEmpty) {
      if (actorId == null || normalizedRequestorId != actorId) {
        futures.add(
          createForUser(
            targetUserId: normalizedRequestorId,
            title: 'Post-Repair Submitted',
            message: 'A post-repair evaluation for $roomStr has been submitted by $maintenanceName and is awaiting admin evaluation.',
            type: 'post_repair_submitted',
            workRequestId: workRequestId,
            targetPage: '/reports',
            actorUserId: actorId,
          ),
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
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

    final preview = messageContent.length > 80
        ? '${messageContent.substring(0, 80)}…'
        : messageContent;

    await createForUser(
      targetUserId: targetUserId,
      title: senderName,
      message: preview,
      type: 'chat_message',
      workRequestId: workRequestId,
      targetPage: 'chat_room_id:$chatRoomId',
    );
  }

  /// Notify Department Head of a newly submitted work request from faculty
  static Future<void> notifyDeptHeadNewRequest({
    required String deptHeadUserId,
    required String workRequestId,
    required String requestTitle,
    required String requestorName,
    required String departmentName,
  }) async {
    await createForUser(
      targetUserId: deptHeadUserId,
      title: 'Department Approval Required',
      message: '$requestorName submitted a work request "$requestTitle" requiring your evaluation.',
      type: 'dept_head_approval_required',
      workRequestId: workRequestId,
      targetPage: '/approvals',
    );
  }

  /// Notify Campus Admin that a Department Head has approved/endorsed a request
  static Future<void> notifyCampusAdminDeptHeadApproved({
    required String workRequestId,
    required String requestTitle,
    required String deptHeadName,
    required String departmentName,
  }) async {
    await createForRole(
      targetRole: 'campadmin',
      title: 'New Work Request (Dept Head Approved)',
      message: 'Work request "$requestTitle" from $departmentName was endorsed by Department Head $deptHeadName and is awaiting admin approval.',
      type: 'work_request_submitted',
      workRequestId: workRequestId,
      targetPage: '/reports',
    );
  }

  /// Notify Requestor of the Department Head's decision (approved or declined)
  static Future<void> notifyRequestorDeptHeadDecision({
    required String requestorId,
    required String workRequestId,
    required String requestTitle,
    required bool isApproved,
    required String deptHeadName,
    String? notes,
  }) async {
    final statusText = isApproved ? 'endorsed and forwarded to Campus Admin' : 'declined';
    final notesText = (notes != null && notes.trim().isNotEmpty) ? ' Note: $notes' : '';
    await createForUser(
      targetUserId: requestorId,
      title: isApproved ? 'Request Endorsed by Department Head' : 'Request Declined by Department Head',
      message: 'Your work request "$requestTitle" was $statusText by Department Head $deptHeadName.$notesText',
      type: isApproved ? 'dept_head_approved' : 'dept_head_declined',
      workRequestId: workRequestId,
      targetPage: '/status',
    );
  }

  /// Notify appropriate reviewer (Dept Head or Campus Admin) about a Follow-Up inquiry
  static Future<void> notifyFollowUpSubmitted({
    required String workRequestId,
    required String requestorId,
    required String requestorName,
    required String message,
    required String targetStage,
    String? recipientUserId,
    required String workRequestTitle,
  }) async {
    final preview = message.length > 80 ? '${message.substring(0, 80)}…' : message;
    if (targetStage == 'dept_head' && recipientUserId != null && recipientUserId.isNotEmpty) {
      await createForUser(
        targetUserId: recipientUserId,
        title: 'Work Request Follow-Up',
        message: '$requestorName sent an inquiry on "$workRequestTitle": "$preview"',
        type: 'work_request_follow_up',
        workRequestId: workRequestId,
        targetPage: '/approvals',
      );
    } else {
      await createForRole(
        targetRole: 'campadmin',
        title: 'Work Request Follow-Up',
        message: '$requestorName sent an inquiry on "$workRequestTitle": "$preview"',
        type: 'work_request_follow_up',
        workRequestId: workRequestId,
        targetPage: '/reports',
      );
    }
  }

  /// Notify Requestor that a reviewer replied to their Follow-Up inquiry
  static Future<void> notifyFollowUpReplied({
    required String requestorId,
    required String workRequestId,
    required String responderName,
    required String response,
  }) async {
    final preview = response.length > 80 ? '${response.substring(0, 80)}…' : response;
    await createForUser(
      targetUserId: requestorId,
      title: 'Response to Your Inquiry',
      message: '$responderName replied to your follow-up: "$preview"',
      type: 'work_request_follow_up_reply',
      workRequestId: workRequestId,
      targetPage: '/status',
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
    notifyChange();
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
    notifyChange();
  }

  static Future<int> getUnreadCount({
    required String role,
    required String userId,
  }) async {
    final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: userId);
    if (!isEnabled) {
      return 0;
    }
    final list = await fetchForUser(role: role, userId: userId);
    return list.where((n) => !n.isRead).length;
  }
}




