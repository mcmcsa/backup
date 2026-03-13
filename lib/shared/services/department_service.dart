import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/department_model.dart';

class DepartmentService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'departments';

  static Future<List<Department>> fetchAll() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => Department.fromMap(e)).toList();
  }

  static Future<List<Department>> fetchByCampus(String campus) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('campus', campus)
        .order('name', ascending: true);
    return (data as List).map((e) => Department.fromMap(e)).toList();
  }

  static Future<Department?> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Department.fromMap(data);
  }

  static Future<void> insert(Department department) async {
    await _db.from(_table).insert(department.toMap());
  }

  static Future<void> update(Department department) async {
    await _db.from(_table).update(department.toMap()).eq('id', department.id);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
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
    final code = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    final newDept = {
      'name': name,
      'code': '${code.substring(0, code.length > 10 ? 10 : code.length)}_${now.millisecondsSinceEpoch % 10000}',
      'campus': 'Main',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final inserted = await _db.from(_table).insert(newDept).select().single();
    return Department.fromMap(inserted);
  }
}
