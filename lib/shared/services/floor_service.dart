import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/floor_model.dart';
import 'admin_audit_log_service.dart';

class FloorService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'floors';

  static Future<List<Floor>> fetchAll() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => Floor.fromMap(e)).toList();
  }

  static Future<Floor?> fetchByName(String name) async {
    final data = await _db.from(_table).select().eq('name', name).maybeSingle();
    if (data == null) return null;
    return Floor.fromMap(data);
  }

  static Future<void> insert(Floor floor) async {
    await _db.from(_table).insert(floor.toMap());
    await AdminAuditLogService.logAction(
      title: 'Added Floor',
      details: 'Floor: ${floor.name} (${floor.id})',
    );
  }

  static Future<void> update(Floor floor) async {
    await _db.from(_table).update(floor.toMap()).eq('id', floor.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Floor',
      details: 'Floor: ${floor.name} (${floor.id})',
    );
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Deleted Floor',
      details: 'Floor ID: $id',
    );
  }

  static Future<Floor> findOrCreateByName(String name) async {
    final existing = await fetchByName(name);
    if (existing != null) return existing;

    final now = DateTime.now();

    final floor = Floor(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );

    await insert(floor);
    return floor;
  }
}
