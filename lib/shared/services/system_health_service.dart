import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SystemHealthService {
  static Future<Map<String, dynamic>> fetchHealthMetrics() async {
    String serverStatus = 'Online';
    String dbStatus = 'Healthy';
    String connectionStatus = 'Connected';
    String? connectionError;

    try {
      final db = Supabase.instance.client;
      // Perform a lightweight query on system_settings to verify database response
      await db.from('system_settings').select('id').limit(1).maybeSingle();
    } catch (e) {
      serverStatus = 'Offline';
      dbStatus = 'Degraded';
      connectionStatus = 'Disconnected';
      connectionError = e.toString();
    }

    final random = Random();
    
    // Simulate metrics
    return {
      'server_status': serverStatus,
      'database_status': dbStatus,
      'supabase_connection': connectionStatus,
      'storage_usage_gb': (50 + random.nextDouble() * 20).toStringAsFixed(1),
      'memory_usage_percent': 40 + random.nextInt(40),
      'cpu_usage_percent': 10 + random.nextInt(60),
      'active_sessions': 120 + random.nextInt(50),
      'failed_login_attempts': random.nextInt(15),
      
      'storage_growth': List.generate(7, (i) => 40 + (i * 2) + random.nextInt(5)),
      'requests_per_hour': List.generate(24, (i) => 100 + random.nextInt(400)),
      
      'recent_errors': [
        if (connectionError != null) {'time': 'Just now', 'error': 'DB Connection Error: $connectionError'},
        if (random.nextBool()) {'time': '10 mins ago', 'error': 'Auth timeout - IP 192.168.1.45'},
        if (random.nextBool()) {'time': '1 hour ago', 'error': 'Failed to load image asset'},
        if (random.nextBool()) {'time': '3 hours ago', 'error': 'Database query took > 2000ms'},
        if (random.nextBool()) {'time': '5 hours ago', 'error': 'Missing permission for user X'},
      ]
    };
  }
}
