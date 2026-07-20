import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _notificationsEnabledKey = 'settings_notifications_enabled';
  static const String _emailNotificationsKey = 'settings_email_notifications';
  static const String _pushNotificationsKey = 'settings_push_notifications';
  static const String _qrRegenerationEnabledKey = 'settings_qr_regeneration_enabled';

  static Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'notificationsEnabled': prefs.getBool(_notificationsEnabledKey) ?? true,
      'emailNotifications': prefs.getBool(_emailNotificationsKey) ?? false,
      'pushNotifications': prefs.getBool(_pushNotificationsKey) ?? true,
    };
  }

  static Future<void> setNotificationSettings({
    required bool notificationsEnabled,
    required bool emailNotifications,
    required bool pushNotifications,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, notificationsEnabled);
    await prefs.setBool(_emailNotificationsKey, emailNotifications);
    await prefs.setBool(_pushNotificationsKey, pushNotifications);
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
