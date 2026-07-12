import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_type_model.dart';
import 'admin_audit_log_service.dart';

class RequestTypeService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'request_types';

  // Return all, active or inactive. The UI will filter.
  static Future<List<RequestType>> fetchAll() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => RequestType.fromMap(e)).toList();
  }

  static Future<List<RequestType>> fetchAllIncludingInactive() async {
    return fetchAll();
  }

  static Future<RequestType?> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return RequestType.fromMap(data);
  }

  static Future<RequestType?> fetchByName(String name) async {
    final data = await _db.from(_table).select().eq('name', name).maybeSingle();
    if (data == null) return null;
    return RequestType.fromMap(data);
  }

  // ─── Create ──────────────────────────────────────────────────────────────

  static Future<String?> create({
    required String name,
    required String description,
    required String priority,
    required bool isActive,
  }) async {
    try {
      final existing = await fetchByName(name.trim());
      if (existing != null) return 'A request category named "$name" already exists.';

      final now = DateTime.now().toIso8601String();
      await _db.from(_table).insert({
        'name': name.trim(),
        'description': description.trim(),
        'priority': priority,
        'is_active': isActive,
        'created_at': now,
        'updated_at': now,
      });

      await AdminAuditLogService.logAction(
        title: 'Added Request Category',
        details: 'Category: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy insert
  static Future<void> insert(RequestType requestType) async {
    await _db.from(_table).insert(requestType.toMap());
    await AdminAuditLogService.logAction(
      title: 'Added Request Type',
      details: 'Request Type: ${requestType.name} (${requestType.id})',
    );
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  static Future<String?> updateCategory({
    required String id,
    required String name,
    required String description,
    required String priority,
    required bool isActive,
  }) async {
    try {
      final existing = await fetchByName(name.trim());
      if (existing != null && existing.id != id) {
        return 'A request category named "$name" already exists.';
      }

      await _db.from(_table).update({
        'name': name.trim(),
        'description': description.trim(),
        'priority': priority,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Updated Request Category',
        details: 'Category: $name',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy update
  static Future<void> update(RequestType requestType) async {
    await _db.from(_table).update(requestType.toMap()).eq('id', requestType.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Request Type',
      details: 'Request Type: ${requestType.name} (${requestType.id})',
    );
  }

  // ─── Status & Delete ──────────────────────────────────────────────────────

  static Future<void> setActive(String id, bool isActive, String name) async {
    await _db.from(_table).update({'is_active': isActive}).eq('id', id);
    await AdminAuditLogService.logAction(
      title: isActive ? 'Restored Request Category' : 'Disabled Request Category',
      details: 'Category: $name',
    );
  }

  static Future<String?> deleteCategory(String id, String name) async {
    try {
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted Request Category',
        details: 'Category: $name',
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
      title: 'Deleted Request Type',
      details: 'Request Type ID: $id',
    );
  }
}
