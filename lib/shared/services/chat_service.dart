import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import 'app_notification_service.dart';

class ChatService {
  static SupabaseClient get _db => Supabase.instance.client;

  // ──────────────────────────────────────────────────
  // ROOMS
  // ──────────────────────────────────────────────────

  /// Fetch all rooms the current user participates in.
  static Future<List<ChatRoom>> fetchRooms(String userId) async {
    final deletedIds = await getDeletedRoomIds(userId);
    final response = await _db
        .from('chat_rooms')
        .select('''
          *,
          chat_participants!inner(
            id, room_id, user_id, role, joined_at, last_read_at,
            users(name, email, profile_image)
          )
        ''')
        .order('updated_at', ascending: false);

    final rawRooms = (response as List)
        .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
        .where((r) => r.participants.any((p) => p.userId == userId))
        .toList();

    final List<ChatRoom> visibleRooms = [];
    for (final r in rawRooms) {
      final clearedAt = await getClearedAt(userId, r.id);
      final isMarkedDeleted = deletedIds.contains(r.id);

      if (clearedAt != null) {
        final hasNewMessageAfterClear =
            r.lastMessageAt != null && r.lastMessageAt!.isAfter(clearedAt);

        if (isMarkedDeleted && !hasNewMessageAfterClear) {
          continue; // Room remains deleted/hidden for this user
        }

        if (isMarkedDeleted && hasNewMessageAfterClear) {
          // A new message arrived after deletion! Restore room so user can see it
          await restoreDeletedRoom(userId, r.id);
        }

        if (!hasNewMessageAfterClear) {
          // Room is opened/visible, but past messages are deleted: hide old preview
          visibleRooms.add(ChatRoom(
            id: r.id,
            name: r.name,
            type: r.type,
            workRequestId: r.workRequestId,
            createdBy: r.createdBy,
            lastMessage: null,
            lastMessageAt: null,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            participants: r.participants,
          ));
          continue;
        }
      } else if (isMarkedDeleted) {
        continue;
      }

      visibleRooms.add(r);
    }

    return visibleRooms;
  }

  // ──────────────────────────────────────────────────
  // ARCHIVE & DELETE CONVERSATIONS
  // ──────────────────────────────────────────────────

  static String _archivedKey(String userId) => 'chat_archived_rooms_$userId';
  static String _deletedKey(String userId) => 'chat_deleted_rooms_$userId';
  static String _clearedKey(String userId, String roomId) =>
      'chat_cleared_at_${userId}_$roomId';

  /// Get list of archived room IDs for user
  static Future<Set<String>> getArchivedRoomIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_archivedKey(userId)) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Check if room is archived
  static Future<bool> isRoomArchived(String userId, String roomId) async {
    final set = await getArchivedRoomIds(userId);
    return set.contains(roomId);
  }

  /// Archive or Unarchive a room for user
  static Future<void> setRoomArchived(String userId, String roomId, bool archive) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = (prefs.getStringList(_archivedKey(userId)) ?? []).toSet();
      if (archive) {
        set.add(roomId);
      } else {
        set.remove(roomId);
      }
      await prefs.setStringList(_archivedKey(userId), set.toList());
    } catch (_) {}
  }

  /// Get list of deleted room IDs for user
  static Future<Set<String>> getDeletedRoomIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_deletedKey(userId)) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Restore room from deleted set
  static Future<void> restoreDeletedRoom(String userId, String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = (prefs.getStringList(_deletedKey(userId)) ?? []).toSet();
      if (set.contains(roomId)) {
        set.remove(roomId);
        await prefs.setStringList(_deletedKey(userId), set.toList());
      }
    } catch (_) {}
  }

  /// Get the timestamp at which user deleted/cleared their chat history in this room
  static Future<DateTime?> getClearedAt(String userId, String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_clearedKey(userId, roomId));
      if (str != null && str.isNotEmpty) {
        return DateTime.tryParse(str);
      }
      // Check Supabase user_metadata as fallback
      final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
      if (meta != null && meta['chat_cleared_rooms'] is Map) {
        final map = meta['chat_cleared_rooms'] as Map;
        final iso = map[roomId] as String?;
        if (iso != null) {
          final dt = DateTime.tryParse(iso);
          if (dt != null) {
            await prefs.setString(_clearedKey(userId, roomId), iso);
            return dt;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Set the timestamp at which user deleted/cleared their chat history in this room
  static Future<void> setClearedAt(
      String userId, String roomId, DateTime timestamp) async {
    final iso = timestamp.toUtc().toIso8601String();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clearedKey(userId, roomId), iso);
    } catch (_) {}

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.id == userId) {
        final currentMeta = Map<String, dynamic>.from(user.userMetadata ?? {});
        final clearedMap =
            Map<String, dynamic>.from(currentMeta['chat_cleared_rooms'] as Map? ?? {});
        clearedMap[roomId] = iso;
        currentMeta['chat_cleared_rooms'] = clearedMap;
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: currentMeta),
        );
      }
    } catch (_) {}
  }

  /// Delete a conversation for the current user.
  /// NOTE: Clears all messages ("usapan") ONLY for this [userId].
  /// The other participant keeps their messages and conversation intact.
  static Future<bool> deleteConversation(String userId, String roomId) async {
    final now = DateTime.now();

    // 1. Record cleared timestamp so all existing messages are hidden for this user
    await setClearedAt(userId, roomId, now);

    // 2. Mark as deleted in local preferences so it disappears from the list
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = (prefs.getStringList(_deletedKey(userId)) ?? []).toSet();
      set.add(roomId);
      await prefs.setStringList(_deletedKey(userId), set.toList());

      // Also remove from archived if it was archived
      final archSet = (prefs.getStringList(_archivedKey(userId)) ?? []).toSet();
      if (archSet.contains(roomId)) {
        archSet.remove(roomId);
        await prefs.setStringList(_archivedKey(userId), archSet.toList());
      }
    } catch (_) {}

    // 3. Mark read to clear notifications and badges
    try {
      await markRead(roomId, userId);
    } catch (_) {}

    return true;
  }

  /// Fetch a single room by id.
  static Future<ChatRoom?> fetchRoom(String roomId) async {
    final response = await _db
        .from('chat_rooms')
        .select('''
          *,
          chat_participants(
            id, room_id, user_id, role, joined_at, last_read_at,
            users(name, email, profile_image)
          )
        ''')
        .eq('id', roomId)
        .maybeSingle();

    if (response == null) return null;
    return ChatRoom.fromJson(response);
  }

  /// Find or create a direct-message room between two users.
  static Future<ChatRoom> findOrCreateDirectRoom({
    required String currentUserId,
    required String currentUserName,
    required String currentUserRole,
    required String otherUserId,
    required String otherUserName,
    required String otherUserRole,
    String? workRequestId,
  }) async {
    // Look for an existing direct room shared only between these two users
    final response = await _db.rpc('find_direct_chat_room', params: {
      'user_a': currentUserId,
      'user_b': otherUserId,
    });

    if (response != null && (response as List).isNotEmpty) {
      final existing = response.first as Map<String, dynamic>;
      final roomId = existing['id'] as String;
      // If user previously deleted this conversation, restore it to room list
      await restoreDeletedRoom(currentUserId, roomId);
      final room = await fetchRoom(roomId);
      if (room != null) return room;
    }

    // Create new room
    final roomId = const Uuid().v4();
    
    await _db.from('chat_rooms').insert({
      'id': roomId,
      'type': 'direct',
      'created_by': currentUserId,
      'work_request_id': workRequestId,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Add both participants
    await _db.from('chat_participants').insert([
      {
        'room_id': roomId,
        'user_id': currentUserId,
        'role': currentUserRole,
      },
      {
        'room_id': roomId,
        'user_id': otherUserId,
        'role': otherUserRole,
      },
    ]);

    return (await fetchRoom(roomId))!;
  }

  // ──────────────────────────────────────────────────
  // MESSAGES
  // ──────────────────────────────────────────────────

  /// Fetch the latest 50 messages in a room (paginated), respecting user's cleared history.
  static Future<List<ChatMessage>> fetchMessages(
    String roomId, {
    String? currentUserId,
    int limit = 50,
    String? before, // cursor: created_at ISO string
  }) async {
    DateTime? clearedAt;
    if (currentUserId != null) {
      clearedAt = await getClearedAt(currentUserId, roomId);
    }

    var query = _db.from('chat_messages').select().eq('room_id', roomId);

    if (clearedAt != null) {
      query = query.gt('created_at', clearedAt.toIso8601String());
    }

    if (before != null) {
      query = query.lt('created_at', before);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    var list = (response as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();

    if (clearedAt != null) {
      list = list.where((m) => m.createdAt.isAfter(clearedAt!)).toList();
    }

    return list.reversed.toList();
  }

  /// Send a text message.
  static Future<ChatMessage> sendTextMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    bool notify = true,
  }) async {
    final payload = {
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'message_type': 'text',
      'reply_to_id': replyToId,
      'reply_to_content': replyToContent,
      'reply_to_sender_name': replyToSenderName,
    };

    final response = await _db.from('chat_messages').insert(payload).select().single();
    await _updateRoomLastMessage(roomId, content, response['created_at'] as String);
    await restoreDeletedRoom(senderId, roomId);
    if (notify) {
      _sendNewMessageNotification(roomId, senderId, senderName, content);
    }
    return ChatMessage.fromJson(response);
  }

  /// Send an attachment message (image / voice / file).
  static Future<ChatMessage> sendAttachmentMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String filePath,
    required MessageType messageType,
    String? content,
    String? replyToId,
    bool notify = true,
  }) async {
    final url = await uploadAttachment(filePath, roomId);
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final typeStr = _messageTypeToString(messageType);

    final payload = {
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'message_type': typeStr,
      'attachment_url': url,
      'attachment_name': fileName,
      'reply_to_id': replyToId,
    };

    final response = await _db.from('chat_messages').insert(payload).select().single();
    final preview = _attachmentPreview(messageType, fileName);
    await _updateRoomLastMessage(
      roomId,
      preview,
      response['created_at'] as String,
    );
    await restoreDeletedRoom(senderId, roomId);
    if (notify) {
      _sendNewMessageNotification(roomId, senderId, senderName, preview);
    }
    return ChatMessage.fromJson(response);
  }

  /// Send an attachment message using in-memory bytes (web and mobile compatible).
  static Future<ChatMessage> sendAttachmentMessageBytes({
    required String roomId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required Uint8List bytes,
    required String fileName,
    required MessageType messageType,
    String? content,
    String? replyToId,
    bool notify = true,
  }) async {
    final parts = fileName.split('.');
    final ext = parts.length > 1 ? parts.last : '';
    final url = await uploadAttachmentBytes(bytes, roomId, ext);
    final typeStr = _messageTypeToString(messageType);

    final payload = {
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'message_type': typeStr,
      'attachment_url': url,
      'attachment_name': fileName,
      'reply_to_id': replyToId,
    };

    final response = await _db.from('chat_messages').insert(payload).select().single();
    final preview = _attachmentPreview(messageType, fileName);
    await _updateRoomLastMessage(
      roomId,
      preview,
      response['created_at'] as String,
    );
    await restoreDeletedRoom(senderId, roomId);
    if (notify) {
      _sendNewMessageNotification(roomId, senderId, senderName, preview);
    }
    return ChatMessage.fromJson(response);
  }

  /// Forward a message to another room.
  static Future<void> forwardMessage({
    required ChatMessage original,
    required String targetRoomId,
    required String forwarderName,
    required String forwarderRole,
    required String forwarderId,
  }) async {
    final payload = {
      'room_id': targetRoomId,
      'sender_id': forwarderId,
      'sender_name': forwarderName,
      'sender_role': forwarderRole,
      'content': original.content,
      'message_type': original.typeString,
      'attachment_url': original.attachmentUrl,
      'attachment_name': original.attachmentName,
      'is_forwarded': true,
    };

    final response = await _db.from('chat_messages').insert(payload).select().single();
    await _updateRoomLastMessage(
      targetRoomId,
      '↪ ${original.previewText}',
      response['created_at'] as String,
    );
  }

  /// Toggle pin on a message.
  static Future<void> pinMessage(String messageId, {required bool isPinned}) async {
    await _db.from('chat_messages').update({'is_pinned': isPinned}).eq('id', messageId);
  }

  /// Soft-delete a message.
  static Future<void> deleteMessage(String messageId) async {
    await _db.from('chat_messages').update({
      'is_deleted': true,
      'content': null,
      'attachment_url': null,
    }).eq('id', messageId);
  }

  /// Edit a text message.
  static Future<void> editMessage(String messageId, String newContent) async {
    await _db.from('chat_messages').update({
      'content': newContent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  /// Search messages in a room by keyword.
  static Future<List<ChatMessage>> searchMessages(
    String roomId,
    String query, {
    String? currentUserId,
  }) async {
    DateTime? clearedAt;
    if (currentUserId != null) {
      clearedAt = await getClearedAt(currentUserId, roomId);
    }

    var dbQuery = _db
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .eq('is_deleted', false)
        .ilike('content', '%$query%');

    if (clearedAt != null) {
      dbQuery = dbQuery.gt('created_at', clearedAt.toIso8601String());
    }

    final response = await dbQuery
        .order('created_at', ascending: false)
        .limit(30);

    var list = (response as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();

    if (clearedAt != null) {
      list = list.where((m) => m.createdAt.isAfter(clearedAt!)).toList();
    }

    return list;
  }

  /// Fetch pinned messages in a room.
  static Future<List<ChatMessage>> fetchPinnedMessages(
    String roomId, {
    String? currentUserId,
  }) async {
    DateTime? clearedAt;
    if (currentUserId != null) {
      clearedAt = await getClearedAt(currentUserId, roomId);
    }

    var dbQuery = _db
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .eq('is_pinned', true)
        .eq('is_deleted', false);

    if (clearedAt != null) {
      dbQuery = dbQuery.gt('created_at', clearedAt.toIso8601String());
    }

    final response = await dbQuery
        .order('created_at', ascending: false);

    var list = (response as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();

    if (clearedAt != null) {
      list = list.where((m) => m.createdAt.isAfter(clearedAt!)).toList();
    }

    return list;
  }

  // ──────────────────────────────────────────────────
  // PARTICIPANTS & READ RECEIPTS
  // ──────────────────────────────────────────────────

  /// Mark all messages in a room as read for the user.
  static Future<void> markRead(String roomId, String userId) async {
    await _db
        .from('chat_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', userId);
    await AppNotificationService.markChatRoomAsRead(
      roomId: roomId,
      userId: userId,
    );
  }

  /// Get unread message count for a user in a room.
  static Future<int> getUnreadCount(String roomId, String userId) async {
    final participant = await _db
        .from('chat_participants')
        .select('last_read_at')
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();

    if (participant == null) return 0;
    final lastRead = participant['last_read_at'];

    var query = _db
        .from('chat_messages')
        .select('id')
        .eq('room_id', roomId)
        .neq('sender_id', userId);

    if (lastRead != null) {
      query = query.gt('created_at', lastRead);
    }

    final clearedAt = await getClearedAt(userId, roomId);
    if (clearedAt != null) {
      query = query.gt('created_at', clearedAt.toIso8601String());
    }

    final response = await query.count(CountOption.exact);
    return response.count;
  }

  /// Fetch eligible users to start a chat with, filtered by role.
  static Future<List<Map<String, dynamic>>> fetchEligibleUsers({
    required String currentUserId,
    required String currentUserRole,
  }) async {
    List<String> allowedRoles = [];
    switch (currentUserRole) {
      case 'teacher':
        allowedRoles = ['admin', 'campadmin'];
        break;
      case 'admin':
      case 'campadmin':
        allowedRoles = ['teacher', 'maintenance', 'admin', 'campadmin'];
        break;
      case 'maintenance':
        allowedRoles = ['admin', 'campadmin'];
        break;
    }

    final response = await _db
        .from('users')
        .select('id, name, email, role, profile_image')
        .inFilter('role', allowedRoles)
        .neq('id', currentUserId)
        .eq('is_active', true)
        .order('name');

    return (response as List).cast<Map<String, dynamic>>();
  }

  // ──────────────────────────────────────────────────
  // TYPING INDICATOR
  // ──────────────────────────────────────────────────

  static Future<void> setTyping(
    String roomId,
    String userId,
    String userName, {
    required bool isTyping,
  }) async {
    try {
      await _db.from('chat_typing').upsert({
        'room_id': roomId,
        'user_id': userId,
        'user_name': userName,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Typing is non-critical
    }
  }

  // ──────────────────────────────────────────────────
  // REALTIME STREAMS
  // ──────────────────────────────────────────────────

  /// Stream of new messages for a room.
  static RealtimeChannel subscribeToMessages(
    String roomId,
    void Function(ChatMessage msg) onMessage,
  ) {
    final channel = _db.channel('chat_messages_$roomId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        try {
          final msg = ChatMessage.fromJson(payload.newRecord);
          onMessage(msg);
        } catch (e) {
          debugPrint('ChatService: message parse error $e');
        }
      },
    ).subscribe();
    return channel;
  }

  /// Stream of message updates (pin, delete) for a room.
  static RealtimeChannel subscribeToMessageUpdates(
    String roomId,
    void Function(ChatMessage msg) onUpdate,
  ) {
    final channel = _db.channel('chat_message_updates_$roomId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'chat_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        try {
          final msg = ChatMessage.fromJson(payload.newRecord);
          onUpdate(msg);
        } catch (e) {
          debugPrint('ChatService: message update parse error $e');
        }
      },
    ).subscribe();
    return channel;
  }

  /// Stream of typing indicators for a room.
  static RealtimeChannel subscribeToTyping(
    String roomId,
    void Function(TypingIndicator) onTyping,
  ) {
    final channel = _db.channel('chat_typing_$roomId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_typing',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        try {
          final t = TypingIndicator.fromJson(payload.newRecord);
          onTyping(t);
        } catch (e) {
          debugPrint('ChatService: typing parse error $e');
        }
      },
    ).subscribe();
    return channel;
  }

  /// Stream of room list updates (last message, timestamp).
  static RealtimeChannel subscribeToRooms(
    String userId,
    void Function() onRoomUpdate,
  ) {
    final channel = _db.channel('chat_rooms_user_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'chat_rooms',
      callback: (_) => onRoomUpdate(),
    ).subscribe();
    return channel;
  }

  // ──────────────────────────────────────────────────
  // STORAGE
  // ──────────────────────────────────────────────────

  static Future<String> uploadAttachment(String filePath, String roomId) async {
    // Extract extension without requiring path package
    final parts = filePath.split('.');
    final ext = parts.length > 1 ? '.${parts.last}' : '';
    final fileName = '$roomId/${DateTime.now().millisecondsSinceEpoch}$ext';
    if (!kIsWeb) {
      final file = File(filePath);
      await _db.storage.from('chat-attachments').upload(fileName, file);
    } else {
      throw UnsupportedError('Use uploadAttachmentBytes on web platforms');
    }
    return _db.storage.from('chat-attachments').getPublicUrl(fileName);
  }

  static Future<String> uploadAttachmentBytes(
    Uint8List bytes,
    String roomId,
    String extension,
  ) async {
    final fileName = '$roomId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final mimeType = _getMimeType(extension);
    await _db.storage.from('chat-attachments').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: mimeType),
    );
    return _db.storage.from('chat-attachments').getPublicUrl(fileName);
  }

  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      // Archives
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case '7z':
        return 'application/x-7z-compressed';
      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      case 'opus':
        return 'audio/ogg';
      // Video
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      // Safe fallback — Supabase accepts application/pdf for unknown types
      // (application/octet-stream is rejected with HTTP 415)
      default:
        return 'application/pdf';
    }
  }

  // ──────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────

  static Future<void> _updateRoomLastMessage(
    String roomId,
    String preview,
    String messageAt,
  ) async {
    await _db.from('chat_rooms').update({
      'last_message': preview.length > 100 ? '${preview.substring(0, 100)}…' : preview,
      'last_message_at': messageAt,
      'updated_at': messageAt,
    }).eq('id', roomId);
  }

  static String _messageTypeToString(MessageType t) {
    switch (t) {
      case MessageType.image:  return 'image';
      case MessageType.voice:  return 'voice';
      case MessageType.file:   return 'file';
      case MessageType.system: return 'system';
      default:                 return 'text';
    }
  }

  static String _attachmentPreview(MessageType t, String name) {
    switch (t) {
      case MessageType.image: return '📷 Image';
      case MessageType.voice: return '🎤 Voice message';
      case MessageType.file:  return '📎 $name';
      default:                return name;
    }
  }

  static Future<void> _sendNewMessageNotification(
    String roomId,
    String senderId,
    String senderName,
    String messageContent,
  ) async {
    try {
      final participants = await _db
          .from('chat_participants')
          .select('user_id')
          .eq('room_id', roomId)
          .neq('user_id', senderId);
      final list = participants as List;
      for (final item in list) {
        final recipientId = item['user_id'] as String?;
        if (recipientId != null && recipientId.isNotEmpty) {
          await AppNotificationService.notifyNewChatMessage(
            targetUserId: recipientId,
            senderName: senderName,
            messageContent: messageContent,
            chatRoomId: roomId,
          );
        }
      }
    } catch (_) {
      // Do not block primary operations if notification fails
    }
  }
}
