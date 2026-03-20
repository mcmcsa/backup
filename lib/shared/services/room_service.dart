import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';

class RoomService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'rooms';

  static const String _selectWithJoins = '*, buildings(name), departments(name)';

  static Future<List<Room>> fetchAll() async {
    final data = await _db.from(_table).select(_selectWithJoins).order('name', ascending: true);
    return (data as List).map((e) => Room.fromMap(e)).toList();
  }

  static Future<List<Room>> fetchByBuilding(String buildingId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('building_id', buildingId)
        .order('name', ascending: true);
    return (data as List).map((e) => Room.fromMap(e)).toList();
  }

  static Future<List<Room>> fetchByDepartment(String departmentId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('department_id', departmentId)
        .order('name', ascending: true);
    return (data as List).map((e) => Room.fromMap(e)).toList();
  }

  static Future<List<Room>> fetchByStatus(String status) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('status', status)
        .order('name', ascending: true);
    return (data as List).map((e) => Room.fromMap(e)).toList();
  }

  static Future<List<Room>> fetchByRoomType(String roomType) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('room_type', roomType)
        .order('name', ascending: true);
    return (data as List).map((e) => Room.fromMap(e)).toList();
  }

  static Future<List<Room>> fetchAvailable() async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('status', 'available')
        .order('name', ascending: true);
    return (data as List).map((e) => Room.fromMap(e)).toList();
  }

  static Future<Room?> fetchById(String id) async {
    final data = await _db.from(_table).select(_selectWithJoins).eq('id', id).maybeSingle();
    if (data == null) return null;
    return Room.fromMap(data);
  }

  static Future<Room?> fetchByQRCode(String qrCodeData) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('qr_code_data', qrCodeData)
        .maybeSingle();
    if (data == null) return null;
    return Room.fromMap(data);
  }

  static Future<void> updateStatus(String id, String status) async {
    await _db.from(_table).update({'status': status}).eq('id', id);
  }

  static Future<void> insert(Room room) async {
    await _db.from(_table).insert(room.toMap());
  }

  static Future<void> update(Room room) async {
    await _db.from(_table).update(room.toMap()).eq('id', room.id);
  }

  static Future<Room?> fetchByName(String name) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .ilike('name', name)
        .maybeSingle();
    if (data == null) return null;
    return Room.fromMap(data);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  /// Returns the next auto-incremented room ID in the format RM0001, RM0002, …
  static Future<String> generateNextId() async {
    final data = await _db.from(_table).select('id');
    int maxNum = 0;
    final regex = RegExp(r'^RM(\d+)$', caseSensitive: false);
    for (final row in (data as List)) {
      final match = regex.firstMatch(row['id']?.toString() ?? '');
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'RM${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  // Analytics methods
  static Future<int> getTotalRooms() async {
    final data = await _db.from(_table).select('id');
    return (data as List).length;
  }

  static Future<int> getAvailableCount() async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('status', 'available');
    return (data as List).length;
  }

  static Future<int> getMaintenanceCount() async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('status', 'maintenance');
    return (data as List).length;
  }
}
