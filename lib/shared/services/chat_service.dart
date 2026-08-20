import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';

class ChatService {
  static SupabaseClient get _db => Supabase.instance.client;

  // ──────────────────────────────────────────────────
  // ROOMS
  // ──────────────────────────────────────────────────

  /// Fetch all rooms the current user participates in.
  static Future<List<ChatRoom>> fetchRooms(String userId) async {
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

    final rooms = (response as List)
        .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
        .where((r) => r.participants.any((p) => p.userId == userId))
        .toList();

    return rooms;
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
    final existing = await _db.rpc('find_direct_chat_room', params: {
      'user_a': currentUserId,
      'user_b': otherUserId,
    }).maybeSingle();

    if (existing != null) {
      final room = await fetchRoom(existing['id'] as String);
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

  /// Fetch the latest 50 messages in a room (paginated).
  static Future<List<ChatMessage>> fetchMessages(
    String roomId, {
    int limit = 50,
    String? before, // cursor: created_at ISO string
  }) async {
    var query = _db.from('chat_messages').select().eq('room_id', roomId);

    if (before != null) {
      query = query.lt('created_at', before);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    return (response as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
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
    await _updateRoomLastMessage(
      roomId,
      _attachmentPreview(messageType, fileName),
      response['created_at'] as String,
    );
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

  /// Search messages in a room by keyword.
  static Future<List<ChatMessage>> searchMessages(String roomId, String query) async {
    final response = await _db
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .eq('is_deleted', false)
        .ilike('content', '%$query%')
        .order('created_at', ascending: false)
        .limit(30);

    return (response as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch pinned messages in a room.
  static Future<List<ChatMessage>> fetchPinnedMessages(String roomId) async {
    final response = await _db
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .eq('is_pinned', true)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
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
        allowedRoles = ['admin', 'campadmin', 'maintenance'];
        break;
      case 'admin':
      case 'campadmin':
        allowedRoles = ['teacher', 'maintenance', 'admin', 'campadmin'];
        break;
      case 'maintenance':
        allowedRoles = ['admin', 'campadmin', 'maintenance'];
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
    await _db.storage.from('chat-attachments').uploadBinary(fileName, bytes);
    return _db.storage.from('chat-attachments').getPublicUrl(fileName);
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
}
