
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/building_model.dart';
import '../models/department_model.dart';
import '../models/floor_model.dart';
import '../models/room_model.dart';
import '../models/room_type_model.dart';
import 'building_service.dart';
import 'department_service.dart';
import '../services/room_type_service.dart';
import '../services/floor_service.dart';
import 'admin_audit_log_service.dart';
import 'work_request_service.dart';
import 'app_notification_service.dart';
import 'qr_code_history_service.dart';

class RoomService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'rooms';
  static const Uuid _uuid = Uuid();

  static Future<String?> uploadRoomImageBytes(Uint8List bytes, String fileName) async {
    try {
      final rawExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
      final mimeType = (rawExt == 'png')
          ? 'image/png'
          : (rawExt == 'webp')
              ? 'image/webp'
              : (rawExt == 'gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      final fileExt = (rawExt == 'jpeg' || rawExt == 'jpg') ? 'jpg' : rawExt;
      final path = 'rooms/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.$fileExt';

      final buckets = [
        'room-images',
        'work-request-attachments',
        'work-evidence',
        'profile-images',
        'chat-attachments',
      ];

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
          debugPrint('Successfully uploaded room image to bucket "$bucket": $url');
          return url;
        } catch (e) {
          debugPrint('Upload room image to bucket "$bucket" failed: $e');
        }
      }

      // Ultimate resilient fallback if storage buckets fail: Base64 data URI
      try {
        final base64String = base64Encode(bytes);
        final dataUri = 'data:$mimeType;base64,$base64String';
        debugPrint('Room image saved as resilient data URI (length: ${dataUri.length})');
        return dataUri;
      } catch (e) {
        debugPrint('Failed base64 fallback conversion: $e');
      }
    } catch (e) {
      debugPrint('Error uploading room image: $e');
    }
    return null;
  }

  static const String _selectWithJoins = '*, buildings(name), departments(name), room_types(name)';

  static Future<List<dynamic>> _safeSelectRooms({
    String? filterColumn,
    dynamic filterValue,
    String? ilikeColumn,
    String? ilikeValue,
    bool ascending = true,
  }) async {
    // 1. Try joined query
    try {
      var query = _db.from(_table).select(_selectWithJoins);
      if (filterColumn != null && filterValue != null) {
        query = query.eq(filterColumn, filterValue);
      }
      if (ilikeColumn != null && ilikeValue != null) {
        query = query.ilike(ilikeColumn, ilikeValue);
      }
      final res = await query.order('name', ascending: ascending);
      return res as List<dynamic>;
    } catch (e) {
      debugPrint('RoomService: _selectWithJoins failed: $e. Retrying direct select...');
    }

    // 2. Try direct select with order
    try {
      var query = _db.from(_table).select();
      if (filterColumn != null && filterValue != null) {
        query = query.eq(filterColumn, filterValue);
      }
      if (ilikeColumn != null && ilikeValue != null) {
        query = query.ilike(ilikeColumn, ilikeValue);
      }
      final res = await query.order('name', ascending: ascending);
      return res as List<dynamic>;
    } catch (e) {
      debugPrint('RoomService: direct select with order failed: $e. Retrying plain select...');
    }

    // 3. Fallback direct select without order
    try {
      var query = _db.from(_table).select();
      if (filterColumn != null && filterValue != null) {
        query = query.eq(filterColumn, filterValue);
      }
      if (ilikeColumn != null && ilikeValue != null) {
        query = query.ilike(ilikeColumn, ilikeValue);
      }
      final res = await query;
      return res as List<dynamic>;
    } catch (e) {
      debugPrint('RoomService: plain select failed: $e');
      return [];
    }
  }

  static Future<List<Room>> _mapRooms(List<dynamic> data) async {
    if (data.isEmpty) return [];

    final roomTypesFuture = RoomTypeService.fetchAll().catchError((_) => <RoomType>[]);
    final floorsFuture = FloorService.fetchAll().catchError((_) => <Floor>[]);
    final buildingsFuture = BuildingService.fetchAll().catchError((_) => <Building>[]);
    final departmentsFuture = DepartmentService.fetchAll().catchError((_) => <Department>[]);

    final results = await Future.wait([
      roomTypesFuture,
      floorsFuture,
      buildingsFuture,
      departmentsFuture,
    ]);

    final roomTypes = (results[0] as List).cast<RoomType>();
    final floors = (results[1] as List).cast<Floor>();
    final buildings = (results[2] as List).cast<Building>();
    final departments = (results[3] as List).cast<Department>();

    final roomTypeNames = {for (final rt in roomTypes) rt.id: rt.name};
    final floorNames = {for (final f in floors) f.id: f.name};
    final buildingNames = {for (final b in buildings) b.id: b.name};
    final departmentNames = {for (final d in departments) d.id: d.name};

    return data.map((e) {
      try {
        final row = Map<String, dynamic>.from(e as Map);
        final roomTypeId = row['room_type_id']?.toString() ?? '';
        final roomTypeName = roomTypeNames[roomTypeId] ?? row['room_type'] ?? '';

        if (roomTypeName.isNotEmpty) {
          row['room_types'] = {'name': roomTypeName};
          row['room_type'] = roomTypeName;
        }

        final floorId = row['floor_id']?.toString() ?? '';
        final floorName = floorNames[floorId] ?? row['floor'] ?? row['floor_snapshot'] ?? '';
        if (floorName.isNotEmpty) {
          row['floors'] = {'name': floorName};
          row['floor'] = floorName;
        }

        final bldgId = row['building_id']?.toString() ?? '';
        String bldgName = '';
        if (row['buildings'] is Map) {
          bldgName = row['buildings']['name']?.toString() ?? '';
        }
        if (bldgName.isEmpty && bldgId.isNotEmpty) {
          bldgName = buildingNames[bldgId] ?? '';
        }
        if (bldgName.isNotEmpty) {
          row['buildings'] = {'name': bldgName};
          row['building'] = bldgName;
        }

        final deptId = row['department_id']?.toString() ?? '';
        String deptName = '';
        if (row['departments'] is Map) {
          deptName = row['departments']['name']?.toString() ?? '';
        }
        if (deptName.isEmpty && deptId.isNotEmpty) {
          deptName = departmentNames[deptId] ?? '';
        }
        if (deptName.isNotEmpty) {
          row['departments'] = {'name': deptName};
          row['department'] = deptName;
          row['department_name'] = deptName;
        }

        return Room.fromMap(row);
      } catch (err) {
        debugPrint('Error mapping room row: $err');
        return Room.fromMap(Map<String, dynamic>.from(e as Map));
      }
    }).toList();
  }

  static Future<List<Room>> fetchAll() async {
    final list = await _safeSelectRooms();
    return _mapRooms(list);
  }

  static Future<List<Room>> fetchByBuilding(String buildingId) async {
    final list = await _safeSelectRooms(filterColumn: 'building_id', filterValue: buildingId);
    return _mapRooms(list);
  }

  static Future<List<Room>> fetchByDepartment(String departmentId) async {
    final list = await _safeSelectRooms(filterColumn: 'department_id', filterValue: departmentId);
    return _mapRooms(list);
  }

  static Future<List<Room>> fetchByStatus(String status) async {
    final list = await _safeSelectRooms(filterColumn: 'status', filterValue: status);
    return _mapRooms(list);
  }

  static Future<Room?> fetchById(String id) async {
    final list = await _safeSelectRooms(filterColumn: 'id', filterValue: id);
    if (list.isEmpty) return null;
    final mapped = await _mapRooms(list);
    return mapped.isNotEmpty ? mapped.first : null;
  }

  static Future<Room?> fetchByCode(String code) async {
    final list = await _safeSelectRooms(filterColumn: 'code', filterValue: code);
    if (list.isEmpty) return null;
    final mapped = await _mapRooms(list);
    return mapped.isNotEmpty ? mapped.first : null;
  }

  static Future<Room?> fetchByQrCode(String qrCodeData) async {
    final list = await _safeSelectRooms(filterColumn: 'qr_code_data', filterValue: qrCodeData);
    if (list.isEmpty) return null;
    final mapped = await _mapRooms(list);
    return mapped.isNotEmpty ? mapped.first : null;
  }

  /// Find a room by scanned QR code data, room code, or room ID (case-insensitive).
  /// Handles prefixes like 'ROOM:' and matches against official rooms created in system.
  static Future<Room?> findRoomByScannedCode(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty) return null;

    String cleanCode = input;
    if (input.toUpperCase().startsWith('ROOM:')) {
      cleanCode = input.substring(5).trim();
    }

    Room? foundRoom;
    try {
      final byQrData = await _db
          .from(_table)
          .select(_selectWithJoins)
          .ilike('qr_code_data', input)
          .maybeSingle();
      if (byQrData != null) {
        final list = await _mapRooms([byQrData]);
        if (list.isNotEmpty) foundRoom = list.first;
      }
    } catch (_) {}

    if (foundRoom == null) {
      try {
        final byQrFormatted = await _db
            .from(_table)
            .select(_selectWithJoins)
            .ilike('qr_code_data', 'ROOM:$cleanCode')
            .maybeSingle();
        if (byQrFormatted != null) {
          final list = await _mapRooms([byQrFormatted]);
          if (list.isNotEmpty) foundRoom = list.first;
        }
      } catch (_) {}
    }

    if (foundRoom == null) {
      try {
        final byCode = await _db
            .from(_table)
            .select(_selectWithJoins)
            .ilike('code', cleanCode)
            .maybeSingle();
        if (byCode != null) {
          final list = await _mapRooms([byCode]);
          if (list.isNotEmpty) foundRoom = list.first;
        }
      } catch (_) {}
    }

    if (foundRoom == null) {
      try {
        final byCodeRaw = await _db
            .from(_table)
            .select(_selectWithJoins)
            .ilike('code', input)
            .maybeSingle();
        if (byCodeRaw != null) {
          final list = await _mapRooms([byCodeRaw]);
          if (list.isNotEmpty) foundRoom = list.first;
        }
      } catch (_) {}
    }

    if (foundRoom == null) {
      try {
        final byId = await fetchById(cleanCode) ?? await fetchById(input);
        if (byId != null) foundRoom = byId;
      } catch (_) {}
    }

    if (foundRoom != null) {
      // Record scan in qr_code_history
      QRCodeHistoryService.recordScanForRoom(foundRoom.id);
    }

    return foundRoom;
  }

  // ─── Create ──────────────────────────────────────────────────────────────

  static Future<String?> create({
    required String name,
    required String code,
    required String buildingId,
    required String departmentId,
    required String roomTypeId,
    required int seats,
    required String floor,
    required String status,
    String? imageUrl,
  }) async {
    try {
      final existingCode = await _db
          .from(_table)
          .select('id')
          .ilike('code', code.trim())
          .maybeSingle();
      if (existingCode != null) return 'A room with number/code "$code" already exists.';

      final now = DateTime.now().toIso8601String();
      await _db.from(_table).insert({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'building_id': buildingId.isNotEmpty ? buildingId : null,
        'department_id': departmentId.isNotEmpty ? departmentId : null,
        'room_type_id': roomTypeId.isNotEmpty ? roomTypeId : null,
        'seats': seats,
        'floor': floor.trim(),
        'status': status,
        'image_url': imageUrl?.trim().isNotEmpty == true ? imageUrl!.trim() : null,
        'created_at': now,
        'updated_at': now,
      });

      await AdminAuditLogService.logAction(
        title: 'Added Room',
        details: 'Room: $name ($code)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Insert room and return newly created Room record
  static Future<Room> insert(Room room) async {
    final payload = Map<String, dynamic>.from(room.toMap());

    // Clean up empty string UUID keys so PostgREST won't fail with uuid syntax error
    if (payload['id'] == '' || payload['id'] == null) {
      payload.remove('id');
    }
    if (payload['department_id'] == '') {
      payload.remove('department_id');
    }
    if (payload['floor_id'] == '') {
      payload.remove('floor_id');
    }
    if (payload['room_type_id'] == '') {
      payload.remove('room_type_id');
    }
    if (payload['building_id'] == '') {
      payload.remove('building_id');
    }

    final code = (payload['code'] ?? '').toString().trim();
    if (code.isEmpty) {
      payload['code'] = 'RM-${DateTime.now().millisecondsSinceEpoch % 100000}';
    } else {
      payload['code'] = code.toUpperCase();
    }

    final now = DateTime.now().toIso8601String();
    payload['created_at'] ??= now;
    payload['updated_at'] ??= now;

    Map<String, dynamic> insertedRow;

    try {
      final res = await _db.from(_table).insert(payload).select().single();
      insertedRow = Map<String, dynamic>.from(res);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('floor') && msg.contains('does not exist')) {
        payload.remove('floor');
        final res = await _db.from(_table).insert(payload).select().single();
        insertedRow = Map<String, dynamic>.from(res);
      } else {
        rethrow;
      }
    }

    await AdminAuditLogService.logAction(
      title: 'Added Room',
      details: 'Room: ${room.name} (${insertedRow['code'] ?? insertedRow['id']})',
    ).catchError((_) {});

    final mappedList = await _mapRooms([insertedRow]);
    return mappedList.isNotEmpty ? mappedList.first : Room.fromMap(insertedRow);
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  static Future<void> logRoomVersion(String roomId, Room? oldRoom) async {
    try {
      final updatedRoom = await fetchById(roomId);
      if (updatedRoom == null) return;

      final versionCountRes = await _db.from('room_versions').select('id').eq('room_id', roomId);
      final currentVersionCount = (versionCountRes as List).length;

      if (currentVersionCount == 0 && oldRoom != null) {
        // Log original version (v1)
        await _db.from('room_versions').insert({
          'room_id': roomId,
          'version': 1,
          'room_data': oldRoom.toMap(),
          'created_at': oldRoom.updatedAt?.toIso8601String() ?? oldRoom.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        });
        
        // Log the new version (v2)
        final currentUser = _db.auth.currentUser;
        await _db.from('room_versions').insert({
          'room_id': roomId,
          'version': 2,
          'room_data': updatedRoom.toMap(),
          'edited_by': currentUser?.id,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Log subsequent version (vN)
        final nextVersion = currentVersionCount == 0 ? 2 : currentVersionCount + 1;
        final currentUser = _db.auth.currentUser;
        await _db.from('room_versions').insert({
          'room_id': roomId,
          'version': nextVersion,
          'room_data': updatedRoom.toMap(),
          'edited_by': currentUser?.id,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  static Future<String?> updateRoom({
    required String id,
    required String name,
    required String code,
    required String buildingId,
    required String departmentId,
    required String roomTypeId,
    required int seats,
    required String floor,
    required String status,
    required List<Room> allRooms,
    String? imageUrl,
    bool updateImage = false,
  }) async {
    try {
      final duplicateCode = allRooms.any(
        (r) => r.id != id && r.code.trim().toLowerCase() == code.trim().toLowerCase(),
      );
      if (duplicateCode) return 'A room with number/code "$code" already exists.';

      // Guard: Block editing if there is an active work request
      final hasActive = await WorkRequestService.hasActiveRequestForRoom(id);
      if (hasActive) {
        return 'This room cannot be edited while it has an ongoing work request.';
      }

      final oldRoom = await fetchById(id);

      final updateData = <String, dynamic>{
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'building_id': buildingId.isNotEmpty ? buildingId : null,
        'department_id': departmentId.isNotEmpty ? departmentId : null,
        'room_type_id': roomTypeId.isNotEmpty ? roomTypeId : null,
        'seats': seats,
        'floor': floor.trim(),
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (updateImage) {
        updateData['image_url'] = imageUrl?.trim().isNotEmpty == true ? imageUrl!.trim() : null;
      }

      await _db.from(_table).update(updateData).eq('id', id);

      await AdminAuditLogService.logAction(
        title: 'Updated Room',
        details: 'Room: $name ($code)',
      );

      // Log version
      await logRoomVersion(id, oldRoom);

      // Fetch resolved requests for historical reports on this room
      final historicalRequests = await WorkRequestService.fetchByRoom(id);
      final resolvedRequests = historicalRequests.where((req) {
        final statusLower = req.status.toLowerCase();
        return statusLower == 'completed' || statusLower == 'declined';
      }).toList();

      // Notify Campus Admin
      await AppNotificationService.createForRole(
        targetRole: 'campadmin',
        title: 'Room Updated',
        message: 'Room $code was updated again by System Admin — tap to view what changed.',
        type: 'room_edit',
        targetPage: 'room_id:$id',
      );

      // Notify Requestors and Maintenance Technicians per report
      for (final req in resolvedRequests) {
        if (req.requestorId != null && req.requestorId!.isNotEmpty) {
          await AppNotificationService.createForUser(
            targetUserId: req.requestorId!,
            title: 'Room Updated',
            message: 'Room $code was updated again by System Admin — tap to view what changed.',
            type: 'room_edit',
            workRequestId: req.id,
            targetPage: 'room_id:$id',
          );
        }
        if (req.assignedToId != null && req.assignedToId!.isNotEmpty) {
          await AppNotificationService.createForUser(
            targetUserId: req.assignedToId!,
            title: 'Room Updated',
            message: 'Room $code was updated again by System Admin — tap to view what changed.',
            type: 'room_edit',
            workRequestId: req.id,
            targetPage: 'room_id:$id',
          );
        }
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Legacy update
  static Future<void> update(Room room) async {
    final oldRoom = await fetchById(room.id);
    await _db.from(_table).update(room.toMap()).eq('id', room.id);
    await AdminAuditLogService.logAction(
      title: 'Updated Room',
      details: 'Room: ${room.name} (${room.id})',
    );
    await logRoomVersion(room.id, oldRoom);
  }

  static Future<void> updateStatus(String id, String status) async {
    await _db.from(_table).update({'status': status}).eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Updated Room Status',
      details: 'Room ID: $id, Status: $status',
    );
  }

  static Future<void> updateQrCode(String id, String qrCodeData) async {
    await _db.from(_table).update({'qr_code_data': qrCodeData}).eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Updated Room QR Code',
      details: 'Room ID: $id',
    );
  }

  // ─── Delete ──────────────────────────────────────────────────────────────

  static Future<String?> deleteRoom(String id, String name) async {
    try {
      await _db.from(_table).delete().eq('id', id);
      await AdminAuditLogService.logAction(
        title: 'Deleted Room',
        details: 'Room: $name (ID: $id)',
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
      title: 'Deleted Room',
      details: 'Room ID: $id',
    );
  }

  static Future<Room> findOrCreateByName(String name, {String? buildingId}) async {
    final query = _db.from(_table).select(_selectWithJoins).ilike('name', name);
    if (buildingId != null && buildingId.isNotEmpty) {
      query.eq('building_id', buildingId);
    }
    final data = await query.maybeSingle();

    if (data != null) {
      final list = await _mapRooms([data]);
      if (list.isNotEmpty) return list.first;
    }

    final now = DateTime.now();
    final newRoom = {
      'name': name,
      'code': name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''),
      if (buildingId != null && buildingId.isNotEmpty) 'building_id': buildingId,
      'seats': 0,
      'floor': '1',
      'status': 'available',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    final inserted = await _db.from(_table).insert(newRoom).select().single();
    await AdminAuditLogService.logAction(
      title: 'Created Room Automatically',
      details: 'Room: $name',
    );
    final list = await _mapRooms([inserted]);
    return list.first;
  }

  static RealtimeChannel listenToAllRooms(
    Function(List<Room>) onUpdate,
  ) {
    final channel = _db.realtime.channel('realtime:rooms');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) async {
            try {
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
}
