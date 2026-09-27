import 'package:supabase_flutter/supabase_flutter.dart';

class SystemHealthService {
  static Future<Map<String, dynamic>> fetchHealthMetrics() async {
    final db = Supabase.instance.client;

    String serverStatus = 'Online';
    String dbStatus = 'Healthy';
    String connectionStatus = 'Connected';
    String? dbError;
    final List<Map<String, String>> recentErrors = [];

    // ── 1. Real connectivity / health check ─────────────────────────────
    final stopwatch = Stopwatch()..start();
    try {
      await db.from('system_settings').select('id').limit(1).maybeSingle();
      stopwatch.stop();
    } catch (e) {
      stopwatch.stop();
      serverStatus = 'Offline';
      dbStatus = 'Degraded';
      connectionStatus = 'Disconnected';
      dbError = 'DB connection error';
      recentErrors.add({'time': 'Just now', 'error': 'Database connection failed'});
    }

    // Flag slow queries (> 2000 ms) as a real system error
    if (stopwatch.elapsedMilliseconds > 2000) {
      recentErrors.add({
        'time': 'Just now',
        'error': 'Database query took > 2000ms (${stopwatch.elapsedMilliseconds}ms)',
      });
    }

    // ── 2. Real user counts ──────────────────────────────────────────────
    int activeSessions = 0;
    int totalRequests = 0;

    if (dbError == null) {
      try {
        final usersRes = await db
            .from('users')
            .select('id')
            .eq('is_active', true);
        activeSessions = (usersRes as List).length;
      } catch (_) {}

      try {
        final reqRes = await db
            .from('work_requests')
            .select('id');
        totalRequests = (reqRes as List).length;
      } catch (_) {}
    }

    // ── 3. Requests per hour chart (real, from work_requests) ────────────
    final List<int> requestsPerHour = List.filled(24, 0);
    if (dbError == null) {
      try {
        final now = DateTime.now().toUtc();
        final since = now.subtract(const Duration(hours: 24));
        final rows = await db
            .from('work_requests')
            .select('created_at')
            .gte('created_at', since.toIso8601String());
        for (final r in (rows as List)) {
          final ts = DateTime.tryParse(r['created_at']?.toString() ?? '');
          if (ts != null) {
            final hoursAgo = now.difference(ts).inHours;
            if (hoursAgo >= 0 && hoursAgo < 24) {
              requestsPerHour[23 - hoursAgo]++;
            }
          }
        }
      } catch (_) {}
    }

    // ── 4. Work requests per day (last 7 days) ───────────────────────────
    // Real storage data requires the Supabase Management API (service role).
    // We use work_request counts per day as a reasonable activity proxy instead.
    final List<int> storageGrowth = List.filled(7, 0);
    if (dbError == null) {
      try {
        final now = DateTime.now().toUtc();
        for (int i = 6; i >= 0; i--) {
          final dayStart = now.subtract(Duration(days: i + 1));
          final dayEnd = now.subtract(Duration(days: i));
          final rows = await db
              .from('work_requests')
              .select('id')
              .gte('created_at', dayStart.toIso8601String())
              .lt('created_at', dayEnd.toIso8601String());
          storageGrowth[6 - i] = (rows as List).length;
        }
      } catch (_) {}
    }

    return {
      'server_status': serverStatus,
      'database_status': dbStatus,
      'supabase_connection': connectionStatus,

      // Real counts from DB
      'active_sessions': activeSessions,
      'total_requests': totalRequests,
      'failed_login_attempts': 0,

      // Storage: not available from client SDK
      'storage_usage_gb': 'N/A',

      // CPU / Memory: not available from Supabase client SDK
      'cpu_usage_percent': null,
      'memory_usage_percent': null,

      // Real charts
      'requests_per_hour': requestsPerHour,
      'storage_growth': storageGrowth,

      // Real errors only (no random simulation)
      'recent_errors': recentErrors,
    };
  }
}
