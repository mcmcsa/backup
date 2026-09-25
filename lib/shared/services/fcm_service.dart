import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings_service.dart';

// Background handler - must be top-level, annotated for tree-shake prevention
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FcmService] Background message: id=${message.messageId}, data=${message.data}');

  // If this was a data-only message (no system notification rendered by OS), show a local notification
  if (message.notification == null) {
    final title = message.data['title'] as String?;
    final body = message.data['body'] as String? ?? message.data['message'] as String?;
    final createdAtStr = message.data['created_at'] as String?;
    final whenTime = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;

    if (title != null && title.isNotEmpty) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.show(
        message.hashCode,
        title,
        body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'psu_mms_notifications',
            'PSU E-ayos Notifications',
            channelDescription: 'Alerts for work requests, approvals, and messages.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
            showWhen: true,
            when: whenTime,
            color: const Color(0xFF4169E1),
          ),
        ),
        payload: message.data['target_page'] as String?,
      );
    }
  }
}

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'psu_mms_notifications',
  'PSU E-ayos Notifications',
  description: 'Alerts for work requests, approvals, and messages.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

class FcmService {
  FcmService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static SupabaseClient get _db => Supabase.instance.client;
  static const String _devicesTable = 'user_devices';

  /// Standard branded notification styling with logo, app title, and real-time timestamp
  static AndroidNotificationDetails _buildAndroidNotificationDetails({
    int? whenTime,
  }) {
    return AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      showWhen: true,
      when: whenTime ?? DateTime.now().millisecondsSinceEpoch,
      color: const Color(0xFF4169E1),
    );
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[FcmService] Notification clicked with payload: ${response.payload}');
      },
    );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened via notification click from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FcmService] App opened from notification: ${message.data}');
    });

    // App opened via notification click from terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FcmService] App launched from terminated via notification: ${initialMessage.data}');
    }

    debugPrint('[FcmService] Initialized successfully.');
  }

  static RealtimeChannel? _realtimeChannel;
  static StreamSubscription<void>? _settingsSub;

  /// Subscribes to Supabase Realtime for instant heads-up banners on mobile when app is open/active
  static void startRealtimeNotificationWatcher(String userId, String userRole) {
    if (kIsWeb) return;
    if (userId.isEmpty) return;

    _settingsSub?.cancel();
    _settingsSub = AppSettingsService.changes.listen((_) async {
      final canPush = await AppSettingsService.canReceivePush(userId: userId);
      if (canPush) {
        await saveToken(userId);
      } else {
        await deleteToken(userId);
      }
    });

    _realtimeChannel?.unsubscribe();

    _realtimeChannel = _db
        .channel('mobile_notif_watcher_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final targetUserId = newRecord['target_user_id']?.toString().trim();
            final targetRole = newRecord['target_role']?.toString().trim();

            final notifType = (newRecord['type']?.toString() ?? '').toLowerCase().trim();
            final normalizedUserRole = userRole.toLowerCase().trim();

            // 0. Maintenance users trigger task acceptance, pre-inspection, post-repair, and completion.
            // Under NO circumstance should maintenance receive notifications for their own actions.
            if (normalizedUserRole == 'maintenance') {
              if (notifType == 'work_request_accepted' ||
                  notifType == 'pre_inspection_submitted' ||
                  notifType == 'post_repair_submitted' ||
                  notifType == 'work_request_completion_submitted') {
                debugPrint('[FcmService] Suppressed maintenance-action notification: $notifType');
                return;
              }
            }

            // STRICT FILTERING:
            // 1. If notification is targeted to a specific user (personal notification like chat/ticket),
            //    it MUST match the currently logged-in user id! If targetUserId is set and doesn't match userId, IGNORE.
            final hasTargetUser = targetUserId != null && targetUserId.isNotEmpty;
            if (hasTargetUser) {
              if (targetUserId != userId) {
                debugPrint('[FcmService] Suppressed notification intended for user $targetUserId (logged-in: $userId)');
                return;
              }
            } else {
              // 2. Only broadcast/role-based notifications (where target_user_id is not set) can match target_role.
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

            // Check master switch and push switch in user settings
            final canPush = await AppSettingsService.canReceivePush(userId: userId);
            if (!canPush) {
              debugPrint('[FcmService] Notification suppressed by user settings.');
              return;
            }

            final title = newRecord['title']?.toString() ?? 'PSU E-ayos Notification';
            final body = newRecord['message']?.toString() ?? '';
            final targetPage = newRecord['target_page']?.toString();
            final createdAtStr = newRecord['created_at']?.toString();
            final whenTime = createdAtStr != null
                ? DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch;
            final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

            debugPrint('[FcmService] Displaying Heads-Up Notification on device: $title');
            await _localNotifications.show(
              notifId,
              title,
              body,
              NotificationDetails(
                android: _buildAndroidNotificationDetails(whenTime: whenTime),
              ),
              payload: targetPage,
            );
          },
        )
        .subscribe();

    debugPrint('[FcmService] Realtime notification watcher started for user $userId ($userRole).');
  }

  static void stopRealtimeNotificationWatcher() {
    _settingsSub?.cancel();
    _settingsSub = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final canPush = await AppSettingsService.canReceivePush();
    if (!canPush) {
      debugPrint('[FcmService] Foreground message suppressed by user settings.');
      return;
    }

    // Recipient validation
    final targetUserId = message.data['target_user_id'] as String?;
    final currentUserId = _db.auth.currentUser?.id;
    if (targetUserId != null && targetUserId.isNotEmpty) {
      if (currentUserId == null || targetUserId != currentUserId) {
        debugPrint('[FcmService] Foreground message suppressed: target $targetUserId != current $currentUserId');
        return;
      }
    }

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String? ?? message.data['message'] as String?;
    final notifType = (message.data['type'] as String? ?? '').toLowerCase().trim();

    if (notifType == 'work_request_accepted' ||
        notifType == 'pre_inspection_submitted' ||
        notifType == 'post_repair_submitted' ||
        notifType == 'work_request_completion_submitted') {
      try {
        final currentId = _db.auth.currentUser?.id;
        if (currentId != null) {
          final u = await _db.from('users').select('role').eq('id', currentId).maybeSingle();
          if (u != null && u['role']?.toString().toLowerCase().trim() == 'maintenance') {
            debugPrint('[FcmService] Foreground message suppressed for maintenance actor: $notifType');
            return;
          }
        }
      } catch (_) {}
    }

    final createdAtStr = message.data['created_at'] as String?;
    final whenTime = createdAtStr != null
        ? DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch
        : DateTime.now().millisecondsSinceEpoch;

    if (title != null && title.isNotEmpty) {
      debugPrint('[FcmService] Foreground message displayed: title=$title');
      await _localNotifications.show(
        message.hashCode,
        title,
        body ?? '',
        NotificationDetails(
          android: _buildAndroidNotificationDetails(whenTime: whenTime),
        ),
        payload: message.data['target_page'] as String?,
      );
    }
  }

  static Future<void> saveToken(String userId) async {
    if (kIsWeb) return;
    if (userId.isEmpty) return;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FcmService] FCM token unavailable — skipping save.');
        return;
      }

      final canPush = await AppSettingsService.canReceivePush(userId: userId);
      final platform = defaultTargetPlatform.name.toLowerCase();

      // 1. Purge this physical device token from any OTHER user accounts
      // to ensure no cross-account notification leak on shared or switched devices.
      await _db
          .from(_devicesTable)
          .delete()
          .eq('fcm_token', token)
          .neq('user_id', userId);

      // 2. Associate token exclusively with the currently logged-in user
      await _db.from(_devicesTable).upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id, platform',
      );

      debugPrint('[FcmService] FCM token saved exclusively for user $userId (canPush: $canPush).');

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _refreshToken(userId, newToken);
      });
    } catch (e) {
      debugPrint('[FcmService] saveToken error: $e');
    }
  }

  static Future<void> _refreshToken(String userId, String newToken) async {
    if (kIsWeb) return;
    try {
      final platform = defaultTargetPlatform.name.toLowerCase();

      // Purge token from other users before refreshing
      await _db
          .from(_devicesTable)
          .delete()
          .eq('fcm_token', newToken)
          .neq('user_id', userId);

      await _db.from(_devicesTable).upsert(
        {
          'user_id': userId,
          'fcm_token': newToken,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id, platform',
      );
      debugPrint('[FcmService] FCM token refreshed for user $userId.');
    } catch (e) {
      debugPrint('[FcmService] _refreshToken error: $e');
    }
  }

  static Future<void> deleteToken(String userId) async {
    if (kIsWeb) return;
    stopRealtimeNotificationWatcher();
    if (userId.isEmpty) return;

    try {
      final platform = defaultTargetPlatform.name.toLowerCase();
      await _db
          .from(_devicesTable)
          .delete()
          .eq('user_id', userId)
          .eq('platform', platform);
      debugPrint('[FcmService] FCM token removed for user $userId.');
    } catch (e) {
      debugPrint('[FcmService] deleteToken error: $e');
    }
  }
}
