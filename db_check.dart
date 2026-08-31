import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://koszfvvodjctiytbflup.supabase.co',
    anonKey: 'sb_publishable_39jKzuDntPex2oZgplFxqg_JKLbKkDB',
  );
  
  final db = Supabase.instance.client;
  print('\n=== Rooms ===');
  try {
    final roomsData = await db.from('rooms').select('id, code, name, status');
    for (final room in roomsData) {
      print('Room ID: ${room['id']} | Code: ${room['code']} | Name: ${room['name']} | Status: ${room['status']}');
    }
  } catch (e) {
    print('Error fetching rooms: $e');
  }

  print('\n=== Active Work Requests ===');
  try {
    final wrData = await db.from('work_requests').select('id, room_id, status, title').neq('status', 'Completed').neq('status', 'Declined');
    if (wrData.isEmpty) {
      print('No active work requests found.');
    } else {
      for (final wr in wrData) {
        print('Request ID: ${wr['id']} | Room ID: ${wr['room_id']} | Status: ${wr['status']} | Title: ${wr['title']}');
      }
    }
  } catch (e) {
    print('Error fetching work requests: $e');
  }
}
