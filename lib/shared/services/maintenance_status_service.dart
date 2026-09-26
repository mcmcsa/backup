import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'maintenance_account_service.dart';
import 'work_request_service.dart';
import '../models/work_request_model.dart';

class MaintenanceStatusService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'maintenance_users';
  static Timer? _heartbeatTimer;

  /// Start real-time heartbeat for an active maintenance session
  static void startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    if (userId.trim().isEmpty) return;
    
    // Immediate heartbeat
    sendHeartbeat(userId);
    
    // Periodic heartbeat every 5 seconds while the app is active
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      sendHeartbeat(userId);
    });
  }

  /// Stop heartbeat when user logs out or app unmounts
  static void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Returns true if a work request status represents an ongoing/active assignment for a technician
  static bool isOngoingWorkRequestStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s.isEmpty) return false;
    return s != 'completed' &&
        s != 'cancelled' &&
        s != 'declined' &&
        s != 'rejected' &&
        s != 'declined/cancelled';
  }

  /// Unified binary status detection:
  /// - If user has an active/ongoing assignment -> 'busy'
  /// - Otherwise -> 'available'
  static String computeDynamicStatus({
    required bool hasActiveAssignment,
    required DateTime? lastActiveAt,
    required DateTime now,
    int activeThresholdSeconds = 90,
  }) {
    if (hasActiveAssignment) {
      return 'busy';
    }
    return 'available';
  }

  /// Heartbeat ping to mark user as active and detect available vs busy
  static Future<void> sendHeartbeat(String userId) async {
    try {
      final activeRequests = await _db
          .from('work_requests')
          .select('id, status')
          .eq('assigned_to_id', userId);

      final hasActive = (activeRequests as List).any((r) {
        final st = r['status']?.toString() ?? '';
        return isOngoingWorkRequestStatus(st);
      });

      final String nextStatus = hasActive ? 'busy' : 'available';
      final String? assignmentId = hasActive
          ? activeRequests.firstWhere(
              (r) => isOngoingWorkRequestStatus(r['status']?.toString() ?? ''),
              orElse: () => <String, dynamic>{},
            )['id']?.toString()
          : null;

      await _db.from(_table).update({
        'availability_status': nextStatus,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
        'status_updated_at': DateTime.now().toUtc().toIso8601String(),
        'current_assignment_id': assignmentId,
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Heartbeat error: $e');
    }
  }

  /// Syncs the status of a specific user based on active assignments and heartbeat
  static Future<void> syncStatusForUser(String userId) async {
    try {
      final profile = await _db
          .from(_table)
          .select('last_active_at')
          .eq('user_id', userId)
          .maybeSingle();

      final activeRequests = await _db
          .from('work_requests')
          .select('id, status')
          .eq('assigned_to_id', userId);

      final hasActive = (activeRequests as List).any((r) {
        final st = r['status']?.toString() ?? '';
        return isOngoingWorkRequestStatus(st);
      });

      final DateTime? lastActive = profile?['last_active_at'] != null
          ? DateTime.tryParse(profile!['last_active_at'].toString())
          : null;

      final dynamicStatus = computeDynamicStatus(
        hasActiveAssignment: hasActive,
        lastActiveAt: lastActive,
        now: DateTime.now().toUtc(),
      );

      final String? assignmentId = hasActive
          ? activeRequests.firstWhere(
              (r) => isOngoingWorkRequestStatus(r['status']?.toString() ?? ''),
              orElse: () => <String, dynamic>{},
            )['id']?.toString()
          : null;

      await _db.from(_table).update({
        'availability_status': dynamicStatus,
        'status_updated_at': DateTime.now().toUtc().toIso8601String(),
        'current_assignment_id': assignmentId,
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to sync maintenance status: $e');
    }
  }

  /// Fetch all active maintenance staff along with their live availability status
  static Future<List<MaintenanceAccount>> fetchAllWithStatus() async {
    return await MaintenanceAccountService.fetchAllActiveMaintenance();
  }

  /// Manually override availability status for a user
  static Future<void> updateStatus(String userId, String status) async {
    final normalized = status.toLowerCase().trim() == 'busy' ? 'busy' : 'available';
    final Map<String, dynamic> data = {
      'availability_status': normalized,
      'status_updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _db.from(_table).update(data).eq('user_id', userId);
  }

  /// Called upon successful login
  static Future<void> setOnlineOnLogin(String userId) async {
    try {
      await sendHeartbeat(userId);
    } catch (e) {
      debugPrint('Failed to set online status on login: $e');
    }
  }

  /// Called right before successful logout
  static Future<void> setOfflineOnLogout(String userId) async {
    try {
      await syncStatusForUser(userId);
    } catch (e) {
      debugPrint('Failed to sync status on logout: $e');
    }
  }

  /// Called when a maintenance user accepts a work request
  static Future<void> setBusyOnAssignment(String userId, String workRequestId) async {
    try {
      await _db.from(_table).update({
        'availability_status': 'busy',
        'current_assignment_id': workRequestId,
        'status_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set busy status: $e');
    }
  }

  /// Called when a maintenance user completes a work request
  static Future<void> setAvailableOnCompletion(String userId) async {
    try {
      await syncStatusForUser(userId);
    } catch (e) {
      debugPrint('Failed to set available status on completion: $e');
    }
  }

  /// Fetch all active maintenance staff computed with their real-time Available vs Busy status
  static Future<List<MaintenanceAccount>> fetchActiveMaintenanceWithDynamicStatus() async {
    final results = await Future.wait([
      MaintenanceAccountService.fetchAllActiveMaintenance(),
      WorkRequestService.fetchAll(),
    ]);

    final rawActive = results[0] as List<MaintenanceAccount>;
    final allRequests = results[1] as List<WorkRequest>;

    final activeBusyUserIds = <String>{};
    for (final req in allRequests) {
      if (isOngoingWorkRequestStatus(req.status)) {
        if (req.assignedToId != null && req.assignedToId!.isNotEmpty) {
          activeBusyUserIds.add(req.assignedToId!);
        }
      }
    }

    return rawActive.map((account) {
      final bool isBusy = activeBusyUserIds.contains(account.userId);
      final String computedStatus = isBusy ? 'busy' : 'available';

      if (computedStatus != account.availabilityStatus.toLowerCase()) {
        updateStatus(account.userId, computedStatus).catchError((_) {});
        return MaintenanceAccount(
          userId: account.userId,
          email: account.email,
          fullName: account.fullName,
          employeeId: account.employeeId,
          specialization: account.specialization,
          contactNo: account.contactNo,
          isActive: account.isActive,
          archivedAt: account.archivedAt,
          createdAt: account.createdAt,
          availabilityStatus: computedStatus,
          currentLocation: account.currentLocation,
          currentAssignmentId: account.currentAssignmentId,
          estimatedCompletionTime: account.estimatedCompletionTime,
          lastActiveAt: account.lastActiveAt,
          workingHoursStart: account.workingHoursStart,
          workingHoursEnd: account.workingHoursEnd,
          statusUpdatedAt: account.statusUpdatedAt,
        );
      }
      return account;
    }).toList();
  }

  /// Get status colors for badges (shared design logic)
  static Map<String, dynamic> getStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'busy':
      case 'working':
        return {'color': 0xFFF59E0B, 'bg': 0xFFFEF3C7}; // Amber (Orange/Yellow)
      case 'available':
      case 'online':
      case 'offline':
      case 'break':
      case 'on_leave':
      default:
        return {'color': 0xFF10B981, 'bg': 0xFFD1FAE5}; // Emerald (Green)
    }
  }
}
