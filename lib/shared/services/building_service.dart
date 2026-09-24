import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building_model.dart';
import '../models/department_model.dart';
import 'admin_audit_log_service.dart';
import 'department_service.dart';

class BuildingService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'buildings';
  static const String _junctionTable = 'department_buildings';

  // ─── Fetch Helper ────────────────────────────────────────────────────────

  static Future<List<dynamic>> _safeSelect({
    String? filterColumn,
    dynamic filterValue,
    String? ilikeColumn,
    String? ilikeValue,
    bool ascending = true,
  }) async {
    try {
      var query = _db.from(_table).select();
      if (filterColumn != null && filterValue != null) {
        query = query.eq(filterColumn, filterValue);
      }
      if (ilikeColumn != null && ilikeValue != null) {
        query = query.ilike(ilikeColumn, ilikeValue);
      }
      final res = await query.order('name', ascending: ascending);
      return res as List<dynamic>;
    } catch (e) {
      debugPrint('[BuildingService] Select failed: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _safeSelectSingle({
    required String column,
    required dynamic value,
    bool isIlike = false,
  }) async {
    try {
      var query = _db.from(_table).select();
      final dynamic res = isIlike
          ? await query.ilike(column, value.toString()).maybeSingle()
          : await query.eq(column, value).maybeSingle();
      if (res != null) return Map<String, dynamic>.from(res as Map);
    } catch (_) {}

    return null;
  }

  // ─── Fetch ──────────────────────────────────────────────────────────────

  static Future<List<Building>> fetchAll() async {
    final data = await _safeSelect();
    List<Building> buildings =
        data.map((e) => Building.fromMap(e as Map<String, dynamic>)).toList();

    // Enrich with associated departments from department_buildings junction table
    try {
      final junctionData = await _db
          .from(_junctionTable)
          .select('building_id, department_id, departments(name)');

      final Map<String, List<String>> bldgDeptIds = {};
      final Map<String, List<String>> bldgDeptNames = {};

      for (final row in (junctionData as List)) {
        if (row is Map) {
          final bId = row['building_id']?.toString() ?? '';
          final dId = row['department_id']?.toString() ?? '';
          String dName = '';
          if (row['departments'] is Map && row['departments']['name'] != null) {
            dName = row['departments']['name'].toString();
          }

          if (bId.isNotEmpty && dId.isNotEmpty) {
            bldgDeptIds.putIfAbsent(bId, () => []);
            if (!bldgDeptIds[bId]!.contains(dId)) {
              bldgDeptIds[bId]!.add(dId);
            }

            if (dName.isNotEmpty) {
              bldgDeptNames.putIfAbsent(bId, () => []);
              if (!bldgDeptNames[bId]!.contains(dName)) {
                bldgDeptNames[bId]!.add(dName);
              }
            }
          }
        }
      }

      buildings = buildings.map((b) {
        final dIds = bldgDeptIds[b.id] ?? [];
        final dNames = bldgDeptNames[b.id] ?? [];
        if (dIds.isNotEmpty) {
          return b.copyWith(
            departmentIds: dIds,
            departmentNames: dNames.isNotEmpty ? dNames : b.departmentNames,
          );
        }
        return b;
      }).toList();
    } catch (e) {
      debugPrint('[BuildingService] Junction enrichment error: $e');
    }

    return buildings;
  }

  static Future<List<Building>> fetchByCampus(String campus) async {
    return fetchAll();
  }

  static Future<Building?> fetchById(String id) async {
    final all = await fetchAll();
    for (final b in all) {
      if (b.id == id) return b;
    }
    final data = await _safeSelectSingle(column: 'id', value: id);
    if (data == null) return null;
    return Building.fromMap(data);
  }

  static Future<Building?> fetchByCode(String code) async {
    final data = await _safeSelectSingle(column: 'code', value: code);
    if (data == null) return null;
    return Building.fromMap(data);
  }

  /// Fetch buildings associated with a specific department through department_buildings
  static Future<List<Building>> fetchByDepartment(String departmentId) async {
    if (departmentId.trim().isEmpty) return [];

    try {
      final junctionData = await _db
          .from(_junctionTable)
          .select('building_id')
          .eq('department_id', departmentId.trim());

      final bldgIds = (junctionData as List)
          .map((e) => e['building_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (bldgIds.isNotEmpty) {
        final allBuildings = await fetchAll();
        return allBuildings.where((b) => bldgIds.contains(b.id)).toList();
      }
    } catch (e) {
      debugPrint('[BuildingService] fetchByDepartment junction query failed: $e');
    }

    // Fallback: check rooms
    try {
      final roomData = await _db
          .from('rooms')
          .select('building_id')
          .eq('department_id', departmentId.trim());

      final roomBldgIds = (roomData as List)
          .map((e) => e['building_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (roomBldgIds.isNotEmpty) {
        final allBuildings = await fetchAll();
        return allBuildings.where((b) => roomBldgIds.contains(b.id)).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Fetch departments associated with a specific building
  static Future<List<Department>> fetchDepartmentsByBuilding(String buildingId) async {
    return DepartmentService.fetchByBuilding(buildingId);
  }

  static Future<Building?> fetchByName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;
    final all = await fetchAll();
    for (final b in all) {
      if (b.name.trim().toLowerCase() == cleanName.toLowerCase()) return b;
    }
    final data = await _safeSelectSingle(column: 'name', value: cleanName, isIlike: true);
    if (data == null) return null;
    return Building.fromMap(data);
  }

  static Future<Building?> fetchByNameAndDepartment(String name, String departmentId) async {
    return fetchByName(name);
  }

  // ─── Create ──────────────────────────────────────────────────────────────

  static Future<String?> create({
    required String name,
    String code = '',
    List<String>? departmentIds,
    int numberOfFloors = 1,
  }) async {
    try {
      // Duplicate check for name
      final existingName = await _db
          .from(_table)
          .select('id')
          .ilike('name', name.trim())
          .maybeSingle();
      if (existingName != null) return 'A building named "$name" already exists.';

      final now = DateTime.now().toIso8601String();
      final inserted = await _db.from(_table).insert({
        'name': name.trim(),
        'created_at': now,
        'updated_at': now,
      }).select('id').single();

      final bldgId = inserted['id']?.toString() ?? '';
      if (bldgId.isNotEmpty && departmentIds != null && departmentIds.isNotEmpty) {
        await updateBuildingDepartments(bldgId, departmentIds);
      }

      await AdminAuditLogService.logAction(
        title: 'Created Building',
        details: 'Building: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy insert
  static Future<void> insert(Building building, {List<String>? departmentIds}) async {
    await _db.from(_table).insert(building.toMap());
    final dIds = departmentIds ?? building.departmentIds;
    if (dIds.isNotEmpty) {
      await updateBuildingDepartments(building.id, dIds);
    }
    await AdminAuditLogService.logAction(
      title: 'Added Building',
      details: 'Building: ${building.name} (${building.id})',
    );
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  static Future<String?> updateBuilding({
    required String id,
    required String name,
    String code = '',
    List<String>? departmentIds,
    String departmentId = '',
    int numberOfFloors = 1,
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

      await _db.from(_table).update({
        'name': name.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (departmentIds != null) {
        await updateBuildingDepartments(id, departmentIds);
      }

      await AdminAuditLogService.logAction(
        title: 'Updated Building',
        details: 'Building: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Synchronize M2M relationships in department_buildings for a building
  static Future<void> updateBuildingDepartments(String buildingId, List<String> departmentIds) async {
    if (buildingId.trim().isEmpty) return;
    final cleanDeptIds = departmentIds
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    try {
      final currentRows = await _db
          .from(_junctionTable)
          .select('department_id')
          .eq('building_id', buildingId);

      final currentDeptIds = (currentRows as List)
          .map((r) => r['department_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final toRemove = currentDeptIds.where((id) => !cleanDeptIds.contains(id)).toList();
      if (toRemove.isNotEmpty) {
        await _db
            .from(_junctionTable)
            .delete()
            .eq('building_id', buildingId)
            .inFilter('department_id', toRemove);
      }

      final toAdd = cleanDeptIds.where((id) => !currentDeptIds.contains(id)).toList();
      if (toAdd.isNotEmpty) {
        final inserts = toAdd.map((dId) => {
          'department_id': dId,
          'building_id': buildingId,
        }).toList();
        await _db.from(_junctionTable).insert(inserts);
      }
    } catch (e) {
      debugPrint('[BuildingService] updateBuildingDepartments error: $e');
    }
  }

  // Legacy update
  static Future<void> update(Building building) async {
    await _db.from(_table).update(building.toMap()).eq('id', building.id);
    if (building.departmentIds.isNotEmpty) {
      await updateBuildingDepartments(building.id, building.departmentIds);
    }
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
      // Junction records cascade delete automatically
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
    final existing = await fetchByName(name);
    if (existing != null) return existing;

    final now = DateTime.now();
    final newBuilding = {
      'name': name,
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
