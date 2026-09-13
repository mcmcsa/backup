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

  /// Safe accessor for SupabaseClient that does not throw if Supabase is uninitialized (e.g. in tests)
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Safe accessor for current authenticated user ID
  static String? get _currentAuthUserId {
    try {
      return _client?.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static String _scopedKey(String baseKey, String? userId) {
    final uid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : _currentAuthUserId;
    if (uid != null && uid.isNotEmpty) {
      return '${baseKey}_$uid';
    }
    return baseKey;
  }

  /// Fetches notification settings with multi-tiered resolution:
  /// 1. Supabase database table `user_notification_settings` (primary per-user persistent store)
  /// 2. Supabase Auth `user_metadata` (cross-session cloud store for current user)
  /// 3. Local user-scoped `SharedPreferences`
  /// 4. System defaults (notificationsEnabled: true, emailNotifications: false, pushNotifications: true)
  static Future<Map<String, bool>> getNotificationSettings({
    String? userId,
    bool forceDbFetch = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : _currentAuthUserId;

    final scopedNotifKey = _scopedKey(_notificationsEnabledKey, uid);
    final scopedEmailKey = _scopedKey(_emailNotificationsKey, uid);
    final scopedPushKey = _scopedKey(_pushNotificationsKey, uid);

    bool? cachedNotif = prefs.getBool(scopedNotifKey);
    bool? cachedEmail = prefs.getBool(scopedEmailKey);
    bool? cachedPush = prefs.getBool(scopedPushKey);

    final client = _client;

    // 1. Primary: Try fetching from database table `user_notification_settings`
    if (uid != null && uid.isNotEmpty && client != null) {
      try {
        final res = await client
            .from('user_notification_settings')
            .select('notifications_enabled, email_notifications, push_notifications')
            .eq('user_id', uid)
            .maybeSingle();

        if (res != null) {
          final bool dbNotif = res['notifications_enabled'] == true;
          final bool dbEmail = res['email_notifications'] == true;
          final bool dbPush = res['push_notifications'] == true;

          // Cache in SharedPreferences
          await prefs.setBool(scopedNotifKey, dbNotif);
          await prefs.setBool(scopedEmailKey, dbEmail);
          await prefs.setBool(scopedPushKey, dbPush);

          return {
            'notificationsEnabled': dbNotif,
            'emailNotifications': dbEmail,
            'pushNotifications': dbPush,
          };
        }
      } catch (_) {
        // Table may not exist yet or user is offline — gracefully continue to fallback
      }
    }

    // 2. Secondary: Fallback to Supabase Auth metadata for current logged-in user
    if (uid != null && client != null) {
      final currentUser = client.auth.currentUser;
      if (currentUser != null && currentUser.id == uid) {
        final meta = currentUser.userMetadata;
        final metaNotif = meta?['notifications_enabled'];
        final metaEmail = meta?['email_notifications'];
        final metaPush = meta?['push_notifications'];

        if (metaNotif is bool || metaEmail is bool || metaPush is bool) {
          final bool notifVal = (metaNotif is bool) ? metaNotif : (cachedNotif ?? true);
          final bool emailVal = (metaEmail is bool) ? metaEmail : (cachedEmail ?? false);
          final bool pushVal = (metaPush is bool) ? metaPush : (cachedPush ?? true);

          // Update local cache
          await prefs.setBool(scopedNotifKey, notifVal);
          await prefs.setBool(scopedEmailKey, emailVal);
          await prefs.setBool(scopedPushKey, pushVal);

          return {
            'notificationsEnabled': notifVal,
            'emailNotifications': emailVal,
            'pushNotifications': pushVal,
          };
        }
      }
    }

    // 3. Tertiary: Local SharedPreferences
    final bool notificationsEnabled = cachedNotif ??
        prefs.getBool(_notificationsEnabledKey) ??
        true;

    final bool emailNotifications = cachedEmail ??
        prefs.getBool(_emailNotificationsKey) ??
        false;

    final bool pushNotifications = cachedPush ??
        prefs.getBool(_pushNotificationsKey) ??
        true;

    return {
      'notificationsEnabled': notificationsEnabled,
      'emailNotifications': emailNotifications,
      'pushNotifications': pushNotifications,
    };
  }

  /// Master switch check: Can the user receive any in-app notification, alert or badge?
  static Future<bool> isNotificationsEnabled({String? userId}) async {
    final settings = await getNotificationSettings(userId: userId);
    return settings['notificationsEnabled'] ?? true;
  }

  /// Push notifications check:
  /// Logic: if (enableNotifications === true) { if (pushNotifications === true) -> push } else { false }
  static Future<bool> canReceivePush({String? userId}) async {
    final settings = await getNotificationSettings(userId: userId);
    final master = settings['notificationsEnabled'] ?? true;
    final push = settings['pushNotifications'] ?? true;
    return master && push;
  }

  /// Email notifications check:
  /// Logic: if (enableNotifications === true) { if (emailNotifications === true) -> email } else { false }
  static Future<bool> canReceiveEmail({String? userId}) async {
    final settings = await getNotificationSettings(userId: userId);
    final master = settings['notificationsEnabled'] ?? true;
    final email = settings['emailNotifications'] ?? false;
    return master && email;
  }

  /// Saves notification settings to:
  /// 1. User-scoped SharedPreferences (local cache for zero-latency UI)
  /// 2. Database table `user_notification_settings` (primary DB store)
  /// 3. Supabase Auth `user_metadata` (cross-device cloud store)
  /// 4. `user_devices` table (mobile push activation)
  static Future<void> setNotificationSettings({
    required bool notificationsEnabled,
    required bool emailNotifications,
    required bool pushNotifications,
    String? userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : _currentAuthUserId;

    final scopedNotifKey = _scopedKey(_notificationsEnabledKey, uid);
    final scopedEmailKey = _scopedKey(_emailNotificationsKey, uid);
    final scopedPushKey = _scopedKey(_pushNotificationsKey, uid);

    // Save to user-scoped key
    await prefs.setBool(scopedNotifKey, notificationsEnabled);
    await prefs.setBool(scopedEmailKey, emailNotifications);
    await prefs.setBool(scopedPushKey, pushNotifications);

    // Also update global fallback key
    await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
    await prefs.setBool(_emailNotificationsKey, emailNotifications);
    await prefs.setBool(_pushNotificationsKey, pushNotifications);

    final client = _client;

    // 1. Upsert into Supabase database table `user_notification_settings`
    if (uid != null && uid.isNotEmpty && client != null) {
      try {
        await client.from('user_notification_settings').upsert(
          {
            'user_id': uid,
            'notifications_enabled': notificationsEnabled,
            'email_notifications': emailNotifications,
            'push_notifications': pushNotifications,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      } catch (e) {
        debugPrint('[AppSettingsService] Note: user_notification_settings upsert fallback: $e');
      }
    }

    // 2. Sync preference to Supabase Auth metadata for persistent cross-device consistency
    if (client != null) {
      try {
        if (client.auth.currentUser != null && (uid == null || client.auth.currentUser!.id == uid)) {
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
    }

    // 3. Sync preference to user_devices table in Supabase so server/edge function knows whether to push
    if (client != null && uid != null && !kIsWeb) {
      try {
        final platform = defaultTargetPlatform.name.toLowerCase();
        await client
            .from('user_devices')
            .update({
              'push_enabled': notificationsEnabled && pushNotifications,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', uid)
            .eq('platform', platform);
      } catch (_) {
        // Ignore if column doesn't exist or offline
      }
    }

    // Notify all active listeners across app (Navigation shells, Notification lists)
    notifyChanged();
  }

  /// Automatically called upon login or session restore to load user settings from DB and apply them.
  static Future<Map<String, bool>> loadAndApplyForUser(String userId) async {
    final settings = await getNotificationSettings(userId: userId, forceDbFetch: true);
    notifyChanged();
    return settings;
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
