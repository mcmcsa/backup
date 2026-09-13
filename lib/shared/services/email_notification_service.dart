import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings_service.dart';

class EmailNotificationService {
  EmailNotificationService._();

  static SupabaseClient get _db => Supabase.instance.client;

  /// Dispatches an email notification to a specific user if their settings permit it.
  /// Strictly adheres to:
  /// if (enableNotifications === true && emailNotifications === true) -> send email notification
  static Future<void> sendNotificationEmail({
    required String targetUserId,
    required String title,
    required String message,
    String? workRequestId,
    String? type,
  }) async {
    if (targetUserId.isEmpty) return;

    try {
      // 1. Verify user's notification settings (Master switch & Email switch)
      final canEmail = await AppSettingsService.canReceiveEmail(userId: targetUserId);
      if (!canEmail) {
        debugPrint('[EmailNotificationService] Email suppressed: user $targetUserId has emailNotifications or master toggle OFF.');
        return;
      }

      // 2. Resolve target user's email address from database
      final userRecord = await _db
          .from('users')
          .select('email, name')
          .eq('id', targetUserId)
          .maybeSingle();

      if (userRecord == null) {
        debugPrint('[EmailNotificationService] Could not find user $targetUserId in database.');
        return;
      }

      final email = userRecord['email']?.toString().trim();
      final name = userRecord['name']?.toString().trim() ?? 'User';

      if (email == null || email.isEmpty) {
        debugPrint('[EmailNotificationService] User $targetUserId has no registered email.');
        return;
      }

      final payload = {
        'recipient_id': targetUserId,
        'recipient_email': email,
        'recipient_name': name,
        'subject': title,
        'title': title,
        'message': message,
        'work_request_id': workRequestId,
        'notification_type': type ?? 'general',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      debugPrint('[EmailNotificationService] Dispatching email to $email: "$title"');

      // 3. Invoke Supabase Edge Function 'send-email' if available
      try {
        await _db.functions.invoke('send-email', body: payload);
        debugPrint('[EmailNotificationService] Successfully delivered email payload to edge function.');
      } catch (e) {
        // Edge function might not be deployed yet or SMTP keys pending.
        // We log clearly and continue so UI is never blocked and no uncaught error occurs.
        debugPrint('[EmailNotificationService] Email function invoke notice: $e');
      }
    } catch (e) {
      debugPrint('[EmailNotificationService] sendNotificationEmail error: $e');
    }
  }

  /// Dispatches email notifications to active users of specific roles whose email settings are enabled.
  static Future<void> sendRoleNotificationEmails({
    required List<String> targetRoles,
    required String title,
    required String message,
    String? workRequestId,
    String? type,
  }) async {
    if (targetRoles.isEmpty) return;

    try {
      final normalizedRoles = targetRoles.map((r) => r.toLowerCase()).toList();

      var query = _db.from('users').select('id, email, name, role').eq('is_active', true);
      if (!normalizedRoles.contains('all')) {
        query = query.inFilter('role', normalizedRoles);
      }

      final users = await query;
      if (users.isEmpty) return;

      for (final u in users) {
        final userId = u['id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          await sendNotificationEmail(
            targetUserId: userId,
            title: title,
            message: message,
            workRequestId: workRequestId,
            type: type,
          );
        }
      }
    } catch (e) {
      debugPrint('[EmailNotificationService] sendRoleNotificationEmails error: $e');
    }
  }
}
