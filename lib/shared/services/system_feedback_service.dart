import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_feedback_model.dart';
import 'admin_audit_log_service.dart';

class SystemFeedbackService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'system_feedback';

  static Future<List<SystemFeedback>> fetchAll() async {
    try {
      final data = await _db.from(_table).select().order('created_at', ascending: false);
      return (data as List).map((e) => SystemFeedback.fromMap(e)).toList();
    } catch (e) {
      // Return empty list if table doesn't exist yet
      return [];
    }
  }

  static Future<String?> submitFeedback({
    required String category,
    required String message,
  }) async {
    try {
      final authUser = _db.auth.currentUser;
      if (authUser == null) throw 'User not authenticated';

      final profile = await _db.from('users').select('name').eq('id', authUser.id).maybeSingle();
      final userName = profile != null ? profile['name'] : 'Unknown User';

      await _db.from(_table).insert({
        'user_id': authUser.id,
        'user_name': userName,
        'category': category,
        'message': message,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> updateFeedbackStatus({
    required String id,
    required String status,
    String? reply,
  }) async {
    try {
      await _db.from(_table).update({
        'status': status,
        if (reply != null) 'admin_reply': reply,
      }).eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Resolved User Feedback',
        details: 'Feedback ID: $id resolved with reply.',
      );

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteFeedback(String id) async {
    try {
      await _db.from(_table).delete().eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Deleted User Feedback',
        details: 'Feedback ID: $id was deleted.',
      );

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
