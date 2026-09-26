import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/work_request_model.dart';
import '../models/room_model.dart';
import 'maintenance_status_service.dart';
import 'room_service.dart';
import 'department_service.dart';
import 'app_notification_service.dart';

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
      'dept_head:users!work_requests_dept_head_id_fkey(name), '
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

  /// Fetch requests awaiting approval by the designated Department Head
  static Future<List<WorkRequest>> fetchPendingForDeptHead(String deptHeadId) async {
    final cleanId = deptHeadId.trim();
    if (cleanId.isEmpty) return [];
    try {
      final data = await _db
          .from(_table)
          .select(_selectWithRelations)
          .eq('dept_head_id', cleanId)
          .eq('dept_head_status', 'pending')
          .neq('status', 'Cancelled')
          .order('date_submitted', ascending: false);
      final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
      return await enrichMissingRequestorNames(requests);
    } catch (_) {
      try {
        final data = await _db
            .from(_table)
            .select()
            .eq('dept_head_id', cleanId)
            .eq('dept_head_status', 'pending')
            .neq('status', 'Cancelled')
            .order('date_submitted', ascending: false);
        final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
        return await enrichMissingRequestorNames(requests);
      } catch (e) {
        return [];
      }
    }
  }

  /// Fetch all requests that were evaluated (approved or acknowledged) or cancelled for this Department Head
  static Future<List<WorkRequest>> fetchEvaluatedByDeptHead(String deptHeadId) async {
    final cleanId = deptHeadId.trim();
    if (cleanId.isEmpty) return [];
    try {
      final data = await _db
          .from(_table)
          .select(_selectWithRelations)
          .eq('dept_head_id', cleanId)
          .neq('dept_head_status', 'pending')
          .order('date_submitted', ascending: false);
      final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
      return await enrichMissingRequestorNames(requests);
    } catch (_) {
      try {
        final data = await _db
            .from(_table)
            .select()
            .eq('dept_head_id', cleanId)
            .neq('dept_head_status', 'pending')
            .order('date_submitted', ascending: false);
        final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
        return await enrichMissingRequestorNames(requests);
      } catch (e) {
        return [];
      }
    }
  }

  /// Fetch requests awaiting Campus Admin assignment & approval
  static Future<List<WorkRequest>> fetchPendingForCampusAdmin() async {
    try {
      final data = await _db
          .from(_table)
          .select(_selectWithRelations)
          .or('status.eq.Pending,status.eq.Pending Campus Admin')
          .neq('dept_head_status', 'pending')
          .neq('dept_head_status', 'acknowledged')
          .neq('status', 'Cancelled')
          .neq('status', 'Acknowledged')
          .order('date_submitted', ascending: false);
      final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
      final filtered = requests.where((r) => !r.isPendingDeptHead && !r.isAcknowledged && !r.isCancelled).toList();
      return await enrichMissingRequestorNames(filtered);
    } catch (_) {
      try {
        final data = await _db
            .from(_table)
            .select('*')
            .or('status.eq.Pending,status.eq.Pending Campus Admin')
            .neq('dept_head_status', 'pending')
            .neq('dept_head_status', 'acknowledged')
            .neq('status', 'Cancelled')
            .neq('status', 'Acknowledged')
            .order('date_submitted', ascending: false);
        final requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
        final filtered = requests.where((r) => !r.isPendingDeptHead && !r.isAcknowledged && !r.isCancelled).toList();
        return await enrichMissingRequestorNames(filtered);
      } catch (e) {
        return [];
      }
    }
  }

  static Future<List<WorkRequest>> fetchAwaitingPreInspection() async {
    final data = await _db
        .from('pre_inspection_reports')
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
        .from('post_repair_reports')
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

  /// Returns the latest active work request for a room by ID, code, or name.
  /// If no active request exists, returns null.
  static Future<WorkRequest?> getActiveRequestForRoom({
    required String roomId,
    String? roomCode,
    String? roomName,
  }) async {
    final cleanId = roomId.trim();
    if (cleanId.isEmpty) return null;

    try {
      List<WorkRequest> requests = await fetchByRoom(cleanId);
      if (requests.isEmpty && roomName != null && roomName.trim().isNotEmpty) {
        final data = await _db
            .from(_table)
            .select(_selectWithRelations)
            .ilike('office_room', '%${roomName.trim()}%')
            .order('date_submitted', ascending: false);
        requests = (data as List).map((e) => WorkRequest.fromMap(e)).toList();
      }

      for (final req in requests) {
        final status = req.status.toLowerCase().trim();
        final isFinished = status == 'completed' ||
            status == 'complete' ||
            status == 'declined' ||
            status == 'cancelled' ||
            status == 'canceled' ||
            req.isCancelled ||
            status == 'declined/cancelled' ||
            status == 'acknowledged';
        if (!isFinished) {
          return req;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns true when a room already has an active report.
  /// Active means not yet completed, cancelled, or declined.
  static Future<bool> hasActiveRequestForRoom(String roomId, {String? roomName}) async {
    final activeRequest = await getActiveRequestForRoom(roomId: roomId, roomName: roomName);
    return activeRequest != null;
  }

  static Future<void> updateRoomStatusFromRequests(String roomId, {String? roomName}) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) return;

    try {
      final activeRequest = await getActiveRequestForRoom(roomId: normalizedRoomId, roomName: roomName);
      if (activeRequest != null) {
        await RoomService.updateStatus(normalizedRoomId, activeRequest.status.toLowerCase());
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

  /// Fetches complete history for a user:
  /// 1. Requests submitted by the user (where status is completed, cancelled, declined, or acknowledged)
  /// 2. Requests evaluated by the user as Department Head (approved, acknowledged, or declined)
  /// This ensures that even if a Department Head steps down or becomes a regular faculty,
  /// they can always review their past evaluations, approvals, and acknowledgements in their History page.
  static Future<List<WorkRequest>> fetchHistoryForUser(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return [];

    try {
      final results = await Future.wait([
        fetchByRequestor(cleanId),
        fetchEvaluatedByDeptHead(cleanId),
      ]);

      final requested = results[0];
      final evaluated = results[1];

      // Requests submitted by user that have concluded
      final historicalRequested = requested.where((r) {
        final s = r.status.toLowerCase();
        return s == 'completed' ||
            s == 'complete' ||
            s == 'declined' ||
            s == 'cancelled' ||
            s == 'canceled' ||
            r.isCancelled ||
            s == 'declined/cancelled' ||
            s == 'pre-inspection declined' ||
            s == 'acknowledged' ||
            r.isAcknowledged;
      });

      // Deduplicate by ID (giving precedence to enriched evaluated data)
      final map = <String, WorkRequest>{};
      for (final r in historicalRequested) {
        map[r.id] = r;
      }
      for (final r in evaluated) {
        map[r.id] = r;
      }

      final combined = map.values.toList();
      combined.sort((a, b) {
        final dateA = a.deptHeadApprovedDate ?? a.dateSubmitted;
        final dateB = b.deptHeadApprovedDate ?? b.dateSubmitted;
        return dateB.compareTo(dateA);
      });

      return await enrichMissingRequestorNames(combined);
    } catch (e) {
      debugPrint('[WorkRequestService] Error in fetchHistoryForUser: $e');
      return [];
    }
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

    // 3. Resolve Dept Head names for requests that have deptHeadId but missing deptHeadName
    final missingDeptHead = updatedList
        .where((r) => r.deptHeadId != null && r.deptHeadId!.trim().isNotEmpty && (r.deptHeadName == null || r.deptHeadName!.trim().isEmpty))
        .toList();
    if (missingDeptHead.isNotEmpty) {
      final deptHeadUserIds = missingDeptHead.map((r) => r.deptHeadId!.trim()).toSet().toList();
      try {
        final headUsers = await _db
            .from('users')
            .select('id, name')
            .inFilter('id', deptHeadUserIds);
        final headNameMap = <String, String>{
          for (final u in (headUsers as List))
            if (u['id'] != null && u['name'] != null && u['name'].toString().trim().isNotEmpty)
              u['id'].toString(): u['name'].toString().trim(),
        };
        if (headNameMap.isNotEmpty) {
          updatedList = updatedList.map((r) {
            if (r.deptHeadId != null && headNameMap.containsKey(r.deptHeadId)) {
              return r.copyWith(deptHeadName: headNameMap[r.deptHeadId]);
            }
            return r;
          }).toList();
        }
      } catch (_) {}
    }

    return updatedList;
  }

  static Future<List<WorkRequest>> fetchAssignedTo(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return [];

    List<WorkRequest> requests = [];
    final seenIds = <String>{};

    // 1. Direct assignments
    try {
      final data = await _db
          .from(_table)
          .select(_selectWithRelations)
          .eq('assigned_to_id', cleanUserId)
          .order('date_submitted', ascending: false);
      for (final e in (data as List)) {
        final wr = WorkRequest.fromMap(e);
        if (seenIds.add(wr.id)) {
          requests.add(wr);
        }
      }
    } catch (_) {
      // Fallback to simple select if joins fail
      try {
        final data = await _db
            .from(_table)
            .select('*')
            .eq('assigned_to_id', cleanUserId)
            .order('date_submitted', ascending: false);
        for (final e in (data as List)) {
          final wr = WorkRequest.fromMap(e);
          if (seenIds.add(wr.id)) {
            requests.add(wr);
          }
        }
      } catch (_) {}
    }

    // 2. Active collaborators (status != 'declined')
    try {
      final collabData = await _db
          .from('work_request_collaborators')
          .select('work_request_id')
          .eq('user_id', cleanUserId)
          .neq('status', 'declined');

      if (collabData.isNotEmpty) {
        final collabIds = collabData
            .map((row) => row['work_request_id']?.toString().trim())
            .whereType<String>()
            .where((id) => id.isNotEmpty && !seenIds.contains(id))
            .toSet()
            .toList();

        if (collabIds.isNotEmpty) {
          try {
            final collabRequestsData = await _db
                .from(_table)
                .select(_selectWithRelations)
                .inFilter('id', collabIds);
            for (final row in collabRequestsData) {
              final wr = WorkRequest.fromMap(row);
              if (seenIds.add(wr.id)) {
                requests.add(wr);
              }
            }
          } catch (_) {
            final collabRequestsData = await _db
                .from(_table)
                .select('*')
                .inFilter('id', collabIds);
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

    requests.sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));

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
    if (oldReq != null && oldReq.isPendingDeptHead) {
      throw Exception('Action Denied: Cannot assign maintenance while request is pending Department Head review.');
    }
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

  static Future<bool> _safeUpdateWorkRequest(String id, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    while (true) {
      try {
        final res = await (id.startsWith('WR-')
            ? _db.from(_table).update(payload).eq('legacy_id', id).select('id')
            : _db.from(_table).update(payload).eq('id', id).select('id'));
        if (res.isEmpty) {
          debugPrint('[WorkRequestService] Warning: update on $id modified 0 rows (possible RLS restriction).');
          return false;
        }
        return true;
      } on PostgrestException catch (e) {
        if (e.message.contains('work_requests_status_check')) {
          if (payload['status'] == 'Pending Department Head') {
            // Old DBs without 'Pending Department Head' constraint: fall back gracefully
            payload['status'] = 'Pending';
            continue;
          } else if (payload['status'] == 'Acknowledged') {
            payload['status'] = 'Completed';
            continue;
          } else if (payload['status'] == 'Cancelled') {
            payload['status'] = 'Declined';
            continue;
          }
          // 'Pending Campus Admin' must NOT be silently downgraded to 'Pending' —
          // that would leave dept_head_status='pending' and break the whole workflow.
          // Surface the error so the caller (and developer) can see it.
        }
        final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
        if (match != null) {
          final missingCol = match.group(1);
          if (missingCol != null && payload.containsKey(missingCol)) {
            debugPrint('[WorkRequestService] Schema fallback: removing missing column "$missingCol"');
            payload.remove(missingCol);
            continue;
          }
        }
        rethrow;
      }
    }
  }

  static Future<void> _safeInsertSignature(Map<String, dynamic> sigPayload) async {
    try {
      await _db.from('e_signatures').insert(sigPayload);
    } on PostgrestException catch (e) {
      if (e.message.contains('e_signatures_signature_type_check') ||
          e.message.contains('e_signatures_signer_role_check') ||
          e.message.contains('signature_type') ||
          e.message.contains('signer_role')) {
        final fallback = Map<String, dynamic>.from(sigPayload);
        fallback['signature_type'] = 'approval';
        fallback['signer_role'] = 'teacher';
        try {
          await _db.from('e_signatures').insert(fallback);
        } catch (_) {}
      } else {
        rethrow;
      }
    }
  }

  /// Department Head approves/endorses a work request
  static Future<bool> approveByDeptHead(
    String id,
    String deptHeadId,
    String deptHeadName, {
    String? notes,
    String? signatureData,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'dept_head_status': 'approved',
      'dept_head_approved_date': nowIso,
      if (notes != null && notes.trim().isNotEmpty) 'dept_head_notes': notes.trim(),
      'status': 'Pending Campus Admin', // Advances ticket to Campus Admin queue
    };

    final updated = await _safeUpdateWorkRequest(id, updateData);

    if (signatureData != null && signatureData.trim().isNotEmpty) {
      try {
        await _safeInsertSignature({
          'work_request_id': id,
          'signer_id': deptHeadId,
          'signer_name': deptHeadName,
          'signer_role': 'dept_head',
          'signature_type': 'dept_head_approval',
          'signature_data': signatureData,
          'signed_at': nowIso,
        });
      } catch (e) {
        debugPrint('Failed to save dept head approval signature: $e');
      }
    }

    notifyChange();

    unawaited(() async {
      try {
        final req = await fetchById(id);
        if (req != null) {
          await AppNotificationService.notifyCampusAdminDeptHeadApproved(
            workRequestId: req.id,
            requestTitle: req.title,
            deptHeadName: deptHeadName,
            departmentName: req.departmentName ?? 'Department',
          );
          if (req.requestorId != null && req.requestorId!.isNotEmpty) {
            await AppNotificationService.notifyRequestorDeptHeadDecision(
              requestorId: req.requestorId!,
              workRequestId: req.id,
              requestTitle: req.title,
              isApproved: true,
              deptHeadName: deptHeadName,
              notes: notes,
            );
          }
        }
      } catch (e) {
        debugPrint('[WorkRequestService] Error sending dept head approval notifications: $e');
      }
    }());

    return updated;
  }

  /// Department Head acknowledges a work request (department will handle internally)
  static Future<bool> acknowledgeByDeptHead(
    String id,
    String deptHeadId,
    String deptHeadName, {
    String? notes,
    String? signatureData,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'dept_head_status': 'acknowledged',
      'dept_head_approved_date': nowIso,
      if (notes != null && notes.trim().isNotEmpty) 'dept_head_notes': notes.trim(),
      'status': 'Acknowledged', // Request handled internally; terminates centralized workflow
    };

    final updated = await _safeUpdateWorkRequest(id, updateData);

    if (signatureData != null && signatureData.trim().isNotEmpty) {
      try {
        await _safeInsertSignature({
          'work_request_id': id,
          'signer_id': deptHeadId,
          'signer_name': deptHeadName,
          'signer_role': 'dept_head',
          'signature_type': 'dept_head_acknowledgement',
          'signature_data': signatureData,
          'signed_at': nowIso,
        });
      } catch (e) {
        debugPrint('Failed to save dept head acknowledgement signature: $e');
      }
    }

    notifyChange();

    unawaited(() async {
      try {
        final req = await fetchById(id);
        if (req?.requestorId != null && req!.requestorId!.isNotEmpty) {
          await AppNotificationService.notifyRequestorDeptHeadAcknowledged(
            requestorId: req.requestorId!,
            workRequestId: req.id,
            requestTitle: req.title,
            deptHeadName: deptHeadName,
            notes: notes,
          );
        }
      } catch (e) {
        debugPrint('[WorkRequestService] Error sending dept head acknowledgement notification: $e');
      }
    }());

    return updated;
  }

  /// Requestor cancels a work request
  static Future<void> cancelByRequestor(
    String id,
    String userId, {
    required String reasonType,
    String? reason,
  }) async {
    final req = await fetchById(id);
    if (req == null) throw Exception('Request not found.');

    final isDeptOwned = req.departmentId != null && req.deptHeadStatus != 'not_applicable';
    if (isDeptOwned) {
      if (req.deptHeadStatus != 'pending') {
        throw Exception('Cannot cancel request after Department Head has made a decision.');
      }
    } else {
      if (req.status.toLowerCase() != 'pending' || req.assignedToId != null) {
        throw Exception('Cannot cancel request after maintenance processing has begun.');
      }
    }

    final nowIso = DateTime.now().toIso8601String();
    final resolvedReason = (reason != null && reason.trim().isNotEmpty) ? reason.trim() : reasonType;
    final updateData = {
      'status': 'Cancelled',
      'cancelled_by': userId,
      'cancelled_at': nowIso,
      'cancellation_reason_type': reasonType,
      'cancellation_reason': resolvedReason,
    };

    try {
      if (id.startsWith('WR-')) {
        await _db.from(_table).update(updateData).eq('legacy_id', id);
      } else {
        await _db.from(_table).update(updateData).eq('id', id);
      }
    } on PostgrestException catch (e) {
      if (e.message.contains('work_requests_status_check')) {
        updateData['status'] = 'Declined';
        if (id.startsWith('WR-')) {
          await _db.from(_table).update(updateData).eq('legacy_id', id);
        } else {
          await _db.from(_table).update(updateData).eq('id', id);
        }
      } else {
        rethrow;
      }
    }

    notifyChange();

    try {
      if (req.roomId != null) {
        await updateRoomStatusFromRequests(req.roomId!);
      }
      await AppNotificationService.notifyRequestorCancelled(
        workRequestId: req.id,
        requestTitle: req.title,
        deptHeadId: req.deptHeadId,
      );
    } catch (_) {}
  }

  /// Department Head declines a work request (legacy/fallback method)
  static Future<void> declineByDeptHead(
    String id,
    String deptHeadId,
    String deptHeadName, {
    required String reason,
    String? signatureData,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'dept_head_status': 'declined',
      'dept_head_approved_date': nowIso,
      'dept_head_notes': reason.trim(),
      'status': 'Declined', // Request ends and does NOT proceed to Campus Admin
    };

    await _safeUpdateWorkRequest(id, updateData);

    if (signatureData != null && signatureData.trim().isNotEmpty) {
      try {
        await _safeInsertSignature({
          'work_request_id': id,
          'signer_id': deptHeadId,
          'signer_name': deptHeadName,
          'signer_role': 'dept_head',
          'signature_type': 'dept_head_approval',
          'signature_data': signatureData,
          'signed_at': nowIso,
        });
      } catch (_) {}
    }

    notifyChange();

    unawaited(() async {
      try {
        final req = await fetchById(id);
        if (req?.requestorId != null && req!.requestorId!.isNotEmpty) {
          await AppNotificationService.notifyRequestorDeptHeadDecision(
            requestorId: req.requestorId!,
            workRequestId: req.id,
            requestTitle: req.title,
            isApproved: false,
            deptHeadName: deptHeadName,
            notes: reason,
          );
        }
      } catch (_) {}
    }());
  }

  static Future<void> approveRequest(
    String id,
    String approvedById,
    String approvedByName, {
    String priority = '',
    String? estimatedDuration,
  }) async {
    final existing = await fetchById(id);
    if (existing != null && existing.isPendingDeptHead) {
      throw Exception('Action Denied: Cannot approve request while pending Department Head review.');
    }
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
    final mimeType = _normalizeAttachmentMimeType(rawExt);
    final ext = mimeType == 'image/jpeg' ? 'jpg' : rawExt;
    final sanitizedFileName = fileName.contains('.')
        ? '${fileName.substring(0, fileName.lastIndexOf('.'))}.$ext'
        : '$fileName.$ext';
    final path = '$workRequestId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    // List of buckets to try in priority order
    final buckets = ['work-evidence', 'work-request-attachments', 'chat-attachments'];

    for (final bucket in buckets) {
      try {
        await _db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
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
      final dataUri = 'data:$mimeType;base64,$base64String';
      debugPrint('Attachment saved as resilient data URI (fileName: $fileName)');
      return dataUri;
    } catch (e) {
      debugPrint('Failed base64 data URI conversion: $e');
    }

    return null;
  }

  static String _normalizeAttachmentMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'jpg':
      case 'jpeg':
      case 'jfif':
      case 'pjpeg':
      case 'pjp':
      default:
        return 'image/jpeg';
    }
  }

  static Future<WorkRequest> insert(WorkRequest request) async {
    final payload = request.toMap();
    if ((payload['id']?.toString().trim().isEmpty ?? true)) {
      payload['id'] = _generateWorkRequestId();
    }

    Room? room;
    if (request.roomId != null && request.roomId!.toString().trim().isNotEmpty) {
      room = await RoomService.fetchById(request.roomId!.toString().trim());
    }

    final roomHasDepartment = room != null && room.departmentId.trim().isNotEmpty;

    // Layer 2: Room-to-Department Validation & Routing
    bool isHead = false;
    String? resolvedDeptHeadId;

    if (roomHasDepartment) {
      // Cross-department check: if requestor specifies a department, it must match the room's department
      if (request.departmentId != null &&
          request.departmentId!.trim().isNotEmpty &&
          request.departmentId!.trim() != room.departmentId.trim()) {
        throw Exception('Access Denied: Selected room does not belong to your department.');
      }

      // Department-owned Room: work_requests.department_id = room.department_id
      payload['department_id'] = room.departmentId;

      final deptId = room.departmentId;
      final dept = await DepartmentService.fetchById(deptId);
      if (dept != null) {
        if (dept.headUserId != null &&
            dept.headUserId!.isNotEmpty &&
            dept.headUserId == request.requestorId) {
          isHead = true;
        } else {
          resolvedDeptHeadId = dept.headUserId ??
              await DepartmentService.fetchDepartmentHeadUserId(deptId);
        }
      }

      if (isHead) {
        payload['dept_head_status'] = 'not_applicable';
        payload['dept_head_id'] = null;
        payload['status'] = 'Pending';
      } else {
        if (resolvedDeptHeadId == null || resolvedDeptHeadId.isEmpty) {
          throw Exception(
            'No active Department Head assigned to ${dept?.name ?? "this department"}. Please contact the administrator before submitting.',
          );
        }
        payload['dept_head_id'] = resolvedDeptHeadId;
        payload['dept_head_status'] = 'pending';
        // 'Pending' satisfies all database check constraints while dept_head_status='pending' routes to Dept Head
        payload['status'] = 'Pending';
      }
    } else {
      // Case 2: Department-less Room (Comfort Room, Lobby, Hallway, Common Area)
      // Requestor -> Room -> Campus Admin directly -> Maintenance
      // DO NOT route through requestor's Department Head.
      // work_requests.department_id = NULL, work_requests.dept_head_id = NULL
      payload['department_id'] = null;
      payload['dept_head_id'] = null;
      payload['dept_head_status'] = 'not_applicable';
      payload['status'] = 'Pending';
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

    // Trigger notification: Dept Head ONLY if awaiting Dept Head review, Campus Admin ONLY if common/bypassed
    if (!isHead && resolvedDeptHeadId != null && resolvedDeptHeadId.isNotEmpty) {
      try {
        await AppNotificationService.notifyDeptHeadNewRequest(
          deptHeadUserId: resolvedDeptHeadId,
          workRequestId: data['id']?.toString() ?? payload['id'],
          requestTitle: request.title,
          requestorName: request.requestorName,
          departmentName: request.departmentName ?? 'Department',
        );
      } catch (_) {}
    } else {
      try {
        await AppNotificationService.notifyWorkRequestSubmitted(
          workRequestId: data['id']?.toString() ?? payload['id'],
          roomName: request.roomName ?? (room?.name ?? ''),
          buildingName: request.buildingName ?? '',
          requestorName: request.requestorName,
          requestorId: request.requestorId,
        );
      } catch (_) {}
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
        if (error.message.contains('work_requests_status_check')) {
          if (sanitizedPayload['status'] != 'Pending') {
            sanitizedPayload['status'] = 'Pending';
            continue;
          }
        }
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
        if (error.message.contains('work_requests_status_check')) {
          if (sanitizedPayload['status'] == 'Pending Department Head' ||
              sanitizedPayload['status'] == 'Pending Campus Admin') {
            sanitizedPayload['status'] = 'Pending';
            continue;
          }
          if (sanitizedPayload['status'] == 'Acknowledged') {
            sanitizedPayload['status'] = 'Completed';
            continue;
          }
          if (sanitizedPayload['status'] == 'Cancelled') {
            sanitizedPayload['status'] = 'Declined';
            continue;
          }
        }
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
