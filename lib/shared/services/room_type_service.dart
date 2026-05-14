import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/room_type_model.dart';
import 'admin_audit_log_service.dart';

class RoomTypeService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'room_types';

  static Future<List<RoomType>> fetchAll() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => RoomType.fromMap(e)).toList();
  }

  static Future<List<RoomType>> fetchAllIncludingInactive() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => RoomType.fromMap(e)).toList();
  }

  static Future<RoomType?> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return RoomType.fromMap(data);
  }

  static Future<RoomType?> fetchByName(String name) async {
    final data = await _db.from(_table).select().eq('name', name).maybeSingle();
    if (data == null) return null;
    return RoomType.fromMap(data);
  }

  static Future<void> insert(RoomType roomType) async {
    await _db.from(_table).insert(roomType.toMap());
    await AdminAuditLogService.logAction(
      title: 'Added Room Type',
      details: 'Room Type: ${roomType.name} (${roomType.id})',
    );
  }

  static Future<void> update(RoomType roomType) async {
    await _db.from(_table).update(roomType.toMap()).eq('id', roomType.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Room Type',
      details: 'Room Type: ${roomType.name} (${roomType.id})',
    );
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Deleted Room Type',
      details: 'Room Type ID: $id',
    );
  }

  static Future<RoomType> findOrCreateByName(String name) async {
    final existing = await fetchByName(name);
    if (existing != null) return existing;

    final now = DateTime.now();
    final newType = RoomType(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );

    final inserted = await _db
        .from(_table)
        .insert(newType.toMap())
        .select()
        .single();
    await AdminAuditLogService.logAction(
      title: 'Created Room Type Automatically',
      details: 'Room Type: $name',
    );
    return RoomType.fromMap(inserted);
  }
}
