import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:psu_maintsystem/shared/services/app_settings_service.dart';
import 'package:psu_maintsystem/shared/services/app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notification Settings - Toggle Logic & Combinations', () {
    test('Combo 1: Master=ON, Email=ON, Push=ON -> both can receive', () async {
      const testUser = 'user-combo-1';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: true,
        pushNotifications: true,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isTrue);
      expect(canPush, isTrue);
      expect(canEmail, isTrue);
    });

    test('Combo 2: Master=ON, Email=ON, Push=OFF -> email allowed, push suppressed', () async {
      const testUser = 'user-combo-2';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: true,
        pushNotifications: false,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isTrue);
      expect(canPush, isFalse);
      expect(canEmail, isTrue);
    });

    test('Combo 3: Master=ON, Email=OFF, Push=ON -> push allowed, email suppressed', () async {
      const testUser = 'user-combo-3';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: false,
        pushNotifications: true,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isTrue);
      expect(canPush, isTrue);
      expect(canEmail, isFalse);
    });

    test('Combo 4: Master=ON, Email=OFF, Push=OFF -> both suppressed', () async {
      const testUser = 'user-combo-4';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: false,
        pushNotifications: false,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isTrue);
      expect(canPush, isFalse);
      expect(canEmail, isFalse);
    });

    test('Combo 5: Master=OFF, Email=ON, Push=ON -> master suppresses all (no email, no push)', () async {
      const testUser = 'user-combo-5';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: false,
        emailNotifications: true,
        pushNotifications: true,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isFalse);
      expect(canPush, isFalse);
      expect(canEmail, isFalse);
    });

    test('Combo 6: Master=OFF, Email=ON, Push=OFF -> master suppresses all', () async {
      const testUser = 'user-combo-6';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: false,
        emailNotifications: true,
        pushNotifications: false,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isFalse);
      expect(canPush, isFalse);
      expect(canEmail, isFalse);
    });

    test('Combo 7: Master=OFF, Email=OFF, Push=ON -> master suppresses all', () async {
      const testUser = 'user-combo-7';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: false,
        emailNotifications: false,
        pushNotifications: true,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isFalse);
      expect(canPush, isFalse);
      expect(canEmail, isFalse);
    });

    test('Combo 8: Master=OFF, Email=OFF, Push=OFF -> all OFF', () async {
      const testUser = 'user-combo-8';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: false,
        emailNotifications: false,
        pushNotifications: false,
        userId: testUser,
      );

      final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: testUser);
      final canPush = await AppSettingsService.canReceivePush(userId: testUser);
      final canEmail = await AppSettingsService.canReceiveEmail(userId: testUser);

      expect(isEnabled, isFalse);
      expect(canPush, isFalse);
      expect(canEmail, isFalse);
    });
  });

  group('Per-User Storage & Scoping Isolation', () {
    test('Settings for User A do not conflict with or affect User B', () async {
      const userTeacher = 'uuid-teacher-101';
      const userAdmin = 'uuid-admin-202';
      const userMaint = 'uuid-maintenance-303';

      // Teacher: Master=ON, Email=ON, Push=ON
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: true,
        pushNotifications: true,
        userId: userTeacher,
      );

      // Admin: Master=OFF, Email=OFF, Push=OFF
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: false,
        emailNotifications: false,
        pushNotifications: false,
        userId: userAdmin,
      );

      // Maintenance: Master=ON, Email=OFF, Push=ON
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: false,
        pushNotifications: true,
        userId: userMaint,
      );

      // Verify Teacher
      expect(await AppSettingsService.isNotificationsEnabled(userId: userTeacher), isTrue);
      expect(await AppSettingsService.canReceivePush(userId: userTeacher), isTrue);
      expect(await AppSettingsService.canReceiveEmail(userId: userTeacher), isTrue);

      // Verify Admin
      expect(await AppSettingsService.isNotificationsEnabled(userId: userAdmin), isFalse);
      expect(await AppSettingsService.canReceivePush(userId: userAdmin), isFalse);
      expect(await AppSettingsService.canReceiveEmail(userId: userAdmin), isFalse);

      // Verify Maintenance
      expect(await AppSettingsService.isNotificationsEnabled(userId: userMaint), isTrue);
      expect(await AppSettingsService.canReceivePush(userId: userMaint), isTrue);
      expect(await AppSettingsService.canReceiveEmail(userId: userMaint), isFalse);
    });
  });

  group('AppNotificationService - Unread Count Suppression', () {
    test('getUnreadCount returns 0 when master notifications is OFF', () async {
      const testUser = 'user-notifications-disabled';
      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: false,
        emailNotifications: true,
        pushNotifications: true,
        userId: testUser,
      );

      final unreadCount = await AppNotificationService.getUnreadCount(
        role: 'teacher',
        userId: testUser,
      );

      expect(unreadCount, equals(0));
    });
  });
}
