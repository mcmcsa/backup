import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_repair_model.dart';

class PostRepairService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'post_repair_reports';

  /// Fetch all post-repair reports for a work request (ordered chronologically by attempt_number ascending)
  static Future<List<PostRepairReport>> fetchByWorkRequest(String workRequestId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('work_request_id', workRequestId)
        .order('attempt_number', ascending: true);
    final list = (data as List).map((e) => PostRepairReport.fromMap(e)).toList();
    list.sort((a, b) => a.attemptNumber.compareTo(b.attemptNumber));
    return list;
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


  /// Insert a new post-repair report
  static Future<PostRepairReport> insert(PostRepairReport report) async {
    final data = await _db
        .from(_table)
        .insert(report.toMap())
        .select()
        .single();
    return PostRepairReport.fromMap(data);
  }

  /// Requestor evaluates the post-repair report (Satisfy or Not Satisfy, optional rating and comment)
  static Future<void> submitRequestorEvaluation({
    required String id,
    required String requestorId,
    required String evaluation, // 'satisfy' or 'not_satisfy'
    int? rating, // 1 to 5 (optional)
    String? comment, // optional
  }) async {
    assert(evaluation == 'satisfy' || evaluation == 'not_satisfy',
        'Evaluation must be either satisfy or not_satisfy');
    if (rating != null) {
      assert(rating >= 1 && rating <= 5, 'Rating must be between 1 and 5');
    }

    final updateData = <String, dynamic>{
      'requestor_evaluation': evaluation,
      'requestor_rating': rating,
      'requestor_comment': (comment != null && comment.trim().isNotEmpty) ? comment.trim() : null,
      'requestor_evaluated_by': requestorId,
      'requestor_evaluated_date': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _db.from(_table).update(updateData).eq('id', id);
  }

  /// Admin evaluates the post-repair report - mark satisfied (completed)
  static Future<void> markSatisfied(String id, String adminId, {String? notes}) async {
    final existing = await fetchById(id);
    if (existing == null || !existing.isRequestorEvaluated) {
      throw StateError('Cannot finalize evaluation: Requestor has not yet evaluated this post-repair report.');
    }

    await _db.from(_table).update({
      'admin_evaluation': 'satisfied',
      'admin_evaluation_notes': notes,
      'admin_evaluated_by': adminId,
      'admin_evaluated_date': DateTime.now().toIso8601String(),
      'status': 'Completed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Admin evaluates the post-repair report - mark for rework
  static Future<void> markRework(String id, String adminId, String reworkNotes) async {
    final existing = await fetchById(id);
    if (existing == null || !existing.isRequestorEvaluated) {
      throw StateError('Cannot send for rework: Requestor has not yet evaluated this post-repair report.');
    }

    await _db.from(_table).update({
      'admin_evaluation': 'rework',
      'admin_evaluation_notes': reworkNotes,
      'admin_evaluated_by': adminId,
      'admin_evaluated_date': DateTime.now().toIso8601String(),
      'status': 'Rework',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }


}
