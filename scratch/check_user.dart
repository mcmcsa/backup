import 'package:supabase/supabase.dart';

const String supabaseUrl = 'https://koszfvvodjctiytbflup.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtvc3pmdnZvZGpjdGl5dGJmbHVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1OTQ0NjksImV4cCI6MjA4NzE3MDQ2OX0.2HcgNVQkDfJnMB7XqVgKilMER-eFF8Va--VIJx_zjts';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  try {
    final user = await client.from('users').select().eq('id', '04cd0d72-d0af-499b-ae7d-ebbfb443c40f').maybeSingle();
    print('USER 04cd0d72...: $user');

    final user2 = await client.from('users').select().eq('id', 'eb942851-4f8d-41d7-917c-fe3c31703df3').maybeSingle();
    print('USER eb942851...: $user2');

    final req = await client.from('work_requests').select().order('created_at', ascending: false).limit(2);
    print('LATEST WORK REQUESTS: $req');
  } catch (e) {
    print('Error: $e');
  }
}
