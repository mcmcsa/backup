import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/work_request_model.dart';
import 'maintenance_status_service.dart';
import 'room_service.dart';

class WorkRequestService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'work_requests';

  static final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  static Stream<void> get onWorkRequestsChanged => _changeController.stream;

  /// Broadcast a change to all active in-memory listeners
  static void notifyChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
  static final RegExp _missingColumnRegex = RegExp(
    "Could not find the '([^']+)' column of 'work_requests'",
  );
  static const String _selectWithRelations =
      '*, '
      'building:buildings(name), '
      'department:departments(name), '
      'room:rooms(name, code), '
      'request_type:request_types(name), '
      'requestor:users!work_requests_requestor_id_fkey(name, teacher_users(position)), '
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
      final enrichedResults = await enrichMissingRequestorNames(results);
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = enrichedResults.map((r) => r.toMap()).toList();
        await prefs.setString(_cacheKey, json.encode(jsonList));
      } catch (e) {
        // Ignore cache save errors
      }
      
      return enrichedResults;
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
    final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
    return await enrichMissingRequestorNames(requests);
  }

  static Future<List<WorkRequest>> fetchAwaitingPreInspection() async {
    final data = await _db
        .from('pre_inspections')
        .select('work_request_id')
        .eq('status', 'Pending');
    final ids = (data as List).map((e) => e['work_request_id'] as String).toList();
    if (ids.isEmpty) return [];
    
    final requestsData = await _db
        .from(_table)
        .select(_selectWithRelations)
        .inFilter('id', ids)
        .order('date_submitted', ascending: false);
    return (requestsData as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  static Future<List<WorkRequest>> fetchAwaitingPostRepair() async {
    final data = await _db
        .from('post_repairs')
        .select('work_request_id')
        .eq('status', 'Pending');
    final ids = (data as List).map((e) => e['work_request_id'] as String).toList();
    if (ids.isEmpty) return [];
    
    final requestsData = await _db
        .from(_table)
        .select(_selectWithRelations)
        .inFilter('id', ids)
        .order('date_submitted', ascending: false);
    return (requestsData as List).map((e) => WorkRequest.fromMap(e)).toList();
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
          status != 'declined' &&
          status != 'cancelled' &&
          status != 'declined/cancelled';
    });
  }

  static Future<void> updateRoomStatusFromRequests(String roomId) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) return;

    try {
      final hasActive = await hasActiveRequestForRoom(normalizedRoomId);
      if (hasActive) {
        await RoomService.updateStatus(normalizedRoomId, 'maintenance');
      } else {
        await RoomService.updateStatus(normalizedRoomId, 'available');
      }
    } catch (_) {
      // Silently ignore failures
    }
  }

  static Future<List<WorkRequest>> fetchByRequestor(String requestorId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .eq('requestor_id', requestorId)
        .order('date_submitted', ascending: false);
    return (data as List).map((e) => WorkRequest.fromMap(e)).toList();
  }

  /// Enriches any requests where requestorName is empty by querying `users` table
  /// and `e_signatures` table (to bypass RLS limitations for non-admin roles).
  static Future<List<WorkRequest>> enrichMissingRequestorNames(
    List<WorkRequest> requests,
  ) async {
    if (requests.isEmpty) return requests;

    final missing = requests
        .where((r) => r.requestorName.trim().isEmpty)
        .toList();
    if (missing.isEmpty) return requests;

    var updatedList = List<WorkRequest>.from(requests);

    // 1. Try resolving via `users` table for requests that have requestorId
    final withReqId = missing
        .where((r) => r.requestorId != null && r.requestorId!.trim().isNotEmpty)
        .toList();
    if (withReqId.isNotEmpty) {
      final userIds = withReqId
          .map((r) => r.requestorId!.trim())
          .toSet()
          .toList();
      try {
        final users = await _db
            .from('users')
            .select('id, name')
            .inFilter('id', userIds);
        final nameMap = <String, String>{
          for (final u in (users as List))
            if (u['id'] != null &&
                u['name'] != null &&
                u['name'].toString().trim().isNotEmpty)
              u['id'].toString(): u['name'].toString().trim(),
        };
        if (nameMap.isNotEmpty) {
          updatedList = updatedList.map((r) {
            if (r.requestorName.trim().isEmpty &&
                r.requestorId != null &&
                nameMap.containsKey(r.requestorId)) {
              final name = nameMap[r.requestorId]!;
              return r.copyWith(
                requestorName: name,
                reportedByName: name,
              );
            }
            return r;
          }).toList();
        }
      } catch (_) {}
    }

    // 2. For any requests still missing requestorName, resolve via `e_signatures` table
    final stillMissing = updatedList
        .where((r) => r.requestorName.trim().isEmpty)
        .toList();
    if (stillMissing.isNotEmpty) {
      final reqIds = stillMissing.map((r) => r.id).toList();
      try {
        final sigs = await _db
            .from('e_signatures')
            .select('work_request_id, signer_name, signature_type, signer_role, signer_id')
            .inFilter('work_request_id', reqIds)
            .order('signed_at', ascending: true);
        if (sigs.isNotEmpty) {
          final sigNameMap = <String, String>{};
          for (final s in sigs) {
            final wId = s['work_request_id']?.toString() ?? '';
            final sName = s['signer_name']?.toString().trim() ?? '';
            final type = (s['signature_type'] ?? '').toString().toLowerCase();
            final role = (s['signer_role'] ?? '').toString().toLowerCase();
            if (wId.isNotEmpty && sName.isNotEmpty) {
              if (type == 'requestor' ||
                  type == 'request' ||
                  role == 'teacher' ||
                  !sigNameMap.containsKey(wId)) {
                sigNameMap[wId] = sName;
              }
            }
          }
          if (sigNameMap.isNotEmpty) {
            updatedList = updatedList.map((r) {
              if (r.requestorName.trim().isEmpty &&
                  sigNameMap.containsKey(r.id)) {
                final name = sigNameMap[r.id]!;
                return r.copyWith(
                  requestorName: name,
                  reportedByName: name,
                );
              }
              return r;
            }).toList();
          }
        }
      } catch (_) {}
    }

    return updatedList;
  }

  static Future<List<WorkRequest>> fetchAssignedTo(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return [];

    // 1. Direct assignments or accepted tickets
    final data = await _db
        .from(_table)
        .select(_selectWithRelations)
        .or('assigned_to_id.eq.$cleanUserId,accepted_by_id.eq.$cleanUserId')
        .order('date_submitted', ascending: false);
    final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
    final seenIds = requests.map((r) => r.id).toSet();

    // 2. Active collaborators (status != 'declined')
    try {
      final collabData = await _db
          .from('work_request_collaborators')
          .select('work_request_id')
          .eq('user_id', cleanUserId)
          .neq('status', 'declined');

      if (collabData is List && collabData.isNotEmpty) {
        final collabIds = collabData
            .map((row) => row['work_request_id']?.toString().trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty && !seenIds.contains(id))
            .toSet()
            .toList();

        if (collabIds.isNotEmpty) {
          final collabRequestsData = await _db
              .from(_table)
              .select(_selectWithRelations)
              .inFilter('id', collabIds);
          if (collabRequestsData is List) {
            for (final row in collabRequestsData) {
              final wr = WorkRequest.fromMap(row);
              if (seenIds.add(wr.id)) {
                requests.add(wr);
              }
            }
          }
        }
      }
    } catch (_) {}

    requests.sort((a, b) => (b.dateSubmitted ?? DateTime(1970))
        .compareTo(a.dateSubmitted ?? DateTime(1970)));

    return await enrichMissingRequestorNames(requests);
  }

  static Future<WorkRequest?> fetchById(String id) async {
    Map<String, dynamic>? data;
    try {
      // Try to fetch by UUID first with relations
      data = await _db
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
    } catch (_) {
      // If relations join fails due to RLS permissions on related tables, fall back to simple query
      try {
        data = await _db
            .from(_table)
            .select('*')
            .eq('id', id)
            .maybeSingle();
        if (data == null && id.startsWith('WR-')) {
          data = await _db
              .from(_table)
              .select('*')
              .eq('legacy_id', id)
              .maybeSingle();
        }
      } catch (_) {}
    }
    
    if (data == null) return null;
    var request = WorkRequest.fromMap(data);

    // Auto-recover attachments from candidate storage buckets if empty
    if (request.attachmentUrls == null || request.attachmentUrls!.isEmpty) {
      const candidateBuckets = [
        'work-evidence',
        'work-request-attachments',
        'work_evidence',
        'evidence',
        'images',
        'chat-attachments',
      ];
      final candidatePaths = [
        request.id,
        'work-evidence/${request.id}',
        'attachments/${request.id}',
        'work-requests/${request.id}',
      ];

      for (final bucket in candidateBuckets) {
        bool found = false;
        for (final path in candidatePaths) {
          try {
            final files = await _db.storage.from(bucket).list(path: path);
            if (files.isNotEmpty) {
              final recoveredUrls = files
                  .where((f) => f.name.isNotEmpty && !f.name.startsWith('.'))
                  .map((f) => _db.storage.from(bucket).getPublicUrl('$path/${f.name}'))
                  .toList();
              if (recoveredUrls.isNotEmpty) {
                request = request.copyWith(
                  attachmentUrls: recoveredUrls,
                  workEvidence: jsonEncode(recoveredUrls),
                );
                // Opportunistically save to DB so future fetches don't need to re-query storage
                try {
                  await _updateWithSchemaFallback(request.id, {
                    'work_evidence': jsonEncode(recoveredUrls),
                  });
                } catch (_) {}
                found = true;
                break;
              }
            }
          } catch (_) {}
        }
        if (found) break;
      }
    }

    // Enrich requestorName if still empty
    if (request.requestorName.trim().isEmpty) {
      final enriched = await enrichMissingRequestorNames([request]);
      if (enriched.isNotEmpty) {
        request = enriched.first;
      }
    }

    return request;
  }

  static Future<void> updateStatus(String id, String status) async {
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'status': status}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'status': status}).eq('id', id);
    }

    notifyChange();

    try {
      final request = await fetchById(id);
      if (request?.roomId != null) {
        await updateRoomStatusFromRequests(request!.roomId!);
      }
      if (request?.assignedToId != null) {
        await MaintenanceStatusService.syncStatusForUser(request!.assignedToId!);
      }
    } catch (_) {}
  }

  static Future<void> updatePriority(String id, String priority) async {
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'priority': priority}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'priority': priority}).eq('id', id);
    }
    notifyChange();
  }

  static Future<void> updateWorkEvidence(String id, String evidenceUrl) async {
    // Update by UUID, or by legacy_id if it looks like the old format
    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'work_evidence': evidenceUrl}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'work_evidence': evidenceUrl}).eq('id', id);
    }
    notifyChange();
  }

  static Future<String> uploadVoiceNote(String filePath, String requestId) async {
    final file = File(filePath);
    final ext = filePath.split('.').last;
    final fileName = '${requestId}_voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    await _db.storage.from('voice_recordings').upload(fileName, file);
    return _db.storage.from('voice_recordings').getPublicUrl(fileName);
  }

  /// Upload voice note from raw bytes — works on both Web and mobile.
  static Future<String> uploadVoiceNoteBytes(
    Uint8List bytes,
    String requestId, {
    String ext = 'm4a',
  }) async {
    final fileName = '${requestId}_voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mimeType = ext == 'webm' ? 'audio/webm' : 'audio/mp4';
    await _db.storage.from('voice_recordings').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: mimeType),
    );
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
    notifyChange();
  }

  static Future<void> assignTo(String id, String userId) async {
    final oldReq = await fetchById(id);
    final oldAssigneeId = oldReq?.assignedToId;

    if (id.startsWith('WR-')) {
      await _db.from(_table).update({'assigned_to_id': userId}).eq('legacy_id', id);
    } else {
      await _db.from(_table).update({'assigned_to_id': userId}).eq('id', id);
    }

    notifyChange();

    try {
      await MaintenanceStatusService.setBusyOnAssignment(userId, id);
      if (oldAssigneeId != null && oldAssigneeId != userId) {
        await MaintenanceStatusService.syncStatusForUser(oldAssigneeId);
      }
    } catch (_) {}
  }

  static Future<void> approveRequest(
    String id,
    String approvedById,
    String approvedByName, {
    String priority = '',
    String? estimatedDuration,
  }) async {
    DateTime? dateDue;
    if (estimatedDuration != null && estimatedDuration.trim().isNotEmpty) {
      final durLower = estimatedDuration.toLowerCase();
      if (durLower.contains('hour')) {
        final hours = int.tryParse(durLower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
        dateDue = DateTime.now().add(Duration(hours: hours));
      } else if (durLower.contains('day')) {
        final days = int.tryParse(durLower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        dateDue = DateTime.now().add(Duration(days: days));
      } else if (durLower.contains('week')) {
        final weeks = int.tryParse(durLower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        dateDue = DateTime.now().add(Duration(days: weeks * 7));
      } else {
        dateDue = DateTime.now().add(const Duration(days: 1));
      }
    }

    final updateData = {
      'status': 'In Progress',
      'maintenance_start_time': DateTime.now().toIso8601String(),
      'approved_by_id': approvedById,
      'approved_date': DateTime.now().toIso8601String(),
      if (priority.isNotEmpty) 'priority': priority,
      if (dateDue != null) 'date_due': dateDue.toIso8601String(),
      if (estimatedDuration != null && estimatedDuration.trim().isNotEmpty)
        'maintenance_notes': estimatedDuration.trim(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }

    notifyChange();

    try {
      final request = await fetchById(id);
      if (request?.roomId != null) {
        await updateRoomStatusFromRequests(request!.roomId!);
      }
    } catch (_) {}
  }

  static Future<void> completeRequest(String id) async {
    final updateData = {
      'status': 'Completed',
      'date_completed': DateTime.now().toIso8601String(),
      'maintenance_end_time': DateTime.now().toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }

    notifyChange();
    
    // Fetch to find who was assigned, so we can free them
    final request = await fetchById(id);
    if (request?.assignedToId != null) {
      await MaintenanceStatusService.setAvailableOnCompletion(request!.assignedToId!);
    }

    // Update room status
    if (request?.roomId != null && request!.roomId!.isNotEmpty) {
      await updateRoomStatusFromRequests(request.roomId!);
    }
  }

  /// Maintenance accepts the work request and starts work (sets to under_maintenance)
  static Future<void> acceptByMaintenance(
    String id,
    String maintenanceId,
    String maintenanceName,
  ) async {
    DateTime? dateDue;
    try {
      final request = await fetchById(id);
      final estimatedDuration = request?.maintenanceNotes;
      if (estimatedDuration != null && estimatedDuration.trim().isNotEmpty) {
        final durLower = estimatedDuration.toLowerCase();
        if (durLower.contains('hour')) {
          final hours = int.tryParse(durLower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
          dateDue = DateTime.now().add(Duration(hours: hours));
        } else if (durLower.contains('day')) {
          final days = int.tryParse(durLower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          dateDue = DateTime.now().add(Duration(days: days));
        } else if (durLower.contains('week')) {
          final weeks = int.tryParse(durLower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          dateDue = DateTime.now().add(Duration(days: weeks * 7));
        } else {
          dateDue = DateTime.now().add(const Duration(days: 1));
        }
      }
    } catch (_) {}

    final updateData = {
      'status': 'In Progress',
      'accepted_date': DateTime.now().toIso8601String(),
      'assigned_to_id': maintenanceId,
      'maintenance_start_time': DateTime.now().toIso8601String(),
      if (dateDue != null) 'date_due': dateDue.toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }

    notifyChange();
    
    await MaintenanceStatusService.setBusyOnAssignment(maintenanceId, id);

    try {
      final request = await fetchById(id);
      if (request?.roomId != null) {
        await updateRoomStatusFromRequests(request!.roomId!);
      }
    } catch (_) {}
  }

  /// Set status to Confirmed (after admin approves pre-inspection)
  static Future<void> setUnderMaintenance(String id) async {
    final updateData = {
      'status': 'Confirmed',
      'maintenance_start_time': DateTime.now().toIso8601String(),
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }

    notifyChange();

    try {
      final request = await fetchById(id);
      if (request?.roomId != null) {
        await updateRoomStatusFromRequests(request!.roomId!);
      }
    } catch (_) {}
  }

  /// Set status to rework
  static Future<void> setRework(String id, String reworkNotes) async {
    final request = await fetchById(id);
    final currentCount = request?.reworkCount ?? 0;
    final updateData = {
      'status': 'Rework',
      'rework_count': currentCount + 1,
      'rework_notes': reworkNotes,
      'maintenance_end_time': null,
    };
    if (id.startsWith('WR-')) {
      await _db.from(_table).update(updateData).eq('legacy_id', id);
    } else {
      await _db.from(_table).update(updateData).eq('id', id);
    }

    notifyChange();

    if (request?.roomId != null) {
      await updateRoomStatusFromRequests(request!.roomId!);
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
    return getCountByStatus('Confirmed');
  }

  /// Get approved count (waiting for maintenance acceptance)
  static Future<int> getApprovedCount() async {
    return getCountByStatus('In Progress');
  }

  static String generateId() => _generateWorkRequestId();

  /// Robust multi-bucket upload with automatic base64 data-URI fallback
  static Future<String?> uploadAttachmentBytes({
    required String workRequestId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final rawExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final ext = rawExt == 'jpg' ? 'jpeg' : rawExt;
    final path = '$workRequestId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    // List of buckets to try in priority order
    final buckets = ['work-evidence', 'work-request-attachments', 'chat-attachments'];

    for (final bucket in buckets) {
      try {
        await _db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
        final url = _db.storage.from(bucket).getPublicUrl(path);
        debugPrint('Successfully uploaded attachment to bucket "$bucket": $url');
        return url;
      } catch (e) {
        debugPrint('Upload to storage bucket "$bucket" failed: $e');
      }
    }

    // Ultimate fallback if cloud storage buckets reject: data URI base64
    try {
      final base64String = base64Encode(bytes);
      final dataUri = 'data:image/$ext;base64,$base64String';
      debugPrint('Attachment saved as resilient data URI (fileName: $fileName)');
      return dataUri;
    } catch (e) {
      debugPrint('Failed base64 data URI conversion: $e');
    }

    return null;
  }

  static Future<WorkRequest> insert(WorkRequest request) async {
    final payload = request.toMap();
    if ((payload['id']?.toString().trim().isEmpty ?? true)) {
      payload['id'] = _generateWorkRequestId();
    }

    // Automatically check for duplicates in the same room
    final roomId = payload['room_id'];
    if (roomId != null && roomId.toString().isNotEmpty) {
      try {
        final active = await _db
            .from(_table)
            .select('id')
            .eq('room_id', roomId)
            .neq('status', 'Completed')
            .neq('status', 'Declined')
            .order('date_submitted', ascending: true)
            .limit(1)
            .maybeSingle();
        if (active != null) {
          payload['duplicate_of_id'] = active['id'];
        }
      } catch (_) {
        // Silently ignore detection failures to not block submission
      }
    }

    final data = await _insertWithSchemaFallback(payload);
    
    // Update room status
    if (request.roomId != null && request.roomId!.isNotEmpty) {
      await updateRoomStatusFromRequests(request.roomId!);
    }

    notifyChange();

    return WorkRequest.fromMap(data);
  }

  static Future<void> update(WorkRequest request) async {
    await _updateWithSchemaFallback(request.id, request.toMap());
    if (request.roomId != null && request.roomId!.isNotEmpty) {
      await updateRoomStatusFromRequests(request.roomId!);
    }
    notifyChange();
  }

  static Future<void> delete(String id) async {
    String? roomId;
    try {
      final request = await fetchById(id);
      roomId = request?.roomId;
    } catch (_) {}

    if (id.startsWith('WR-')) {
      await _db.from(_table).delete().eq('legacy_id', id);
    } else {
      await _db.from(_table).delete().eq('id', id);
    }

    if (roomId != null && roomId.isNotEmpty) {
      await updateRoomStatusFromRequests(roomId);
    }
    notifyChange();
  }

  // Analytics methods
  static Future<int> getPendingCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'Pending');
    return (data as List?)?.length ?? 0;
  }

  static Future<int> getOngoingCount() async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('status', 'In Progress');
    return (data as List?)?.length ?? 0;
  }

  static Future<int> getCompletedCount() async {
    final data = await _db.from(_table).select('id').eq('status', 'Completed');
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
    final channelName =
        'realtime:work_requests_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 6)}';
    final channel = _db.realtime.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) async {
            notifyChange();
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
    final channelName =
        'realtime:work_requests_req_${requestorId}_${DateTime.now().millisecondsSinceEpoch}';
    final channel = _db.realtime.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) async {
            notifyChange();
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

  /// Set up real-time listener for requests assigned to a maintenance user
  static RealtimeChannel listenToMaintenanceRequests(
    String userId,
    Function(List<WorkRequest>) onUpdate,
  ) {
    final channelName =
        'realtime:work_requests_maint_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final channel = _db.realtime.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) async {
            notifyChange();
            try {
              final data = await fetchAssignedTo(userId);
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
