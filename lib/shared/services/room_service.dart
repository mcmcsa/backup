import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';
import '../services/room_type_service.dart';
import 'admin_audit_log_service.dart';

class RoomService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const String _table = 'rooms';

  static const String _selectWithJoins = '*, buildings(name), departments(name)';

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

  static Future<List<Room>> fetchByRoomType(String roomType) async {
    try {
      final data = await _db
          .from(_table)
          .select(_selectWithJoins)
          .eq('room_type_id', roomType)
          .order('name', ascending: true);
      return _mapRooms(data as List);
    } on PostgrestException catch (e) {
      if (!_isMissingColumnError(e, 'room_type_id')) rethrow;
      final rooms = await fetchAll();
      final normalized = roomType.trim().toLowerCase();
      return rooms
          .where(
            (r) =>
                r.roomTypeId.toLowerCase() == normalized ||
                r.roomType.toLowerCase() == normalized,
          )
          .toList();
    }
  }

  static Future<List<Room>> fetchAvailable() async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('status', 'available')
        .order('name', ascending: true);
    return _mapRooms(data as List);
  }

  static Future<Room?> fetchById(String id) async {
    if (!_looksLikeUuid(id)) return null;

    final data = await _db.from(_table).select(_selectWithJoins).eq('id', id).maybeSingle();
    if (data == null) return null;
    return (await _mapRooms([data])).first;
  }

  static Future<Room?> fetchByQRCode(String qrCodeData) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .eq('qr_code_data', qrCodeData)
        .maybeSingle();
    if (data == null) return null;
    return (await _mapRooms([data])).first;
  }

  static Future<Room?> fetchByScanValue(String scanValue) async {
    final normalized = scanValue.trim();
    if (normalized.isEmpty) return null;

    final byQr = await fetchByQRCode(normalized);
    if (byQr != null) return byQr;

    final qrPayload = _tryParseQrPayload(normalized);
    final payloadRoomCode =
        qrPayload['room_code'] ?? qrPayload['code'] ?? qrPayload['roomId'];
    if (payloadRoomCode != null && payloadRoomCode.trim().isNotEmpty) {
      final byPayloadCode = await fetchByIdOrRoomNumber(payloadRoomCode);
      if (byPayloadCode != null) return byPayloadCode;
    }

    final byIdOrCode = await fetchByIdOrRoomNumber(normalized);
    if (byIdOrCode != null) return byIdOrCode;

    final loweredScan = normalized.toLowerCase();
    final rooms = await fetchAll();

    for (final room in rooms) {
      final roomCode = room.code.trim().toLowerCase();
      if (roomCode.isNotEmpty && loweredScan.contains(roomCode)) {
        return room;
      }
    }

    return null;
  }

  static String buildQrCodePayload({
    required String roomCode,
    required String roomName,
    required String buildingName,
    required String departmentName,
    required String floor,
    required String roomType,
    required String status,
  }) {
    return jsonEncode({
      'type': 'psu_room',
      'room_code': roomCode.trim(),
      'room_name': roomName.trim(),
      'building_name': buildingName.trim(),
      'department_name': departmentName.trim(),
      'floor': floor.trim(),
      'room_type': roomType.trim(),
      'status': status.trim(),
    });
  }

  static Future<void> updateStatus(String id, String status) async {
    await _db.from(_table).update({'status': status}).eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Updated Room Status',
      details: 'Room ID: $id, Status: $status',
    );
  }

  static Future<void> insert(Room room) async {
    await _insertWithLegacyFallback(room.toMap());
    final roomReference = room.code.isNotEmpty ? room.code : room.id;
    await AdminAuditLogService.logAction(
      title: 'Added Room',
      details: 'Room: ${room.name} ($roomReference)',
    );
  }

  static Future<void> update(Room room) async {
    await _updateWithLegacyFallback(room.toMap(), room.id);
    final roomReference = room.code.isNotEmpty ? room.code : room.id;
    await AdminAuditLogService.logAction(
      title: 'Updated Room',
      details: 'Room: ${room.name} ($roomReference)',
    );
  }

  static Future<Room?> fetchByName(String name) async {
    final data = await _db
        .from(_table)
        .select(_selectWithJoins)
        .ilike('name', name)
        .maybeSingle();
    if (data == null) return null;
    return (await _mapRooms([data])).first;
  }

  static Future<Room?> fetchByCode(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return null;

    try {
      final data = await _db
          .from(_table)
          .select(_selectWithJoins)
          .eq('code', normalized)
          .maybeSingle();
      if (data == null) return null;
      return (await _mapRooms([data])).first;
    } on PostgrestException catch (e) {
      if (!_isMissingColumnError(e, 'code')) rethrow;
      // Older schemas may not have a dedicated code column.
      return fetchById(normalized);
    }
  }

  static Future<Room?> fetchByIdOrRoomNumber(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    if (_looksLikeUuid(normalized)) {
      final byId = await fetchById(normalized);
      if (byId != null) return byId;
    }

    return fetchByCode(normalized);
  }

  static Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
    await AdminAuditLogService.logAction(
      title: 'Deleted Room',
      details: 'Room ID: $id',
    );
  }

  /// Returns the next auto-incremented room ID in the format RM0001, RM0002, …
  static Future<String> generateNextCode() async {
    final data = await _db.from(_table).select('code');
    int maxNum = 0;
    final regex = RegExp(r'^RM(\d+)$', caseSensitive: false);
    for (final row in (data as List)) {
      final match = regex.firstMatch(row['code']?.toString() ?? '');
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'RM${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  /// Legacy wrapper kept for compatibility with existing UI callsites.
  static Future<String> generateNextId() async {
    return generateNextCode();
  }

  // Analytics methods
  static Future<int> getTotalRooms() async {
    final data = await _db.from(_table).select('id');
    return (data as List).length;
  }

  static Future<int> getAvailableCount() async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('status', 'available');
    return (data as List).length;
  }

  static Future<int> getMaintenanceCount() async {
    final data = await _db
        .from(_table)
        .select('id')
        .eq('status', 'maintenance');
    return (data as List).length;
  }

  static bool _isMissingColumnError(PostgrestException error, String column) {
    final text = '${error.message} ${error.details} ${error.hint}'.toLowerCase();
    return text.contains("could not find the '$column' column") ||
        text.contains("column '$column'") ||
        text.contains('column $column');
  }

  static bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  static Future<void> _insertWithLegacyFallback(Map<String, dynamic> payload) async {
    final mutable = Map<String, dynamic>.from(payload);
    while (true) {
      try {
        await _db.from(_table).insert(mutable);
        return;
      } on PostgrestException catch (e) {
        final missingColumn = _extractMissingColumn(e);
        if (missingColumn == null || !mutable.containsKey(missingColumn)) rethrow;
        mutable.remove(missingColumn);
      }
    }
  }

  static Future<void> _updateWithLegacyFallback(
    Map<String, dynamic> payload,
    String roomId,
  ) async {
    final mutable = Map<String, dynamic>.from(payload);
    while (true) {
      try {
        await _db.from(_table).update(mutable).eq('id', roomId);
        return;
      } on PostgrestException catch (e) {
        final missingColumn = _extractMissingColumn(e);
        if (missingColumn == null || !mutable.containsKey(missingColumn)) rethrow;
        mutable.remove(missingColumn);
      }
    }
  }

  static String? _extractMissingColumn(PostgrestException error) {
    final text = '${error.message} ${error.details} ${error.hint}';
    final quotedPattern = RegExp(r"'([a-zA-Z0-9_]+)'\\s+column", caseSensitive: false);
    final quoted = quotedPattern.firstMatch(text);
    if (quoted != null) return quoted.group(1)?.toLowerCase();

    final plainPattern = RegExp(r'column\\s+([a-zA-Z0-9_]+)', caseSensitive: false);
    final plain = plainPattern.firstMatch(text);
    return plain?.group(1)?.toLowerCase();
  }

  static Map<String, String> _tryParseQrPayload(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return const {};

      return decoded.map(
        (key, val) => MapEntry(
          key.toString(),
          val?.toString().trim() ?? '',
        ),
      );
    } catch (_) {
      return const {};
    }
  }
}
