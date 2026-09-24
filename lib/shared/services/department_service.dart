import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/building_model.dart';
import '../models/department_model.dart';
import 'admin_audit_log_service.dart';

class DepartmentService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'departments';
  static const String _junctionTable = 'department_buildings';

  // ─── Fetch ──────────────────────────────────────────────────────────────

  static Future<List<Department>> fetchAll() async {
    List<Department> list = [];
    try {
      final data = await _db
          .from(_table)
          .select('*, head_user:users!departments_head_user_id_fkey(name), department_buildings(building_id, buildings(name))')
          .order('name', ascending: true);
      list = (data as List).map((e) => Department.fromMap(e)).toList();
    } catch (_) {
      try {
        final data = await _db
            .from(_table)
            .select('*, head_user:users!departments_head_user_id_fkey(name)')
            .order('name', ascending: true);
        list = (data as List).map((e) => Department.fromMap(e)).toList();
      } catch (_) {
        final data =
            await _db.from(_table).select().order('name', ascending: true);
        list = (data as List).map((e) => Department.fromMap(e)).toList();
      }
    }

    // Enrich missing head user names if any headUserId lacks headUserName
    final missingHeadIds = list
        .where((d) => d.headUserId != null && d.headUserId!.isNotEmpty && (d.headUserName == null || d.headUserName!.isEmpty))
        .map((d) => d.headUserId!)
        .toSet()
        .toList();

    if (missingHeadIds.isNotEmpty) {
      try {
        final usersData = await _db
            .from('users')
            .select('id, name')
            .inFilter('id', missingHeadIds);
        final userMap = {for (var u in usersData) u['id'].toString(): u['name']?.toString()};
        list = list.map((d) {
          if (d.headUserId != null && userMap.containsKey(d.headUserId)) {
            return d.copyWith(headUserName: userMap[d.headUserId]);
          }
          return d;
        }).toList();
      } catch (_) {}
    }

    // Enrich building associations from junction table if list has empty buildingIds
    try {
      final allJunctionData = await _db
          .from(_junctionTable)
          .select('department_id, building_id, buildings(name)');
      
      final Map<String, List<String>> deptBldgIds = {};
      final Map<String, List<String>> deptBldgNames = {};

      for (final row in (allJunctionData as List)) {
        if (row is Map) {
          final dId = row['department_id']?.toString() ?? '';
          final bId = row['building_id']?.toString() ?? '';
          String bName = '';
          if (row['buildings'] is Map && row['buildings']['name'] != null) {
            bName = row['buildings']['name'].toString();
          }

          if (dId.isNotEmpty && bId.isNotEmpty) {
            deptBldgIds.putIfAbsent(dId, () => []);
            if (!deptBldgIds[dId]!.contains(bId)) {
              deptBldgIds[dId]!.add(bId);
            }

            if (bName.isNotEmpty) {
              deptBldgNames.putIfAbsent(dId, () => []);
              if (!deptBldgNames[dId]!.contains(bName)) {
                deptBldgNames[dId]!.add(bName);
              }
            }
          }
        }
      }

      list = list.map((d) {
        final jIds = deptBldgIds[d.id] ?? [];
        final jNames = deptBldgNames[d.id] ?? [];
        if (jIds.isNotEmpty) {
          return d.copyWith(
            buildingIds: jIds,
            buildingNames: jNames.isNotEmpty ? jNames : d.buildingNames,
          );
        }
        return d;
      }).toList();
    } catch (_) {}

    return list;
  }

  /// Fetch departments associated with a specific building through department_buildings
  static Future<List<Department>> fetchByBuilding(String buildingId) async {
    if (buildingId.trim().isEmpty) return [];

    try {
      // 1. Query junction table
      final junctionData = await _db
          .from(_junctionTable)
          .select('department_id')
          .eq('building_id', buildingId.trim());

      final deptIds = (junctionData as List)
          .map((e) => e['department_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (deptIds.isNotEmpty) {
        final allDepts = await fetchAll();
        return allDepts.where((d) => deptIds.contains(d.id)).toList();
      }
    } catch (e) {
      debugPrint('[DepartmentService] fetchByBuilding junction query failed: $e');
    }

    // 2. Resilient fallback: Check rooms belonging to this building
    try {
      final roomData = await _db
          .from('rooms')
          .select('department_id')
          .eq('building_id', buildingId.trim());
      
      final roomDeptIds = (roomData as List)
          .map((e) => e['department_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (roomDeptIds.isNotEmpty) {
        final allDepts = await fetchAll();
        return allDepts.where((d) => roomDeptIds.contains(d.id)).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Fetch buildings associated with a specific department
  static Future<List<Building>> fetchBuildingsByDepartment(String departmentId) async {
    if (departmentId.trim().isEmpty) return [];

    try {
      final junctionData = await _db
          .from(_junctionTable)
          .select('building_id, buildings(*)')
          .eq('department_id', departmentId.trim());

      final List<Building> buildings = [];
      for (final item in (junctionData as List)) {
        if (item is Map && item['buildings'] is Map) {
          buildings.add(Building.fromMap(Map<String, dynamic>.from(item['buildings'] as Map)));
        } else if (item['building_id'] != null) {
          final bId = item['building_id'].toString();
          final bData = await _db.from('buildings').select().eq('id', bId).maybeSingle();
          if (bData != null) {
            buildings.add(Building.fromMap(bData));
          }
        }
      }
      return buildings;
    } catch (e) {
      debugPrint('[DepartmentService] fetchBuildingsByDepartment failed: $e');
      return [];
    }
  }

  static Future<List<Department>> fetchByCampus(String campus) async {
    return fetchAll();
  }

  static Future<Department?> fetchById(String id) async {
    final all = await fetchAll();
    for (final d in all) {
      if (d.id == id) return d;
    }

    try {
      final data = await _db.from(_table).select().eq('id', id).maybeSingle();
      if (data != null) return Department.fromMap(data);
    } catch (_) {}

    return null;
  }

  /// Fetch active Department Head user ID for a given department
  static Future<String?> fetchDepartmentHeadUserId(String departmentId) async {
    try {
      final dept = await fetchById(departmentId);
      if (dept?.headUserId != null && dept!.headUserId!.isNotEmpty) {
        // Validate user is active
        final user = await _db
            .from('users')
            .select('id, is_active')
            .eq('id', dept.headUserId!)
            .maybeSingle();
        if (user != null && user['is_active'] == true) {
          return dept.headUserId;
        }
      }
    } catch (e) {
      debugPrint('Error fetching department head: $e');
    }
    return null;
  }

  /// Assign official Department Head
  static Future<void> setDepartmentHead(String departmentId, String? headUserId) async {
    // 1. If headUserId is provided, clear any other department they might previously head
    if (headUserId != null && headUserId.isNotEmpty) {
      await clearHeadIfAssigned(headUserId, exceptDepartmentId: departmentId);
    }

    // 2. Set this department's head_user_id
    await _db.from(_table).update({
      'head_user_id': headUserId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', departmentId);

    // 3. Synchronize selected user's position to 'Head' in teacher_users
    if (headUserId != null && headUserId.isNotEmpty) {
      try {
        await _db.from('teacher_users').update({
          'position': 'Head',
          'department_id': departmentId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', headUserId);
      } catch (_) {}
    }
  }

  /// Clear head_user_id from departments where this user is currently designated as Head
  static Future<void> clearHeadIfAssigned(String userId, {String? exceptDepartmentId}) async {
    try {
      var query = _db.from(_table).update({
        'head_user_id': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('head_user_id', userId);

      if (exceptDepartmentId != null && exceptDepartmentId.isNotEmpty) {
        query = query.neq('id', exceptDepartmentId);
      }
      await query;
    } catch (e) {
      debugPrint('Error clearing department head: $e');
    }
  }

  // ─── Create ──────────────────────────────────────────────────────────────

  static Future<String?> create({
    required String name,
    String? description,
    List<String>? buildingIds,
  }) async {
    try {
      // Duplicate check
      final existing = await _db
          .from(_table)
          .select('id')
          .ilike('name', name.trim())
          .maybeSingle();
      if (existing != null) return 'A department named "$name" already exists.';

      final now = DateTime.now().toIso8601String();
      final inserted = await _db.from(_table).insert({
        'name': name.trim(),
        'created_at': now,
        'updated_at': now,
      }).select('id').single();

      final deptId = inserted['id']?.toString() ?? '';

      // Sync junction table
      if (deptId.isNotEmpty && buildingIds != null && buildingIds.isNotEmpty) {
        await syncDepartmentBuildings(deptId, buildingIds);
      }

      await AdminAuditLogService.logAction(
        title: 'Created Department',
        details: 'Department: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Insert department entity with building association
  static Future<void> insert(Department department, {List<String>? buildingIds}) async {
    final map = department.toMap();
    await _db.from(_table).insert(map);

    final bIds = buildingIds ?? department.buildingIds;
    if (bIds.isNotEmpty) {
      await syncDepartmentBuildings(department.id, bIds);
    }

    await AdminAuditLogService.logAction(
      title: 'Added Department',
      details: 'Department: ${department.name} (${department.id})',
    );
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  static Future<String?> updateDepartment({
    required String id,
    required String name,
    String? description,
    List<String>? buildingIds,
    required bool isActive,
    required List<Department> allDepartments,
  }) async {
    try {
      // Duplicate check — ignore self
      final duplicate = allDepartments.any(
        (d) =>
            d.id != id &&
            d.name.trim().toLowerCase() == name.trim().toLowerCase(),
      );
      if (duplicate) {
        return 'A department named "$name" already exists.';
      }

      final payload = <String, dynamic>{
        'name': name.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _db.from(_table).update(payload).eq('id', id);

      // Sync junction table if buildingIds provided
      if (buildingIds != null) {
        await syncDepartmentBuildings(id, buildingIds);
      }

      await AdminAuditLogService.logAction(
        title: 'Updated Department',
        details: 'Department: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Synchronize M2M relationships in department_buildings
  static Future<void> syncDepartmentBuildings(String departmentId, List<String> buildingIds) async {
    if (departmentId.trim().isEmpty) return;
    final cleanBldgIds = buildingIds
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList();

    try {
      // 1. Fetch current relationships
      final currentRows = await _db
          .from(_junctionTable)
          .select('building_id')
          .eq('department_id', departmentId);

      final currentBldgIds = (currentRows as List)
          .map((r) => r['building_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // 2. Identify removals
      final toRemove = currentBldgIds.where((id) => !cleanBldgIds.contains(id)).toList();
      if (toRemove.isNotEmpty) {
        await _db
            .from(_junctionTable)
            .delete()
            .eq('department_id', departmentId)
            .inFilter('building_id', toRemove);
      }

      // 3. Identify additions
      final toAdd = cleanBldgIds.where((id) => !currentBldgIds.contains(id)).toList();
      if (toAdd.isNotEmpty) {
        final inserts = toAdd.map((bId) => {
          'department_id': departmentId,
          'building_id': bId,
        }).toList();
        await _db.from(_junctionTable).insert(inserts);
      }
    } catch (e) {
      debugPrint('[DepartmentService] syncDepartmentBuildings error: $e');
    }
  }

  // Legacy update
  static Future<void> update(Department department) async {
    final map = department.toMap();
    await _db.from(_table).update(map).eq('id', department.id);
    if (department.buildingIds.isNotEmpty) {
      await syncDepartmentBuildings(department.id, department.buildingIds);
    }
    await AdminAuditLogService.logAction(
      title: 'Updated Department',
      details: 'Department: ${department.name} (${department.id})',
    );
  }

  // ─── Toggle active ────────────────────────────────────────────────────────

  static Future<String?> setActive(String id, {required bool active}) async {
    try {
      await AdminAuditLogService.logAction(
        title: active ? 'Restored Department' : 'Disabled Department',
        details: 'Department ID: $id',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Delete ──────────────────────────────────────────────────────────────

  static Future<String?> deleteDepartment(String id, String name) async {
    try {
      // department_buildings records are automatically cascade deleted by DB FK
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted Department',
        details: 'Department: $name (ID: $id)',
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
      title: 'Deleted Department',
      details: 'Department ID: $id',
    );
  }

  // ─── Find or create ───────────────────────────────────────────────────────

  static Future<Department> findOrCreateByName(String name) async {
    final data = await _db
        .from(_table)
        .select()
        .ilike('name', name)
        .maybeSingle();
    if (data != null) return Department.fromMap(data);

    final now = DateTime.now();
    final newDept = {
      'name': name,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final inserted =
        await _db.from(_table).insert(newDept).select().single();
    await AdminAuditLogService.logAction(
      title: 'Created Department Automatically',
      details: 'Department: $name',
    );
    return Department.fromMap(inserted);
  }
}
