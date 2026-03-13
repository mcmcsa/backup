import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pre_inspection_model.dart';

class PreInspectionService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'pre_inspection_reports';

  /// Fetch all pre-inspection reports for a work request
  static Future<List<PreInspectionReport>> fetchByWorkRequest(String workRequestId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PreInspectionReport.fromMap(e)).toList();
  }

  /// Fetch latest pre-inspection report for a work request
  static Future<PreInspectionReport?> fetchLatestByWorkRequest(String workRequestId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return PreInspectionReport.fromMap(data);
  }

  /// Fetch by ID
  static Future<PreInspectionReport?> fetchById(String id) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return PreInspectionReport.fromMap(data);
  }

  /// Fetch all pending (submitted but not approved) reports
  static Future<List<PreInspectionReport>> fetchPending() async {
    final data = await _db
        .from(_table)
        .select()
        .eq('status', 'submitted')
        .order('created_at', ascending: false);
    return (data as List).map((e) => PreInspectionReport.fromMap(e)).toList();
  }

  /// Insert a new pre-inspection report
  static Future<PreInspectionReport> insert(PreInspectionReport report) async {
    final data = await _db
        .from(_table)
        .insert(report.toMap())
        .select()
        .single();
    return PreInspectionReport.fromMap(data);
  }

  /// Admin approves the pre-inspection report
  static Future<void> approve(String id, String adminId) async {
    await _db.from(_table).update({
      'admin_approved': true,
      'admin_approved_by': adminId,
      'admin_approved_date': DateTime.now().toIso8601String(),
      'status': 'approved',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Admin rejects the pre-inspection report
  static Future<void> reject(String id, String notes) async {
    await _db.from(_table).update({
      'admin_approved': false,
      'status': 'rejected',
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Fetch reports by inspector
  static Future<List<PreInspectionReport>> fetchByInspector(String inspectorId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('inspector_id', inspectorId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PreInspectionReport.fromMap(e)).toList();
  }
}
