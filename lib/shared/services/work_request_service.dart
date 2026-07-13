import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/work_request_model.dart';
import 'maintenance_status_service.dart';

class WorkRequestService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'work_requests';
  static final RegExp _missingColumnRegex = RegExp(
    "Could not find the '([^']+)' column of 'work_requests'",
  );
  static const String _selectWithRelations =
      '*, '
      'building:buildings(name), '
      'department:departments(name), '
      'room:rooms(name), '
      'request_type:request_types(name), '
      'requestor:users!work_requests_requestor_id_fkey(name), '
      'approver:users!work_requests_approved_by_id_fkey(name), '
      'assignee:users!work_requests_assigned_to_id_fkey(name), '
      'pre_reports:pre_inspection_reports(id), '
      'post_reports:post_repair_reports(id)';
  static final Uuid _uuid = Uuid();

  static String _generateWorkRequestId() {
    return _uuid.v4();
  }

  static const String _cacheKey = 'work_requests_cache';

  static Future<List<WorkRequest>> fetchAll() async {
    try {
      final data = await _db
          .from(_table)
          .select(_selectWithRelations)
          .order('date_submitted', ascending: false);
      
      final results = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = results.map((r) => r.toMap()).toList();
        await prefs.setString(_cacheKey, json.encode(jsonList));
      } catch (e) {
        // Ignore cache save errors
      }
      
      return results;
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          final List decoded = json.decode(cached);
          return decoded.map((e) => WorkRequest.fromMap(e as Map<String, dynamic>)).toList();
        }
      } catch (cacheError) {
        // Ignore cache read errors
      }
      rethrow;
    }
  }

  static Future<List<WorkRequest>> fetchByStatus(String status) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('status', status)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByPriority(String priority) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('priority', priority)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByBuilding(String buildingId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('building_id', buildingId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByDepartment(
    String departmentId,
  ) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('department_id', departmentId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchByRoom(String roomId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
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
      return status != 'completed' &&
          status != 'completed' &&
          status != 'cancelled';
    });
  }

  static Future<List<WorkRequest>> fetchByRequestor(String requestorId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('requestor_id', requestorId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchAssignedTo(String userId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('assigned_to_id', userId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<WorkRequest?> fetchById(String id) async {
    // Try to fetch by UUID first (new format)
    var data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('id', id)
        .maybeSingle();
    
    // If not found and id looks like the old TEXT format, try legacy_id
    if (data == null && id.startsWith('WR-')) {
      data = await _db
          .from(_table)
          .select(_selectWithRelations)
          .eq('legacy_id', id)
          .maybeSingle();
    }
    
    if (data == null) return null;
    return WorkRequest.fromMap(data);
  }

  static Future<void> updateStatus(String id, String status) async {
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'status': status}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'status': status}).eq('id', id);
    }
  }

  static Future<void> updatePriority(String id, String priority) async {
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'priority': priority}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'priority': priority}).eq('id', id);
    }
  }

  static Future<void> updateWorkEvidence(String id, String evidenceUrl) async {
    // Update by UUID, or by legacy_id if it looks like the old format
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'work_evidence': evidenceUrl}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'work_evidence': evidenceUrl}).eq('id', id);
    }
  }

  static Future<String> uploadVoiceNote(String filePath, String requestId) async {
    final file = File(filePath);
    final ext = filePath.split('.').last;
    final fileName = '${requestId}_voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    await _db.storage.from('voice_recordings').upload(fileName, file);
    return _db.storage.from('voice_recordings').getPublicUrl(fileName);
  }

  static Future<void> updateMaintenanceNote(String id, String? note) async {
    final normalized = note?.trim();
    final updateData = {
      'maintenance_notes': (normalized == null || normalized.isEmpty)
          ? null
          : normalized,
    };
    
    // Update by UUID, or by legacy_id if it looks like the old format
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }
  }

  static Future<void> assignTo(String id, String userId) async {
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'assigned_to_id': userId}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'assigned_to_id': userId}).eq('id', id);
    }
  }

  static Future<void> approveRequest(
    String id,
    String approvedById,
    String approvedByName,
  ) async {
    final updateData = {
      'status': 'in_progress',
      'maintenance_start_time': DateTime.now().toIso8601String(),
      'approved_by_id': approvedById,
      'approved_date': DateTime.now().toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }
  }

  static Future<void> completeRequest(String id) async {
    final updateData = {
      'status': 'completed',
      'date_completed': DateTime.now().toIso8601String(),
      'maintenance_end_time': DateTime.now().toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }
    
    // Fetch to find who was assigned, so we can free them
    final request = await fetchById(id);
    if (request?.assignedToId != null) {
      await MaintenanceStatusService.setAvailableOnCompletion(request!.assignedToId!);
    }
  }

  /// Maintenance accepts the work request and starts work (sets to under_maintenance)
  static Future<void> acceptByMaintenance(
    String id,
    String maintenanceId,
    String maintenanceName,
  ) async {
    final updateData = {
      'status': 'under_maintenance',
      'accepted_date': DateTime.now().toIso8601String(),
      'assigned_to_id': maintenanceId,
      'maintenance_start_time': DateTime.now().toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }
    
    await MaintenanceStatusService.setBusyOnAssignment(maintenanceId, id);
  }

  /// Set status to under_maintenance (after admin approves pre-inspection)
  static Future<void> setUnderMaintenance(String id) async {
    final updateData = {
      'status': 'under_maintenance',
      'maintenance_start_time': DateTime.now().toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }
  }

  /// Set status to rework
  static Future<void> setRework(String id, String reworkNotes) async {
    final request = await fetchById(id);
    final currentCount = request?.reworkCount ?? 0;
    final updateData = {
      'status': 'rework',
      'rework_count': currentCount + 1,
      'rework_notes': reworkNotes,
      'maintenance_end_time': null,
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }
  }

  /// Link pre-inspection report to work request
  static Future<void> linkPreInspection(
    String id,
    String preInspectionId,
  ) async {
    // No-op after normalization: existence is derived from pre_inspection_reports.work_request_id.
    return;
  }

  /// Link post-repair report to work request
  static Future<void> linkPostRepair(String id, String postRepairId) async {
    // No-op after normalization: existence is derived from post_repair_reports.work_request_id.
    return;
  }

  /// Fetch requests by date range (for analytics)
  static Future<List<WorkRequest>> fetchByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .gte('date_submitted', start.toIso8601String())
        .lte('date_submitted', end.toIso8601String())
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  /// Get count by status
  static Future<int> getCountByStatus(String status) async {
    final data = await _db.from(_table).select('id').eq('status', status);
    return (data as List?)?.length ?? 0;
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
    final payload = request.toMap();
    if ((payload['id']?.toString().trim().isEmpty ?? true)) {
      payload['id'] = _generateWorkRequestId();
    }

    final data = await _insertWithSchemaFallback(payload);
    return WorkRequest.fromMap(data);
  }

  static Future<void> update(WorkRequest request) async {
    await _updateWithSchemaFallback(request.id, request.toMap());
  }

  static Future<void> delete(String id) async {
    if (id.startsWith('WR-')) {
      await _db.from(_table).delete().eq('legacy_id', id);
    } else {
      await _db.from(_table).delete().eq('id', id);
    }
  }

  // Analytics methods
  static Future<int> getPendingCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'pending');
    return (data as List?)?.length ?? 0;
  }

  static Future<int> getOngoingCount() async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('status', 'in_progress');
    return (data as List?)?.length ?? 0;
  }

  static Future<int> getCompletedCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'completed');
    return (data as List?)?.length ?? 0;
  }

  static Future<int> getHighPriorityCount() async {
    final data = await _db.from(_table).select('id').eq('priority', 'high');
    return (data as List?)?.length ?? 0;
  }

  /// Set up real-time listener for all work request changes
  /// Returns a RealtimeChannel subscription that should be cleaned up in dispose()
  static RealtimeChannel listenToAllWorkRequests(
    Function(List<WorkRequest>) onUpdate,
  ) {
    final channel = _db.realtime.channel('realtime:work_requests');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) async {
            try {
              // Fetch all updated data to ensure consistency
              final data = await fetchAll();
              onUpdate(data);
            } catch (_) {
              // Silently ignore errors
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Set up real-time listener for a specific requestor's requests
  static RealtimeChannel listenToRequestorRequests(
    String requestorId,
    Function(List<WorkRequest>) onUpdate,
  ) {
    final channel = _db.realtime.channel(
      'realtime:work_requests_requestor_$requestorId',
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) async {
            try {
              final data = await fetchByRequestor(requestorId);
              onUpdate(data);
            } catch (_) {
              // Silently ignore errors
            }
          },
        )
        .subscribe();

    return channel;
  }

  static Future<Map<String, dynamic>> _insertWithSchemaFallback(
    Map<String, dynamic> payload,
  ) async {
    final sanitizedPayload = Map<String, dynamic>.from(payload);

    while (true) {
      try {
        return await _db
            .from(_table)
            .insert(sanitizedPayload)
            .select(_selectWithRelations)
            .single();
      } on PostgrestException catch (error) {
        final removedColumn = _removeMissingSchemaColumn(
          error,
          sanitizedPayload,
        );
        if (!removedColumn) rethrow;
      }
    }
  }

  static Future<void> _updateWithSchemaFallback(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final sanitizedPayload = Map<String, dynamic>.from(payload);

    while (true) {
      try {
        final query = _db.from(_table).update(sanitizedPayload);
        if (id.startsWith('WR-')) {
          await query.eq('legacy_id', id);
        } else {
          await query.eq('id', id);
        }
        return;
      } on PostgrestException catch (error) {
        final removedColumn = _removeMissingSchemaColumn(
          error,
          sanitizedPayload,
        );
        if (!removedColumn) rethrow;
      }
    }
  }

  static bool _removeMissingSchemaColumn(
    PostgrestException error,
    Map<String, dynamic> payload,
  ) {
    final match = _missingColumnRegex.firstMatch(error.message);
    final missingColumn = match?.group(1);
    if (missingColumn == null || !payload.containsKey(missingColumn)) {
      return false;
    }

    payload.remove(missingColumn);
    return true;
  }
}
