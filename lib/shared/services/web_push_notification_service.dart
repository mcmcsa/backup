import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'app_settings_service.dart';

class WebPushNotificationService {
  WebPushNotificationService._();

  static RealtimeChannel? _webChannel;
  static StreamSubscription<void>? _settingsSub;

  /// Check if the browser supports the HTML5 Notifications API
  static bool get isSupported {
    if (!kIsWeb) return false;
    try {
      return html.Notification.supported;
    } catch (_) {
      return false;
    }
  }

  /// Check if browser notification permission is currently granted
  static bool get hasPermission {
    if (!kIsWeb) return false;
    try {
      return html.Notification.supported && html.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  /// Request browser notification permission if supported
  static Future<bool> requestPermission() async {
    if (!kIsWeb) return false;
    try {
      if (html.Notification.supported) {
        if (html.Notification.permission == 'granted') return true;
        final result = await html.Notification.requestPermission();
        return result == 'granted';
      }
    } catch (e) {
      debugPrint('[WebPushNotificationService] requestPermission error: $e');
    }
    return false;
  }

  /// Trigger native browser push notification
  static void showBrowserNotification({
    required String title,
    required String message,
    String? icon,
    String? payload,
  }) {
    if (!kIsWeb) return;
    try {
      if (html.Notification.supported && html.Notification.permission == 'granted') {
        html.Notification(
          title,
          body: message,
          icon: icon ?? 'icons/Icon-192.png',
        );
        debugPrint('[WebPushNotificationService] Native browser notification shown: $title');
      }
    } catch (e) {
      debugPrint('[WebPushNotificationService] showBrowserNotification error: $e');
    }
  }

  /// Starts listening to Supabase Realtime for instant browser push notifications when on Web
  static void startWatcher(String userId, String userRole) {
    if (!kIsWeb || userId.isEmpty) return;

    _settingsSub?.cancel();
    _settingsSub = AppSettingsService.changes.listen((_) async {
      final canPush = await AppSettingsService.canReceivePush(userId: userId);
      if (canPush && !hasPermission) {
        await requestPermission();
      }
    });

    _webChannel?.unsubscribe();
    _webChannel = Supabase.instance.client
        .channel('web_push_watcher_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final targetUserId = newRecord['target_user_id']?.toString().trim();
            final targetRole = newRecord['target_role']?.toString().trim();

            // Strict recipient matching
            final hasTargetUser = targetUserId != null && targetUserId.isNotEmpty;
            if (hasTargetUser) {
              if (targetUserId != userId) return;
            } else {
              final normalizedUserRole = userRole.toLowerCase().trim();
              final normalizedTargetRole = (targetRole ?? 'all').toLowerCase().trim();

              // Maintenance users NEVER receive role-broadcast notifications for tickets.
              // They only receive global announcements ('all') or direct notifications (target_user_id == userId).
              if (normalizedUserRole == 'maintenance') {
                if (normalizedTargetRole != 'all') return;
              }

              final isAdminUser = normalizedUserRole == 'campadmin' || normalizedUserRole == 'admin';
              final isAdminTarget = normalizedTargetRole == 'admin' || normalizedTargetRole == 'campadmin';

              final matchesRole = normalizedTargetRole == 'all' ||
                  normalizedTargetRole == normalizedUserRole ||
                  (isAdminUser && isAdminTarget);
              if (!matchesRole) return;
            }

            // Strictly evaluate user notification settings:
            // if (enableNotifications === true && pushNotifications === true) -> push alert
            final canPush = await AppSettingsService.canReceivePush(userId: userId);
            if (!canPush) {
              debugPrint('[WebPushNotificationService] Push notification suppressed by user settings.');
              return;
            }

            final title = newRecord['title']?.toString() ?? 'PSU E-ayos Notification';
            final body = newRecord['message']?.toString() ?? '';
            final targetPage = newRecord['target_page']?.toString();

            showBrowserNotification(
              title: title,
              message: body,
              payload: targetPage,
            );
          },
        )
        .subscribe();

    debugPrint('[WebPushNotificationService] Web push watcher started for user $userId ($userRole).');
  }

  static void stopWatcher() {
    _settingsSub?.cancel();
    _settingsSub = null;
    _webChannel?.unsubscribe();
    _webChannel = null;
  }
}
