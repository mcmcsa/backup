
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';
import '../services/room_type_service.dart';
import 'admin_audit_log_service.dart';
import 'work_request_service.dart';
import 'app_notification_service.dart';

class RoomService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'rooms';

  static const String _selectWithJoins = '*, buildings(name), departments(name), room_types(name)';

  static Future<List<Room>> _mapRooms(List<dynamic> data) async {
    final roomTypes = await RoomTypeService.fetchAll();
    final roomTypeNames = {
      for (final roomType in roomTypes) roomType.id: roomType.name,
    };

    return data.map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      final roomTypeId = row['room_type_id']?.toString() ?? '';
      final roomTypeName = roomTypeNames[roomTypeId] ?? row['room_type'] ?? '';

      if (roomTypeName.isNotEmpty) {
        row['room_types'] = {'name': roomTypeName};
      }

      return Room.fromMap(row);
    }).toList();
  }

  static Future<List<Room>> fetchAll() async {
    final data = await _db.from(_table).select(_selectWithJoins).order('name', ascending: true);
    return _mapRooms(data as List);
  }

  static Future<List<Room>> fetchByBuilding(String buildingId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('building_id', buildingId)
        .order('name', ascending: true);
    return _mapRooms(data as List);
  }

  static Future<List<Room>> fetchByDepartment(String departmentId) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('department_id', departmentId)
        .order('name', ascending: true);
    return _mapRooms(data as List);
  }

  static Future<List<Room>> fetchByStatus(String status) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('status', status)
        .order('name', ascending: true);
    return _mapRooms(data as List);
  }

  static Future<Room?> fetchById(String id) async {
    final data = await _db.from(_table).select(_selectWithJoins).eq('id', id).maybeSingle();
    if (data == null) return null;
    final list = await _mapRooms([data]);
    return list.isNotEmpty ? list.first : null;
  }

  static Future<Room?> fetchByCode(String code) async {
    final data = await _db.from(_table).select(_selectWithJoins).eq('code', code).maybeSingle();
    if (data == null) return null;
    final list = await _mapRooms([data]);
    return list.isNotEmpty ? list.first : null;
  }

  static Future<Room?> fetchByQrCode(String qrCodeData) async {
    final data = await _db.from(_table).select(_selectWithJoins).eq('qr_code_data', qrCodeData).maybeSingle();
    if (data == null) return null;
    final list = await _mapRooms([data]);
    return list.isNotEmpty ? list.first : null;
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

  // Legacy insert
  static Future<void> insert(Room room) async {
    await _db.from(_table).insert(room.toMap());
    await AdminAuditLogService.logAction(
      title: 'Added Room',
      details: 'Room: ${room.name} (${room.id})',
    );
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

      await _db.from(_table).update({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'building_id': buildingId.isNotEmpty ? buildingId : null,
        'department_id': departmentId.isNotEmpty ? departmentId : null,
        'room_type_id': roomTypeId.isNotEmpty ? roomTypeId : null,
        'seats': seats,
        'floor': floor.trim(),
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

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
