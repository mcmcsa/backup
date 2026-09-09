import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Inspect Database Rooms and Work Requests', () async {
    print('Setting up mock shared preferences...');
    SharedPreferences.setMockInitialValues({});
    
    print('Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://koszfvvodjctiytbflup.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtvc3pmdnZvZGpjdGl5dGJmbHVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1OTQ0NjksImV4cCI6MjA4NzE3MDQ2OX0.2HcgNVQkDfJnMB7XqVgKilMER-eFF8Va--VIJx_zjts',
    );
    
    final db = Supabase.instance.client;
    print('Logging in as sysadmin...');
    try {
      final res = await db.auth.signInWithPassword(
        email: 'sysadmin@psu.edu.ph',
        password: 'SysAdmin2026!',
      );
      print('Login success! User ID: ${res.user?.id}');
    } catch (e) {
      print('Login failed: $e');
    }

    print('\n=== Buildings in Database ===');
    try {
      final bldData = await db.from('buildings').select();
      print('Buildings count: ${bldData.length}');
      for (final b in bldData) {
        print('Building: $b');
      }
    } catch (e) {
      print('Error fetching buildings: $e');
    }

    print('\n=== Departments in Database ===');
    try {
      final deptData = await db.from('departments').select();
      print('Departments count: ${deptData.length}');
    } catch (e) {
      print('Error fetching departments: $e');
    }

    print('\n=== Rooms in Database ===');
    try {
      final roomsData = await db.from('rooms').select('*, buildings(name), departments(name), room_types(name)');
      print('Rooms with joins count: ${roomsData.length}');
      for (final room in roomsData) {
        print('Room: $room');
      }
    } catch (e) {
      print('Error fetching rooms with joins: $e');
    }

    try {
      final rawRooms = await db.from('rooms').select();
      print('Raw rooms count: ${rawRooms.length}');
      for (final r in rawRooms) {
        print('Raw room: $r');
      }
    } catch (e) {
      print('Error fetching raw rooms: $e');
    }

    print('\n=== Active Work Requests in Database ===');
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
  });
}
