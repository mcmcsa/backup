import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'maintenance_account_service.dart';

class MaintenanceStatusService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'maintenance_users';

  /// Fetch all active maintenance staff along with their live availability status
  static Future<List<MaintenanceAccount>> fetchAllWithStatus() async {
    return await MaintenanceAccountService.fetchCreatedByCurrentAdmin();
  }

  /// Manually override availability status for a user
  static Future<void> updateStatus(String userId, String status) async {
    await _db.from(_table).update({
      'availability_status': status,
      'status_updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', userId);
  }

  /// Called upon successful login
  static Future<void> setOnlineOnLogin(String userId) async {
    try {
      // Check if they have active assignments
      final activeRequests = await _db
          .from('work_requests')
          .select('id')
          .eq('assigned_to_id', userId)
          .inFilter('status', [
            'Accepted', 
            'Confirmed', 
            'Rework Needed', 
            'Pre-Inspection Submitted', 
            'Under Evaluation', 
            'In Progress', 
            'in_progress', 
            'accepted by maintenance'
          ]);

      final String nextStatus = activeRequests.isNotEmpty ? 'busy' : 'online';

      await _db.from(_table).update({
        'availability_status': nextStatus,
        'last_active_at': DateTime.now().toIso8601String(),
        'status_updated_at': DateTime.now().toIso8601String(),
        if (activeRequests.isNotEmpty) 'current_assignment_id': activeRequests.first['id'],
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set online status: $e');
    }
  }

  /// Called right before successful logout
  static Future<void> setOfflineOnLogout(String userId) async {
    try {
      await _db.from(_table).update({
        'availability_status': 'offline',
        'current_assignment_id': null,
        'status_updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set offline status: $e');
    }
  }

  /// Called when a maintenance user accepts a work request
  static Future<void> setBusyOnAssignment(String userId, String workRequestId) async {
    try {
      await _db.from(_table).update({
        'availability_status': 'busy',
        'current_assignment_id': workRequestId,
        'status_updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set busy status: $e');
    }
  }

  /// Called when a maintenance user completes a work request
  static Future<void> setAvailableOnCompletion(String userId) async {
    try {
      // Check if they still have other active/accepted work requests assigned to them
      final activeRequests = await _db
          .from('work_requests')
          .select('id')
          .eq('assigned_to_id', userId)
          .inFilter('status', [
            'Accepted', 
            'Confirmed', 
            'Rework Needed', 
            'Pre-Inspection Submitted', 
            'Under Evaluation', 
            'In Progress', 
            'in_progress', 
            'accepted by maintenance'
          ]);
      
      final String nextStatus = activeRequests.isNotEmpty ? 'busy' : 'online';

      await _db.from(_table).update({
        'availability_status': nextStatus,
        'current_assignment_id': activeRequests.isNotEmpty ? activeRequests.first['id'] : null,
        'status_updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set online status on completion: $e');
    }
  }

  /// Get status colors for badges (shared design logic)
  static Map<String, dynamic> getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'available':
        return {'color': 0xFF10B981, 'bg': 0xFFD1FAE5}; // Emerald (Green)
      case 'busy':
      case 'working':
        return {'color': 0xFFF59E0B, 'bg': 0xFFFEF3C7}; // Amber (Orange/Yellow)
      case 'offline':
      case 'break':
      case 'on_leave':
      case 'on leave':
      case 'onleave':
      default:
        return {'color': 0xFF64748B, 'bg': 0xFFF1F5F9}; // Slate (Grey)
    }
  }
}
