import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_repair_model.dart';

class PostRepairService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'post_repair_reports';

  /// Fetch all post-repair reports for a work request
  static Future<List<PostRepairReport>> fetchByWorkRequest(String workRequestId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PostRepairReport.fromMap(e)).toList();
  }

  /// Fetch latest post-repair report for a work request
  static Future<PostRepairReport?> fetchLatestByWorkRequest(String workRequestId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return PostRepairReport.fromMap(data);
  }

  /// Fetch by ID
  static Future<PostRepairReport?> fetchById(String id) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return PostRepairReport.fromMap(data);
  }

  /// Fetch all pending evaluation reports
  static Future<List<PostRepairReport>> fetchPendingEvaluation() async {
    final data = await _db
        .from(_table)
        .select()
        .eq('status', 'submitted')
        .order('created_at', ascending: false);
    return (data as List).map((e) => PostRepairReport.fromMap(e)).toList();
  }

  /// Insert a new post-repair report
  static Future<PostRepairReport> insert(PostRepairReport report) async {
    final data = await _db
        .from(_table)
        .insert(report.toMap())
        .select()
        .single();
    return PostRepairReport.fromMap(data);
  }

  /// Admin evaluates the post-repair report - mark satisfied (completed)
  static Future<void> markSatisfied(String id, String adminId, {String? notes}) async {
    await _db.from(_table).update({
      'admin_evaluation': 'satisfied',
      'admin_evaluation_notes': notes,
      'admin_evaluated_by': adminId,
      'admin_evaluated_date': DateTime.now().toIso8601String(),
      'status': 'evaluated',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Admin evaluates the post-repair report - mark for rework
  static Future<void> markRework(String id, String adminId, String reworkNotes) async {
    await _db.from(_table).update({
      'admin_evaluation': 'rework',
      'admin_evaluation_notes': reworkNotes,
      'admin_evaluated_by': adminId,
      'admin_evaluated_date': DateTime.now().toIso8601String(),
      'status': 'rework',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Fetch reports by technician
  static Future<List<PostRepairReport>> fetchByTechnician(String technicianId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('technician_id', technicianId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PostRepairReport.fromMap(e)).toList();
  }
}
