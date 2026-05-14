import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/department_model.dart';
import 'admin_audit_log_service.dart';

class DepartmentService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'departments';

  static Future<List<Department>> fetchAll() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => Department.fromMap(e)).toList();
  }

  static Future<List<Department>> fetchByCampus(String campus) async {
    return fetchAll();
  }

  static Future<Department?> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Department.fromMap(data);
  }

  static Future<void> insert(Department department) async {
    await _db.from(_table).insert(department.toMap());
    await AdminAuditLogService.logAction(
      title: 'Added Department',
      details: 'Department: ${department.name} (${department.id})',
    );
  }

  static Future<void> update(Department department) async {
    await _db.from(_table).update(department.toMap()).eq('id', department.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Department',
      details: 'Department: ${department.name} (${department.id})',
    );
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Deleted Department',
      details: 'Department ID: $id',
    );
  }

  /// Find a department by name, or create it if it doesn't exist.
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
    final inserted = await _db.from(_table).insert(newDept).select().single();
    await AdminAuditLogService.logAction(
      title: 'Created Department Automatically',
      details: 'Department: $name',
    );
    return Department.fromMap(inserted);
  }
}
