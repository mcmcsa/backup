import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettingsService {
  static const String _notificationsEnabledKey = 'settings_notifications_enabled';
  static const String _emailNotificationsKey = 'settings_email_notifications';
  static const String _pushNotificationsKey = 'settings_push_notifications';
  static const String _qrRegenerationEnabledKey = 'settings_qr_regeneration_enabled';

  // Broadcast stream to notify listeners (navigation shells, notification views) when settings change
  static final StreamController<void> _changesController = StreamController<void>.broadcast();
  static Stream<void> get changes => _changesController.stream;

  static void notifyChanged() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  static String _scopedKey(String baseKey, String? userId) {
    final uid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : Supabase.instance.client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      return '${baseKey}_$uid';
    }
    return baseKey;
  }

  static Future<Map<String, bool>> getNotificationSettings({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedNotifKey = _scopedKey(_notificationsEnabledKey, userId);
    final scopedEmailKey = _scopedKey(_emailNotificationsKey, userId);
    final scopedPushKey = _scopedKey(_pushNotificationsKey, userId);

    // Check user_metadata from Supabase Auth as secondary fallback
    final currentUser = Supabase.instance.client.auth.currentUser;
    final meta = currentUser?.userMetadata;

    final metaNotif = meta?['notifications_enabled'];
    final metaEmail = meta?['email_notifications'];
    final metaPush = meta?['push_notifications'];

    final bool notificationsEnabled = prefs.getBool(scopedNotifKey) ??
        prefs.getBool(_notificationsEnabledKey) ??
        (metaNotif is bool ? metaNotif : true);

    final bool emailNotifications = prefs.getBool(scopedEmailKey) ??
        prefs.getBool(_emailNotificationsKey) ??
        (metaEmail is bool ? metaEmail : false);

    final bool pushNotifications = prefs.getBool(scopedPushKey) ??
        prefs.getBool(_pushNotificationsKey) ??
        (metaPush is bool ? metaPush : true);

    return {
      'notificationsEnabled': notificationsEnabled,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
    };
  }

  /// Master switch check: Can the user receive any in-app notification or badge?
  static Future<bool> isNotificationsEnabled({String? userId}) async {
    final settings = await getNotificationSettings(userId: userId);
    return settings['notificationsEnabled'] ?? true;
  }

  /// Master switch check: Can the user receive any push/banner alert?
  /// Must have BOTH master switch ON and Push Notifications ON.
  static Future<bool> canReceivePush({String? userId}) async {
    final settings = await getNotificationSettings(userId: userId);
    final master = settings['notificationsEnabled'] ?? true;
    final push = settings['pushNotifications'] ?? true;
    return master && push;
  }

  /// Master switch check: Can the user receive email alerts?
  /// Must have BOTH master switch ON and Email Notifications ON.
  static Future<bool> canReceiveEmail({String? userId}) async {
    final settings = await getNotificationSettings(userId: userId);
    final master = settings['notificationsEnabled'] ?? true;
    final email = settings['emailNotifications'] ?? false;
    return master && email;
  }

  static Future<void> setNotificationSettings({
    required bool notificationsEnabled,
    required bool emailNotifications,
    required bool pushNotifications,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final scopedNotifKey = _scopedKey(_notificationsEnabledKey, userId);
    final scopedEmailKey = _scopedKey(_emailNotificationsKey, userId);
    final scopedPushKey = _scopedKey(_pushNotificationsKey, userId);

    // Save to user-scoped key
    await prefs.setBool(scopedNotifKey, notificationsEnabled);
    await prefs.setBool(scopedEmailKey, emailNotifications);
    await prefs.setBool(scopedPushKey, pushNotifications);

    // Also update global fallback key
    await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
    await prefs.setBool(_emailNotificationsKey, emailNotifications);
    await prefs.setBool(_pushNotificationsKey, pushNotifications);

    // Sync preference to Supabase Auth metadata for persistent cross-device consistency
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'notifications_enabled': notificationsEnabled,
              'email_notifications': emailNotifications,
              'push_notifications': pushNotifications,
            },
          ),
        );
      }
    } catch (_) {
      // Ignore if offline or rate limited
    }

    // Sync preference to user_devices table in Supabase so server/edge function knows whether to push
    try {
      final user = userId ?? Supabase.instance.client.auth.currentUser?.id;
      if (user != null && !kIsWeb) {
        final platform = defaultTargetPlatform.name.toLowerCase();
        await Supabase.instance.client
            .from('user_devices')
            .update({
              'push_enabled': notificationsEnabled && pushNotifications,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', user)
            .eq('platform', platform);
      }
    } catch (_) {
      // Ignore if column doesn't exist or offline
    }

    // Notify all active listeners across app (Navigation shells, Notification lists)
    notifyChanged();
  }

  static Future<bool> isQrRegenerationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_qrRegenerationEnabledKey) ?? false;
  }

  static Future<void> setQrRegenerationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_qrRegenerationEnabledKey, enabled);
  }
}
