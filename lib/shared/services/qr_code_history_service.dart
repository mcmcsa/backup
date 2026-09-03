import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/qr_code_history_model.dart';
import 'admin_audit_log_service.dart';

class QRCodeHistoryService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'qr_code_history';

  // Get all QR codes from database (active only, for legacy compatibility)
  static Future<List<QRCodeHistory>> getHistory({String? roomId}) async {
    try {
      late final List<dynamic> data;
      
      if (roomId != null) {
        data = await _db
            .from(_table)
            .select()
            .eq('room_id', roomId)
            .eq('is_active', true)
            .order('created_at', ascending: false);
      } else {
        data = await _db
            .from(_table)
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false);
      }
      
      return (data).map((e) => QRCodeHistory.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Error fetching QR code history: $e');
    }
  }

  // Get ALL QR codes from database (including inactive, for admin view)
  static Future<List<QRCodeHistory>> fetchAllHistory() async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .order('created_at', ascending: false);
      return (data as List).map((e) => QRCodeHistory.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Error fetching all QR code history: $e');
    }
  }

  // Save QR code to database
  static Future<QRCodeHistory> saveQRCode({
    required String roomId,
    required String qrCodeValue,
    String? roomName,
    String? building,
    String? department,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _db.from(_table).insert({
        'room_id': roomId,
        'qr_code_value': qrCodeValue,
        'created_by_id': userId,
        'is_active': true,
        'scanned_count': 0,
      }).select().single();

      await AdminAuditLogService.logAction(
        title: 'Generated QR Code',
        details: 'QR Value: $qrCodeValue',
      );

      return QRCodeHistory.fromMap(response);
    } catch (e) {
      throw Exception('Error saving QR code: $e');
    }
  }

  // Update display metadata for active QR history entries of a room.
  static Future<void> updateRoomMetadata({
    required String roomId,
    required String roomName,
    required String building,
    required String department,
  }) async {
    return;
  }

  // Get single QR code by value
  static Future<QRCodeHistory?> getByQRValue(String qrCodeValue) async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .eq('qr_code_value', qrCodeValue)
          .eq('is_active', true)
          .maybeSingle();
      
      if (data == null) return null;
      return QRCodeHistory.fromMap(data);
    } catch (e) {
      throw Exception('Error fetching QR code: $e');
    }
  }

  // Update QR code scan count
  static Future<void> recordQRScan(String qrHistoryId) async {
    try {
      final qrCode = await _db
          .from(_table)
          .select()
          .eq('id', qrHistoryId)
          .maybeSingle();
      
      if (qrCode == null) return;
      
      await _db
          .from(_table)
          .update({
            'scanned_count': (qrCode['scanned_count'] ?? 0) + 1,
            'last_scanned': DateTime.now().toIso8601String(),
          })
          .eq('id', qrHistoryId);
    } catch (e) {
      throw Exception('Error recording QR scan: $e');
    }
  }

  // Delete a specific QR code
  static Future<void> deleteQRCode(String id) async {
    try {
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted QR Code',
        details: 'QR Code ID: $id',
      );
    } catch (e) {
      throw Exception('Error deleting QR code: $e');
    }
  }

  // Soft delete (mark as inactive)
  static Future<void> deactivateQRCode(String id) async {
    try {
      await _db.from(_table).update({'is_active': false}).eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deactivated QR Code',
        details: 'QR Code ID: $id',
      );
    } catch (e) {
      throw Exception('Error deactivating QR code: $e');
    }
  }

  // Activate QR code
  static Future<void> activateQRCode(String id) async {
    try {
      await _db.from(_table).update({'is_active': true}).eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Activated QR Code',
        details: 'QR Code ID: $id',
      );
    } catch (e) {
      throw Exception('Error activating QR code: $e');
    }
  }

  // Increment scan count when room is scanned
  static Future<void> recordScanForRoom(String roomId) async {
    try {
      final matches = await _db
          .from(_table)
          .select('id, scanned_count')
          .eq('room_id', roomId)
          .order('created_at', ascending: false);

      if (matches != null && (matches as List).isNotEmpty) {
        final target = (matches as List).first;
        final id = target['id'].toString();
        final currentCount = (target['scanned_count'] as int?) ?? 0;
        await _db.from(_table).update({
          'scanned_count': currentCount + 1,
          'last_scanned': DateTime.now().toIso8601String(),
        }).eq('id', id);
      }
    } catch (_) {}
  }

  // Clear all QR codes
  static Future<void> clearHistory() async {
    try {
      await _db.from(_table).delete();
    } catch (e) {
      throw Exception('Error clearing history: $e');
    }
  }

  // Get count of QR codes
  static Future<int> getHistoryCount() async {
    try {
      final data = await _db
          .from(_table)
          .select()
          .eq('is_active', true);
      
      return (data as List?)?.length ?? 0;
    } catch (e) {
      throw Exception('Error getting history count: $e');
    }
  }
}
