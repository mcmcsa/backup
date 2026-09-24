import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/department_model.dart';
import 'admin_audit_log_service.dart';

class DepartmentService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'departments';

  // ─── Fetch ──────────────────────────────────────────────────────────────

  static Future<List<Department>> fetchAll() async {
    List<Department> list = [];
    try {
      final data = await _db
          .from(_table)
          .select('*, head_user:users!departments_head_user_id_fkey(name), buildings:buildings!departments_building_id_fkey(name)')
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
            .filter('id', 'in', missingHeadIds);
        final userMap = {for (var u in usersData) u['id'].toString(): u['name']?.toString()};
        list = list.map((d) {
          if (d.headUserId != null && userMap.containsKey(d.headUserId)) {
            return d.copyWith(headUserName: userMap[d.headUserId]);
          }
          return d;
        }).toList();
      } catch (_) {}
    }

    // Enrich missing building names if any buildingId lacks buildingName
    final missingBuildingIds = list
        .where((d) => d.buildingId != null && d.buildingId!.isNotEmpty && (d.buildingName == null || d.buildingName!.isEmpty))
        .map((d) => d.buildingId!)
        .toSet()
        .toList();

    if (missingBuildingIds.isNotEmpty) {
      try {
        final bldgsData = await _db
            .from('buildings')
            .select('id, name')
            .filter('id', 'in', missingBuildingIds);
        final bldgMap = {for (var b in bldgsData) b['id'].toString(): b['name']?.toString()};
        list = list.map((d) {
          if (d.buildingId != null && bldgMap.containsKey(d.buildingId)) {
            return d.copyWith(buildingName: bldgMap[d.buildingId]);
          }
          return d;
        }).toList();
      } catch (_) {}
    }

    return list;
  }

  static Future<List<Department>> fetchByBuilding(String buildingId) async {
    try {
      final data = await _db
          .from(_table)
          .select('*, head_user:users!departments_head_user_id_fkey(name), buildings:buildings!departments_building_id_fkey(name)')
          .eq('building_id', buildingId)
          .order('name', ascending: true);
      return (data as List).map((e) => Department.fromMap(e)).toList();
    } catch (_) {
      try {
        final data = await _db
            .from(_table)
            .select()
            .eq('building_id', buildingId)
            .order('name', ascending: true);
        return (data as List).map((e) => Department.fromMap(e)).toList();
      } catch (_) {
        // Fallback: check if building legacy points to a department
        try {
          final bldg = await _db.from('buildings').select('department_id').eq('id', buildingId).maybeSingle();
          if (bldg != null && bldg['department_id'] != null) {
            final dept = await fetchById(bldg['department_id'].toString());
            if (dept != null) return [dept];
          }
        } catch (_) {}
        return [];
      }
    }
  }

  static Future<List<Department>> fetchByCampus(String campus) async {
    return fetchAll();
  }

  static Future<Department?> fetchById(String id) async {
    Department? dept;
    try {
      final data = await _db
          .from(_table)
          .select('*, head_user:users!departments_head_user_id_fkey(name)')
          .eq('id', id)
          .maybeSingle();
      if (data != null) dept = Department.fromMap(data);
    } catch (_) {
      final data =
          await _db.from(_table).select().eq('id', id).maybeSingle();
      if (data != null) dept = Department.fromMap(data);
    }

    if (dept != null && dept.headUserId != null && (dept.headUserName == null || dept.headUserName!.isEmpty)) {
      try {
        final u = await _db.from('users').select('name').eq('id', dept.headUserId!).maybeSingle();
        if (u != null && u['name'] != null) {
          return Department(
            id: dept.id,
            name: dept.name,
            description: dept.description,
            isActive: dept.isActive,
            headUserId: dept.headUserId,
            headUserName: u['name'].toString(),
            createdAt: dept.createdAt,
            updatedAt: dept.updatedAt,
          );
        }
      } catch (_) {}
    }

    return dept;
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

    // 3. Synchronize selected user's position to 'Head' in teacher_users (Rule 4)
    // NOTE: Per user requirement, previous head's position is NEVER automatically modified.
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
      await _db.from(_table).insert({
        'name': name.trim(),
        'created_at': now,
        'updated_at': now,
      });

      await AdminAuditLogService.logAction(
        title: 'Created Department',
        details: 'Department: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Legacy insert (kept for call-site compatibility) ────────────────────

  static Future<void> insert(Department department) async {
    final map = department.toMap();
    try {
      await _db.from(_table).insert(map);
    } catch (e) {
      if (map.containsKey('building_id')) {
        final fallbackMap = Map<String, dynamic>.from(map)..remove('building_id');
        await _db.from(_table).insert(fallbackMap);
      } else {
        rethrow;
      }
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
    String? buildingId,
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
        if (buildingId != null && buildingId.isNotEmpty) 'building_id': buildingId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _db.from(_table).update(payload).eq('id', id);
      } catch (e) {
        if (payload.containsKey('building_id')) {
          payload.remove('building_id');
          await _db.from(_table).update(payload).eq('id', id);
        } else {
          rethrow;
        }
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

  // Legacy update
  static Future<void> update(Department department) async {
    final map = department.toMap();
    try {
      await _db.from(_table).update(map).eq('id', department.id);
    } catch (e) {
      if (map.containsKey('building_id')) {
        final fallbackMap = Map<String, dynamic>.from(map)..remove('building_id');
        await _db.from(_table).update(fallbackMap).eq('id', department.id);
      } else {
        rethrow;
      }
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
