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
      await _db.from(_table).update({
        'availability_status': 'online',
        'last_active_at': DateTime.now().toIso8601String(),
        'status_updated_at': DateTime.now().toIso8601String(),
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
        'availability_status': 'busy', // Or 'working'
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
      await _db.from(_table).update({
        'availability_status': 'available',
        'current_assignment_id': null,
        'status_updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set available status: $e');
    }
  }

  /// Get status colors for badges (shared design logic)
  static Map<String, dynamic> getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'available':
        return {'color': 0xFF10B981, 'bg': 0xFFD1FAE5}; // Emerald
      case 'working':
      case 'busy':
        return {'color': 0xFFF59E0B, 'bg': 0xFFFEF3C7}; // Amber
      case 'offline':
        return {'color': 0xFF64748B, 'bg': 0xFFF1F5F9}; // Slate
      case 'break':
        return {'color': 0xFF8B5CF6, 'bg': 0xFFEDE9FE}; // Violet
      case 'on_leave':
      case 'on leave':
      case 'onleave':
        return {'color': 0xFF0F172A, 'bg': 0xFFE2E8F0}; // Dark Slate
      default:
        return {'color': 0xFF64748B, 'bg': 0xFFF1F5F9};
    }
  }
}
