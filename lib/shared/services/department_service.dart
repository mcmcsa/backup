import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/department_model.dart';
import 'admin_audit_log_service.dart';

class DepartmentService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'departments';

  // ─── Fetch ──────────────────────────────────────────────────────────────

  static Future<List<Department>> fetchAll() async {
    final data =
        await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => Department.fromMap(e)).toList();
  }

  static Future<List<Department>> fetchByCampus(String campus) async {
    return fetchAll();
  }

  static Future<Department?> fetchById(String id) async {
    final data =
        await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Department.fromMap(data);
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
        'description': description?.trim().isNotEmpty == true
            ? description!.trim()
            : null,
        'is_active': true,
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
    await _db.from(_table).insert(department.toMap());
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

      await _db.from(_table).update({
        'name': name.trim(),
        'description': description?.trim().isNotEmpty == true
            ? description!.trim()
            : null,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

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
    await _db.from(_table).update(department.toMap()).eq('id', department.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Department',
      details: 'Department: ${department.name} (${department.id})',
    );
  }

  // ─── Toggle active ────────────────────────────────────────────────────────

  static Future<String?> setActive(String id, {required bool active}) async {
    try {
      await _db.from(_table).update({
        'is_active': active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

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
      'is_active': true,
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
