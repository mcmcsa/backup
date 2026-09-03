import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building_model.dart';
import 'admin_audit_log_service.dart';

class BuildingService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'buildings';
  static const String _selectWithJoins = '*, departments(name)';

  // ─── Fetch ──────────────────────────────────────────────────────────────

  static Future<List<Building>> fetchAll() async {
    final data = await _db.from(_table).select(_selectWithJoins).order('name', ascending: true);
    return (data as List).map((e) => Building.fromMap(e)).toList();
  }

  static Future<List<Building>> fetchByCampus(String campus) async {
    return fetchAll();
  }

  static Future<Building?> fetchById(String id) async {
    final data = await _db.from(_table).select(_selectWithJoins).eq('id', id).maybeSingle();
    if (data == null) return null;
    return Building.fromMap(data);
  }

  static Future<Building?> fetchByCode(String code) async {
    final data = await _db.from(_table).select(_selectWithJoins).eq('code', code).maybeSingle();
    if (data == null) return null;
    return Building.fromMap(data);
  }

  static Future<List<Building>> fetchByDepartment(String departmentId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('department_id', departmentId)
        .order('name', ascending: true);
    return (data as List).map((e) => Building.fromMap(e)).toList();
  }

  static Future<Building?> fetchByNameAndDepartment(String name, String departmentId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .ilike('name', name)
        .eq('department_id', departmentId)
        .maybeSingle();
    if (data == null) return null;
    return Building.fromMap(data);
  }

  // ─── Create ──────────────────────────────────────────────────────────────

  static Future<String?> create({
    required String name,
    required String code,
    required String departmentId,
    required int numberOfFloors,
  }) async {
    try {
      // Duplicate check for name or code
      final existingName = await _db
          .from(_table)
          .select('id')
          .ilike('name', name.trim())
          .maybeSingle();
      if (existingName != null) return 'A building named "$name" already exists.';

      final existingCode = await _db
          .from(_table)
          .select('id')
          .ilike('code', code.trim())
          .maybeSingle();
      if (existingCode != null) return 'A building with code "$code" already exists.';

      final now = DateTime.now().toIso8601String();
      await _db.from(_table).insert({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        if (departmentId.isNotEmpty) 'department_id': departmentId,
        'created_at': now,
        'updated_at': now,
      });

      await AdminAuditLogService.logAction(
        title: 'Created Building',
        details: 'Building: $name ($code)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy
  static Future<void> insert(Building building) async {
    await _db.from(_table).insert(building.toMap());
    await AdminAuditLogService.logAction(
      title: 'Added Building',
      details: 'Building: ${building.name} (${building.id})',
    );
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  static Future<String?> updateBuilding({
    required String id,
    required String name,
    required String code,
    required String departmentId,
    required int numberOfFloors,
    required bool isActive,
    required List<Building> allBuildings,
  }) async {
    try {
      // Duplicate checks — ignore self
      final duplicateName = allBuildings.any(
        (b) =>
            b.id != id &&
            b.name.trim().toLowerCase() == name.trim().toLowerCase(),
      );
      if (duplicateName) return 'A building named "$name" already exists.';

      final duplicateCode = allBuildings.any(
        (b) =>
            b.id != id &&
            b.code.trim().toLowerCase() == code.trim().toLowerCase(),
      );
      if (duplicateCode) return 'A building with code "$code" already exists.';

      await _db.from(_table).update({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'department_id': departmentId.isNotEmpty ? departmentId : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Updated Building',
        details: 'Building: $name ($code)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy update
  static Future<void> update(Building building) async {
    await _db.from(_table).update(building.toMap()).eq('id', building.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Building',
      details: 'Building: ${building.name} (${building.id})',
    );
  }

  // ─── Toggle active ────────────────────────────────────────────────────────

  static Future<String?> setActive(String id, {required bool active}) async {
    try {
      await AdminAuditLogService.logAction(
        title: active ? 'Restored Building' : 'Disabled Building',
        details: 'Building ID: $id',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Delete ──────────────────────────────────────────────────────────────

  static Future<String?> deleteBuilding(String id, String name) async {
    try {
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted Building',
        details: 'Building: $name (ID: $id)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy delete
  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Deleted Building',
      details: 'Building ID: $id',
    );
  }

  // ─── Find or create ───────────────────────────────────────────────────────

  static Future<Building> findOrCreateByName(String name) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .ilike('name', name)
        .maybeSingle();
    if (data != null) return Building.fromMap(data);

    final now = DateTime.now();
    final code = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    final newBuilding = {
      'name': name,
      'code': '${code.substring(0, code.length > 10 ? 10 : code.length)}_${now.millisecondsSinceEpoch % 10000}',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final inserted = await _db.from(_table).insert(newBuilding).select().single();
    await AdminAuditLogService.logAction(
      title: 'Created Building Automatically',
      details: 'Building: $name',
    );
    return Building.fromMap(inserted);
  }
}
