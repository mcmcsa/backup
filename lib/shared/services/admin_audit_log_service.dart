import 'package:supabase_flutter/supabase_flutter.dart';

import '../../authentication/models/user_model.dart';
import 'login_activity_service.dart';

class AdminAuditLogService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> logAction({
    required String title,
    String? details,
    String? workRequestId,
  }) async {
    try {
      final authUser = _db.auth.currentUser;
      if (authUser == null) return;

      final profile = await _db.from('users').select().eq('id', authUser.id).maybeSingle();
      if (profile == null) return;

      final user = AppUser.fromMap(Map<String, dynamic>.from(profile as Map));
      await LoginActivityService.recordAdminAction(
        user: user,
        title: title,
        details: details,
        workRequestId: workRequestId,
      );
    } catch (_) {
      // Logging should never break primary business operations.
    }
  }
}