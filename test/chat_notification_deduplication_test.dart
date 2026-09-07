import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/shared/models/app_notification_model.dart';
import 'package:psu_maintsystem/shared/services/app_notification_service.dart';

void main() {
  group('Chat Notification Deduplication Tests', () {
    test('Collapses dual-dispatch notifications sent within seconds for same room', () {
      final now = DateTime.now();

      // Dual dispatch scenario: ChatService sends one, ChatMessagesPanel sends another
      final notif1 = AppNotification(
        id: 'n1',
        title: '💬 Teacher Juan',
        message: 'Hello maintenance',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-xyz',
        chatRoomId: 'room-xyz',
        isRead: false,
        createdAt: now,
      );

      final notif2 = AppNotification(
        id: 'n2',
        title: '💬 Teacher Juan',
        message: 'Hello maintenance',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-xyz',
        chatRoomId: 'room-xyz',
        isRead: false,
        createdAt: now.add(const Duration(milliseconds: 150)),
      );

      final result = AppNotificationService.deduplicateNotifications([notif1, notif2]);
      expect(result.length, 1);
      expect(result.first.id, 'n1');
    });

    test('Preserves notifications for different recipients', () {
      final now = DateTime.now();

      final notifUser1 = AppNotification(
        id: 'n1',
        title: '💬 Teacher Juan',
        message: 'Hello team',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-xyz',
        chatRoomId: 'room-xyz',
        isRead: false,
        createdAt: now,
      );

      final notifUser2 = AppNotification(
        id: 'n2',
        title: '💬 Teacher Juan',
        message: 'Hello team',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'admin-user-2',
        targetPage: 'chat_room_id:room-xyz',
        chatRoomId: 'room-xyz',
        isRead: false,
        createdAt: now,
      );

      final result = AppNotificationService.deduplicateNotifications([notifUser1, notifUser2]);
      expect(result.length, 2);
    });

    test('Preserves notifications for different rooms', () {
      final now = DateTime.now();

      final notifRoomA = AppNotification(
        id: 'n1',
        title: '💬 Teacher Juan',
        message: 'Room A issue',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-A',
        chatRoomId: 'room-A',
        isRead: false,
        createdAt: now,
      );

      final notifRoomB = AppNotification(
        id: 'n2',
        title: '💬 Teacher Juan',
        message: 'Room B issue',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-B',
        chatRoomId: 'room-B',
        isRead: false,
        createdAt: now,
      );

      final result = AppNotificationService.deduplicateNotifications([notifRoomA, notifRoomB]);
      expect(result.length, 2);
    });

    test('Collapses repeated identical legacy notifications within 10 minutes', () {
      final now = DateTime.now();

      final notif1 = AppNotification(
        id: 'n1',
        title: '💬 Teacher Juan',
        message: 'Please check the AC',
        type: 'chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-xyz',
        chatRoomId: 'room-xyz',
        isRead: false,
        createdAt: now,
      );

      final notif2 = AppNotification(
        id: 'n2',
        title: '💬 Teacher Juan',
        message: 'Please check the AC',
        type: 'new_chat_message',
        targetRole: 'all',
        targetUserId: 'maint-user-1',
        targetPage: 'chat_room_id:room-xyz',
        chatRoomId: 'room-xyz',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 3)),
      );

      final result = AppNotificationService.deduplicateNotifications([notif1, notif2]);
      expect(result.length, 1);
    });

    test('AppNotification.fromMap correctly parses chat_room_id from target_page', () {
      final map = {
        'id': 'test-id-1',
        'title': '💬 Engr. Test',
        'message': 'Work in progress',
        'type': 'chat_message',
        'target_role': 'all',
        'target_user_id': 'user-123',
        'target_page': 'chat_room_id:custom-room-456',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final notif = AppNotification.fromMap(map);
      expect(notif.chatRoomId, 'custom-room-456');
      expect(notif.targetPage, 'chat_room_id:custom-room-456');
      expect(notif.type, 'chat_message');
    });
  });
}
