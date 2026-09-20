import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://koszfvvodjctiytbflup.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtvc3pmdnZvZGpjdGl5dGJmbHVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1OTQ0NjksImV4cCI6MjA4NzE3MDQ2OX0.2HcgNVQkDfJnMB7XqVgKilMER-eFF8Va--VIJx_zjts';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  try {
    final notifs = await client
        .from('app_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(10);
    print('LATEST 10 NOTIFICATIONS:');
    for (final n in notifs) {
      print('id: ${n['id']}, title: ${n['title']}, target_role: ${n['target_role']}, target_user_id: ${n['target_user_id']}, type: ${n['type']}, msg: ${n['message']}');
    }

    final devices = await client.from('user_devices').select();
    print('\nUSER DEVICES (${devices.length}):');
    for (final d in devices) {
      print('user_id: ${d['user_id']}, platform: ${d['platform']}, token: ${(d['fcm_token'] as String?)?.substring(0, 15)}...');
    }

    final users = await client.from('users').select('id, name, email, role');
    print('\nUSERS:');
    for (final u in users) {
      print('id: ${u['id']}, name: ${u['name']}, email: ${u['email']}, role: ${u['role']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
