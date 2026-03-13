import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building_model.dart';

class BuildingService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'buildings';

  static Future<List<Building>> fetchAll() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => Building.fromMap(e)).toList();
  }

  static Future<List<Building>> fetchByCampus(String campus) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('campus', campus)
        .order('name', ascending: true);
    return (data as List).map((e) => Building.fromMap(e)).toList();
  }

  static Future<Building?> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Building.fromMap(data);
  }

  static Future<Building?> fetchByCode(String code) async {
    final data = await _db.from(_table).select().eq('code', code).maybeSingle();
    if (data == null) return null;
    return Building.fromMap(data);
  }

  static Future<void> insert(Building building) async {
    await _db.from(_table).insert(building.toMap());
  }

  static Future<void> update(Building building) async {
    await _db.from(_table).update(building.toMap()).eq('id', building.id);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  /// Find a building by name, or create it if it doesn't exist.
  static Future<Building> findOrCreateByName(String name) async {
    final data = await _db
        .from(_table)
        .select()
        .ilike('name', name)
        .maybeSingle();
    if (data != null) return Building.fromMap(data);

    final now = DateTime.now();
    final code = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    final newBuilding = {
      'name': name,
      'code': '${code.substring(0, code.length > 10 ? 10 : code.length)}_${now.millisecondsSinceEpoch % 10000}',
      'campus': 'Main',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final inserted = await _db.from(_table).insert(newBuilding).select().single();
    return Building.fromMap(inserted);
  }
}
