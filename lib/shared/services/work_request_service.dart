import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_request_model.dart';

class WorkRequestService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'work_requests';

  static Future<List<WorkRequest>> fetchAll() async {
    final data = await _db
        .from(_table)
        .select()
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByStatus(String status) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('status', status)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByPriority(String priority) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('priority', priority)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByBuilding(String buildingId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('building_id', buildingId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByDepartment(
    String departmentId,
  ) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('department_id', departmentId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByRoom(String roomId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('room_id', roomId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  /// Returns true when a room already has an active report.
  /// Active means not yet completed.
  static Future<bool> hasActiveRequestForRoom(String roomId) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) return false;

    final requests = await fetchByRoom(normalizedRoomId);
    return requests.any((request) {
      final status = request.status.toLowerCase();
      return status != 'completed' && status != 'done';
    });
  }

  static Future<List<WorkRequest>> fetchByRequestor(String requestorId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('requestor_id', requestorId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchAssignedTo(String userId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('assigned_to_id', userId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<WorkRequest?> fetchById(String id) async {
    final data = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return WorkRequest.fromMap(data);
  }

  static Future<void> updateStatus(String id, String status) async {
    await _db.from(_table).update({'status': status}).eq('id', id);
  }

  static Future<void> updatePriority(String id, String priority) async {
    await _db.from(_table).update({'priority': priority}).eq('id', id);
  }

  static Future<void> assignTo(String id, String userId) async {
    await _db.from(_table).update({'assigned_to_id': userId}).eq('id', id);
  }

  static Future<void> approveRequest(
    String id,
    String approvedById,
    String approvedByName,
  ) async {
    await _db
        .from(_table)
        .update({
          'status': 'in_progress',
          'maintenance_start_time': DateTime.now().toIso8601String(),
          'approved_by_id': approvedById,
          'approved_by': approvedByName,
          'approved_date': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  static Future<void> completeRequest(String id) async {
    await _db
        .from(_table)
        .update({
          'status': 'completed',
          'date_completed': DateTime.now().toIso8601String(),
          'maintenance_end_time': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Maintenance accepts the work request
  static Future<void> acceptByMaintenance(
    String id,
    String maintenanceId,
    String maintenanceName,
  ) async {
    await _db
        .from(_table)
        .update({
          'status': 'in_progress',
          'accepted_by_id': maintenanceId,
          'accepted_by_name': maintenanceName,
          'accepted_date': DateTime.now().toIso8601String(),
          'assigned_to_id': maintenanceId,
        })
        .eq('id', id);
  }

  /// Set status to under_maintenance (after admin approves pre-inspection)
  static Future<void> setUnderMaintenance(String id) async {
    await _db
        .from(_table)
        .update({
          'status': 'under_maintenance',
          'maintenance_start_time': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Set status to rework
  static Future<void> setRework(String id, String reworkNotes) async {
    final request = await fetchById(id);
    final currentCount = request?.reworkCount ?? 0;
    await _db
        .from(_table)
        .update({
          'status': 'rework',
          'rework_count': currentCount + 1,
          'rework_notes': reworkNotes,
          'maintenance_end_time': null,
        })
        .eq('id', id);
  }

  /// Link pre-inspection report to work request
  static Future<void> linkPreInspection(
    String id,
    String preInspectionId,
  ) async {
    await _db
        .from(_table)
        .update({'pre_inspection_id': preInspectionId})
        .eq('id', id);
  }

  /// Link post-repair report to work request
  static Future<void> linkPostRepair(String id, String postRepairId) async {
    await _db
        .from(_table)
        .update({'post_repair_id': postRepairId})
        .eq('id', id);
  }

  /// Fetch requests by date range (for analytics)
  static Future<List<WorkRequest>> fetchByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final data = await _db
        .from(_table)
        .select()
        .gte('date_submitted', start.toIso8601String())
        .lte('date_submitted', end.toIso8601String())
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  /// Get count by status
  static Future<int> getCountByStatus(String status) async {
    final data = await _db.from(_table).select('id').eq('status', status);
    return (data as List).length;
  }

  /// Get under maintenance count
  static Future<int> getUnderMaintenanceCount() async {
    return getCountByStatus('under_maintenance');
  }

  /// Get approved count (waiting for maintenance acceptance)
  static Future<int> getApprovedCount() async {
    return getCountByStatus('approved');
  }

  static Future<WorkRequest> insert(WorkRequest request) async {
    final data = await _db
        .from(_table)
        .insert(request.toMap())
        .select()
        .single();
    return WorkRequest.fromMap(data);
  }

  static Future<void> update(WorkRequest request) async {
    await _db.from(_table).update(request.toMap()).eq('id', request.id);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  // Analytics methods
  static Future<int> getPendingCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'pending');
    return (data as List).length;
  }

  static Future<int> getOngoingCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'ongoing');
    return (data as List).length;
  }

  static Future<int> getCompletedCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'done');
    return (data as List).length;
  }

  static Future<int> getHighPriorityCount() async {
    final data = await _db.from(_table).select('id').eq('priority', 'high');
    return (data as List).length;
  }
}
