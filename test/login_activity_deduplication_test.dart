import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/shared/services/login_activity_service.dart';

void main() {
  group('LoginActivity Philippine Time & Deduplication Tests', () {
    test('toPhilippineTime converts UTC timestamp to UTC+8 (Philippine Standard Time)', () {
      // 10:18:00 UTC = 18:18:00 (6:18 PM) in the Philippines
      final utcTime = DateTime.utc(2026, 9, 7, 10, 18, 0);
      final pht = LoginActivity.toPhilippineTime(utcTime);

      expect(pht.year, 2026);
      expect(pht.month, 9);
      expect(pht.day, 7);
      expect(pht.hour, 18);
      expect(pht.minute, 18);
    });

    test('toPhilippineTime handles legacy rows stored directly with local time', () {
      // Suppose current UTC time is nowUtc. A legacy row was stored with local time (+8 hours ahead of UTC).
      final nowUtc = DateTime.now().toUtc();
      final legacyStored = nowUtc.add(const Duration(hours: 8));
      final pht = LoginActivity.toPhilippineTime(legacyStored);

      // Hour should remain the legacyStored hour, NOT bumped another 8 hours
      expect(pht.day, legacyStored.day);
      expect(pht.hour, legacyStored.hour);
      expect(pht.minute, legacyStored.minute);
    });

    test('LoginActivity.fromMap correctly parses ISO strings into Philippine time', () {
      final map = {
        'user_id': 'u1',
        'user_name': 'Hannah Bangyan',
        'role': 'teacher',
        'event_type': 'login',
        'title': 'Teacher Login',
        'details': 'Logged in to the system',
        'logged_at': '2026-09-07T10:19:09.943Z',
      };

      final activity = LoginActivity.fromMap(map);
      expect(activity.loggedInAt.hour, 18);
      expect(activity.loggedInAt.minute, 19);
    });
  });
}
