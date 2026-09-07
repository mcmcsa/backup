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
      // Suppose current UTC time is 10:30 UTC. A legacy row has 18:30 UTC (8 hours ahead of UTC).
      final legacyStored = DateTime.utc(2026, 9, 7, 18, 30, 0);
      final pht = LoginActivity.toPhilippineTime(legacyStored);

      // Hour should remain 18 (6:30 PM), NOT 02:30 AM next day
      expect(pht.day, 7);
      expect(pht.hour, 18);
      expect(pht.minute, 30);
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
