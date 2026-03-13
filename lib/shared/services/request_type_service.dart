import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_type_model.dart';

class RequestTypeService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'request_types';

  static Future<List<RequestType>> fetchAll() async {
    final data = await _db
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);
    return (data as List).map((e) => RequestType.fromMap(e)).toList();
  }

  static Future<List<RequestType>> fetchAllIncludingInactive() async {
    final data = await _db.from(_table).select().order('name', ascending: true);
    return (data as List).map((e) => RequestType.fromMap(e)).toList();
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

  static Future<void> insert(RequestType requestType) async {
    await _db.from(_table).insert(requestType.toMap());
  }

  static Future<void> update(RequestType requestType) async {
    await _db.from(_table).update(requestType.toMap()).eq('id', requestType.id);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}
