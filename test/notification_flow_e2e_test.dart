import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:psu_maintsystem/shared/services/app_settings_service.dart';
import 'package:psu_maintsystem/shared/services/app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NOTIFICATION SETTINGS - LIVE VERIFICATION', () {
    test('Verify all 8 toggle combinations adhere to requirements', () async {
      print('\n================================================================');
      print(' TEST 1: ALL 8 TOGGLE COMBINATIONS VALIDATION');
      print('================================================================');

      final combinations = [
        {'master': true, 'email': true, 'push': true, 'expPush': true, 'expEmail': true, 'desc': 'All ON'},
        {'master': true, 'email': true, 'push': false, 'expPush': false, 'expEmail': true, 'desc': 'Master+Email ON, Push OFF'},
        {'master': true, 'email': false, 'push': true, 'expPush': true, 'expEmail': false, 'desc': 'Master+Push ON, Email OFF'},
        {'master': true, 'email': false, 'push': false, 'expPush': false, 'expEmail': false, 'desc': 'Master ON, Sub-settings OFF'},
        {'master': false, 'email': true, 'push': true, 'expPush': false, 'expEmail': false, 'desc': 'Master OFF, Sub-settings ON (Suppressed)'},
        {'master': false, 'email': true, 'push': false, 'expPush': false, 'expEmail': false, 'desc': 'Master OFF, Email ON (Suppressed)'},
        {'master': false, 'email': false, 'push': true, 'expPush': false, 'expEmail': false, 'desc': 'Master OFF, Push ON (Suppressed)'},
        {'master': false, 'email': false, 'push': false, 'expPush': false, 'expEmail': false, 'desc': 'All OFF'},
      ];

      for (int i = 0; i < combinations.length; i++) {
        final c = combinations[i];
        final userId = 'user_combo_${i + 1}';

        await AppSettingsService.setNotificationSettings(
          notificationsEnabled: c['master'] as bool,
          emailNotifications: c['email'] as bool,
          pushNotifications: c['push'] as bool,
          userId: userId,
        );

        final isEnabled = await AppSettingsService.isNotificationsEnabled(userId: userId);
        final canPush = await AppSettingsService.canReceivePush(userId: userId);
        final canEmail = await AppSettingsService.canReceiveEmail(userId: userId);

        expect(isEnabled, equals(c['master'] as bool));
        expect(canPush, equals(c['expPush'] as bool));
        expect(canEmail, equals(c['expEmail'] as bool));

        print(' [PASS] Combo ${i + 1}: ${c['desc']} -> canPush=$canPush, canEmail=$canEmail, isEnabled=$isEnabled');
      }
    });

    test('Verify consistency across all user roles', () async {
      print('\n================================================================');
      print(' TEST 2: MULTI-ROLE CONSISTENCY TEST');
      print('================================================================');

      final roles = [
        {'role': 'Student / Teacher', 'userId': 'uid_teacher_001'},
        {'role': 'Campus Administrator', 'userId': 'uid_campadmin_002'},
        {'role': 'System Administrator', 'userId': 'uid_sysadmin_003'},
        {'role': 'Maintenance Staff', 'userId': 'uid_maintenance_004'},
      ];

      for (final r in roles) {
        final roleName = r['role']!;
        final uid = r['userId']!;

        // Scenario 1: Master ON, Push ON, Email ON
        await AppSettingsService.setNotificationSettings(
          notificationsEnabled: true,
          emailNotifications: true,
          pushNotifications: true,
          userId: uid,
        );

        expect(await AppSettingsService.canReceivePush(userId: uid), isTrue);
        expect(await AppSettingsService.canReceiveEmail(userId: uid), isTrue);

        // Scenario 2: Master OFF, Email ON, Push ON -> Must be suppressed!
        await AppSettingsService.setNotificationSettings(
          notificationsEnabled: false,
          emailNotifications: true,
          pushNotifications: true,
          userId: uid,
        );

        expect(await AppSettingsService.canReceivePush(userId: uid), isFalse);
        expect(await AppSettingsService.canReceiveEmail(userId: uid), isFalse);

        print(' [PASS] Role: $roleName ($uid) -> Works consistently (ON and Master-OFF suppression verified)');
      }
    });

    test('Verify per-user isolation and cross-session persistence', () async {
      print('\n================================================================');
      print(' TEST 3: PER-USER ISOLATION & CROSS-SESSION RESTORE');
      print('================================================================');

      const userA = 'user_alpha_role';
      const userB = 'user_beta_role';

      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: true,
        pushNotifications: false,
        userId: userA,
      );

      await AppSettingsService.setNotificationSettings(
        notificationsEnabled: true,
        emailNotifications: false,
        pushNotifications: true,
        userId: userB,
      );

      // Verify User A settings
      final aPush = await AppSettingsService.canReceivePush(userId: userA);
      final aEmail = await AppSettingsService.canReceiveEmail(userId: userA);
      expect(aPush, isFalse);
      expect(aEmail, isTrue);

      // Verify User B settings
      final bPush = await AppSettingsService.canReceivePush(userId: userB);
      final bEmail = await AppSettingsService.canReceiveEmail(userId: userB);
      expect(bPush, isTrue);
      expect(bEmail, isFalse);

      print(' [PASS] User Isolation: User A (Push=$aPush, Email=$aEmail) does not collide with User B (Push=$bPush, Email=$bEmail)');

      // Simulate next session / re-login
      final restoredA = await AppSettingsService.loadAndApplyForUser(userA);
      expect(restoredA['notificationsEnabled'], isTrue);
      expect(restoredA['emailNotifications'], isTrue);
      expect(restoredA['pushNotifications'], isFalse);

      print(' [PASS] Cross-Session Restore: Successfully restored User A settings on next session');
    });

    test('Verify badge count suppression when notifications disabled', () async {
      print('\n================================================================');
      print(' TEST 4: UNREAD BADGE COUNT SUPPRESSION');
      print('================================================================');

      const testUser = 'user_badge_check';
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
      print(' [PASS] Unread badge count is strictly $unreadCount when Master Toggle is OFF');
      print('================================================================\n');
    });
  });
}
