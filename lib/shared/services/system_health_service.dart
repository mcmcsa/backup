import 'dart:math';

class SystemHealthService {
  static Future<Map<String, dynamic>> fetchHealthMetrics() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final random = Random();
    
    // Simulate metrics
    return {
      'server_status': 'Online',
      'database_status': 'Healthy',
      'supabase_connection': 'Connected',
      'storage_usage_gb': (50 + random.nextDouble() * 20).toStringAsFixed(1),
      'memory_usage_percent': 40 + random.nextInt(40),
      'cpu_usage_percent': 10 + random.nextInt(60),
      'active_sessions': 120 + random.nextInt(50),
      'failed_login_attempts': random.nextInt(15),
      
      'storage_growth': List.generate(7, (i) => 40 + (i * 2) + random.nextInt(5)),
      'requests_per_hour': List.generate(24, (i) => 100 + random.nextInt(400)),
      
      'recent_errors': [
        if (random.nextBool()) {'time': '10 mins ago', 'error': 'Auth timeout - IP 192.168.1.45'},
        if (random.nextBool()) {'time': '1 hour ago', 'error': 'Failed to load image asset'},
        if (random.nextBool()) {'time': '3 hours ago', 'error': 'Database query took > 2000ms'},
        if (random.nextBool()) {'time': '5 hours ago', 'error': 'Missing permission for user X'},
      ]
    };
  }
}
