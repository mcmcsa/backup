import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_request_follow_up_model.dart';
import 'app_notification_service.dart';

class WorkRequestFollowUpService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'work_request_follow_ups';

  /// Create a follow-up message on an existing work request
  static Future<WorkRequestFollowUp?> createFollowUp({
    required String workRequestId,
    required String requestorId,
    required String message,
    required String targetStage,
    String? recipientUserId,
    String? workRequestTitle,
    String? requestorName,
  }) async {
    try {
      final insertData = {
        'work_request_id': workRequestId,
        'requestor_id': requestorId,
        'message': message,
        'target_stage': targetStage,
        if (recipientUserId != null && recipientUserId.isNotEmpty)
          'recipient_user_id': recipientUserId,
        'status': 'pending',
      };

      final res = await _db.from(_table).insert(insertData).select().single();
      final followUp = WorkRequestFollowUp.fromMap(res);

      // Trigger contextual notification
      try {
        await AppNotificationService.notifyFollowUpSubmitted(
          workRequestId: workRequestId,
          requestorId: requestorId,
          requestorName: requestorName ?? 'Requestor',
          message: message,
          targetStage: targetStage,
          recipientUserId: recipientUserId,
          workRequestTitle: workRequestTitle ?? 'Work Request',
        );
      } catch (_) {
        // Notification failure should not block follow up creation
      }

      return followUp;
    } catch (e) {
      return null;
    }
  }

  /// Fetch all follow-ups for a work request
  static Future<List<WorkRequestFollowUp>> fetchFollowUpsForRequest(
    String workRequestId,
  ) async {
    try {
      final res = await _db
          .from(_table)
          .select('''
            *,
            requestor:users!work_request_follow_ups_requestor_id_fkey(name),
            responder:users!work_request_follow_ups_responded_by_fkey(name)
          ''')
          .eq('work_request_id', workRequestId)
          .order('created_at', ascending: true);

      return (res as List).map((e) => WorkRequestFollowUp.fromMap(e)).toList();
    } catch (_) {
      // Fallback without explicit join
      try {
        final res = await _db
            .from(_table)
            .select()
            .eq('work_request_id', workRequestId)
            .order('created_at', ascending: true);

        return (res as List).map((e) => WorkRequestFollowUp.fromMap(e)).toList();
      } catch (e) {
        return [];
      }
    }
  }

  /// Respond to a follow-up inquiry
  static Future<bool> respondToFollowUp({
    required String followUpId,
    required String responseText,
    required String responderId,
    String? requestorId,
    String? workRequestId,
    String? responderName,
  }) async {
    try {
      await _db.from(_table).update({
        'admin_response': responseText,
        'responded_by': responderId,
        'responded_at': DateTime.now().toIso8601String(),
        'status': 'replied',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);

      if (requestorId != null && workRequestId != null) {
        try {
          await AppNotificationService.notifyFollowUpReplied(
            requestorId: requestorId,
            workRequestId: workRequestId,
            responderName: responderName ?? 'Reviewer',
            response: responseText,
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Acknowledge a follow-up inquiry
  static Future<bool> acknowledgeFollowUp(String followUpId) async {
    try {
      await _db.from(_table).update({
        'status': 'acknowledged',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', followUpId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
