import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_model.dart';

class ScheduleService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'room_schedules';

  static Future<List<RoomSchedule>> fetchByRoom(String roomId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('room_id', roomId)
        .eq('is_maintenance_window', false)
        .order('scheduled_date', ascending: true)
        .order('start_time', ascending: true);
    return (data as List).map((e) => RoomSchedule.fromMap(e)).toList();
  }

  static Future<List<RoomSchedule>> fetchMaintenanceWindowsByRoom(String roomId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('room_id', roomId)
        .eq('is_maintenance_window', true)
        .order('scheduled_date', ascending: true);
    return (data as List).map((e) => RoomSchedule.fromMap(e)).toList();
  }

  static Future<List<RoomSchedule>> fetchAll() async {
    final data = await _db
        .from(_table)
        .select()
        .eq('is_maintenance_window', false)
        .order('scheduled_date', ascending: true)
        .order('start_time', ascending: true);
    return (data as List).map((e) => RoomSchedule.fromMap(e)).toList();
  }

  static Future<List<RoomSchedule>> fetchByDate(String roomId, String date) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('room_id', roomId)
        .eq('scheduled_date', date)
        .order('start_time', ascending: true);
    return (data as List).map((e) => RoomSchedule.fromMap(e)).toList();
  }

  static Future<RoomSchedule?> fetchById(String id) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return RoomSchedule.fromMap(data);
  }

  static Future<void> insert(RoomSchedule schedule) async {
    await _db.from(_table).insert(schedule.toMap());
  }

  static Future<void> update(RoomSchedule schedule) async {
    await _db.from(_table).update(schedule.toMap()).eq('id', schedule.id);
  }

  static Future<void> updateStatus(String id, String status) async {
    await _db.from(_table).update({'status': status}).eq('id', id);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}
