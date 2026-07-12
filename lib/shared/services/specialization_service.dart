import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/specialization_model.dart';
import 'admin_audit_log_service.dart';

class SpecializationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'specializations';

  static Future<List<Specialization>> fetchAll() async {
    try {
      final data = await _db.from(_table).select().order('name', ascending: true);
      return (data as List).map((e) => Specialization.fromMap(e)).toList();
    } catch (e) {
      // In case the table doesn't exist yet, return an empty list gracefully
      return [];
    }
  }

  static Future<Specialization?> fetchByName(String name) async {
    try {
      final data = await _db.from(_table).select().eq('name', name).maybeSingle();
      if (data == null) return null;
      return Specialization.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  static Future<String?> create({
    required String name,
    required String description,
    required bool isActive,
  }) async {
    try {
      final existing = await fetchByName(name.trim());
      if (existing != null) return 'A specialization named "$name" already exists.';

      final now = DateTime.now().toIso8601String();
      await _db.from(_table).insert({
        'name': name.trim(),
        'description': description.trim(),
        'is_active': isActive,
        'created_at': now,
        'updated_at': now,
      });

      await AdminAuditLogService.logAction(
        title: 'Added Specialization',
        details: 'Specialization: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> updateSpecialization({
    required String id,
    required String name,
    required String description,
    required bool isActive,
  }) async {
    try {
      final existing = await fetchByName(name.trim());
      if (existing != null && existing.id != id) {
        return 'A specialization named "$name" already exists.';
      }

      await _db.from(_table).update({
        'name': name.trim(),
        'description': description.trim(),
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Updated Specialization',
        details: 'Specialization: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> setActive(String id, bool isActive, String name) async {
    await _db.from(_table).update({'is_active': isActive}).eq('id', id);
    await AdminAuditLogService.logAction(
      title: isActive ? 'Restored Specialization' : 'Disabled Specialization',
      details: 'Specialization: $name',
    );
  }

  static Future<String?> deleteSpecialization(String id, String name) async {
    try {
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted Specialization',
        details: 'Specialization: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
