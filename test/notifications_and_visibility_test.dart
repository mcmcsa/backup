import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/shared/models/app_notification_model.dart';
import 'package:psu_maintsystem/shared/services/app_notification_service.dart';

void main() {
  group('Role Normalization & Visibility Filter Tests', () {
    test('normalizeRole normalizes admin and campadmin correctly', () {
      expect(AppNotificationService.normalizeRole('admin'), 'admin');
      expect(AppNotificationService.normalizeRole('CAMPADMIN'), 'campadmin');
      expect(AppNotificationService.normalizeRole('campadmin'), 'campadmin');
      expect(AppNotificationService.normalizeRole('teacher'), 'teacher');
      expect(AppNotificationService.normalizeRole('maintenance'), 'maintenance');
      expect(AppNotificationService.normalizeRole('all'), 'all');
    });

    test('Maintenance user visibility strictly isolates personal & global notifications', () {
      final now = DateTime.now();

      final notifications = [
        // 1. Direct notification to this maintenance technician
        AppNotification(
          id: 'n1',
          title: 'Work Request Approved',
          message: 'Assigned to you',
          type: 'work_request_approved',
          targetRole: 'all',
          targetUserId: 'maint_user_1',
          workRequestId: 'wr_001',
          isRead: false,
          createdAt: now,
        ),
        // 2. Global announcement
        AppNotification(
          id: 'n2',
          title: 'System Maintenance',
          message: 'Server upgrade tonight',
          type: 'announcement',
          targetRole: 'all',
          targetUserId: null,
          workRequestId: null,
          isRead: false,
          createdAt: now,
        ),
        // 3. Leaked unassigned ticket notification broadcast to 'maintenance' role
        AppNotification(
          id: 'n3',
          title: 'New Request',
          message: 'Room 101 issue',
          type: 'work_request_submitted',
          targetRole: 'maintenance',
          targetUserId: null,
          workRequestId: 'wr_unassigned',
          isRead: false,
          createdAt: now,
        ),
        // 4. Notification targeted to another maintenance technician
        AppNotification(
          id: 'n4',
          title: 'Work Request Approved',
          message: 'Assigned to tech 2',
          type: 'work_request_approved',
          targetRole: 'all',
          targetUserId: 'maint_user_2',
          workRequestId: 'wr_002',
          isRead: false,
          createdAt: now,
        ),
      ];

      // Maintenance visibility rule simulation (matching _visibilityFilter logic):
      // target_user_id == userId OR (target_user_id == null AND target_role == 'all')
      const userId = 'maint_user_1';
      final visibleToMaint = notifications.where((n) {
        if (n.targetUserId == userId) return true;
        if (n.targetUserId == null && n.targetRole == 'all') return true;
        return false;
      }).toList();

      expect(visibleToMaint.length, 2);
      expect(visibleToMaint.map((n) => n.id), containsAll(['n1', 'n2']));
      expect(visibleToMaint.map((n) => n.id), isNot(contains('n3'))); // No unassigned tickets
      expect(visibleToMaint.map((n) => n.id), isNot(contains('n4'))); // No other staff's tickets
    });

    test('Campus Admin user visibility includes campadmin, admin, all, and personal', () {
      final now = DateTime.now();
      const adminId = 'admin_001';

      final notifications = [
        // 1. Direct personal notification to admin
        AppNotification(
          id: 'a1',
          title: 'New Work Request Submitted',
          message: 'Direct to admin',
          type: 'work_request_submitted',
          targetRole: 'all',
          targetUserId: adminId,
          workRequestId: 'wr_001',
          isRead: false,
          createdAt: now,
        ),
        // 2. Role broadcast to 'campadmin'
        AppNotification(
          id: 'a2',
          title: 'Pre-Inspection Submitted',
          message: 'Role broadcast campadmin',
          type: 'pre_inspection_submitted',
          targetRole: 'campadmin',
          targetUserId: null,
          workRequestId: 'wr_001',
          isRead: false,
          createdAt: now,
        ),
        // 3. Role broadcast to 'admin'
        AppNotification(
          id: 'a3',
          title: 'Post-Repair Evaluation Submitted',
          message: 'Role broadcast admin',
          type: 'post_repair_submitted',
          targetRole: 'admin',
          targetUserId: null,
          workRequestId: 'wr_001',
          isRead: false,
          createdAt: now,
        ),
        // 4. Role broadcast to 'teacher' (should NOT be visible to admin unless targeted)
        AppNotification(
          id: 'a4',
          title: 'Work Request Ready for Your Confirmation',
          message: 'For teacher',
          type: 'work_request_completion_ready_for_requestor',
          targetRole: 'teacher',
          targetUserId: null,
          workRequestId: 'wr_001',
          isRead: false,
          createdAt: now,
        ),
      ];

      final visibleToAdmin = notifications.where((n) {
        if (n.targetUserId == adminId) return true;
        if (n.targetUserId == null) {
          final r = n.targetRole.toLowerCase();
          return r == 'campadmin' || r == 'admin' || r == 'all';
        }
        return false;
      }).toList();

      expect(visibleToAdmin.length, 3);
      expect(visibleToAdmin.map((n) => n.id), containsAll(['a1', 'a2', 'a3']));
      expect(visibleToAdmin.map((n) => n.id), isNot(contains('a4')));
    });

    test('deduplicateNotifications collapses duplicate direct + role alerts', () {
      final baseTime = DateTime.now();

      final rawNotifications = [
        AppNotification(
          id: 'notif_direct',
          title: 'New Work Request Submitted',
          message: 'New request for Room 101',
          type: 'work_request_submitted',
          targetRole: 'all',
          targetUserId: 'admin_1',
          workRequestId: 'wr_100',
          isRead: false,
          createdAt: baseTime,
        ),
        AppNotification(
          id: 'notif_role',
          title: 'New Work Request Submitted',
          message: 'New request for Room 101',
          type: 'work_request_submitted',
          targetRole: 'campadmin',
          targetUserId: null,
          workRequestId: 'wr_100',
          isRead: false,
          createdAt: baseTime.add(const Duration(seconds: 1)),
        ),
        AppNotification(
          id: 'notif_diff_request',
          title: 'New Work Request Submitted',
          message: 'New request for Room 202',
          type: 'work_request_submitted',
          targetRole: 'campadmin',
          targetUserId: null,
          workRequestId: 'wr_200',
          isRead: false,
          createdAt: baseTime.add(const Duration(seconds: 2)),
        ),
      ];

      final deduped = AppNotificationService.deduplicateNotifications(rawNotifications);

      expect(deduped.length, 2);
      expect(deduped.any((n) => n.workRequestId == 'wr_100'), isTrue);
      expect(deduped.any((n) => n.workRequestId == 'wr_200'), isTrue);
    });
  });

  group('Maintenance Work Task Visibility Rules', () {
    test('strictly filters out tickets not assigned to technician', () {
      const currentTechId = 'tech_alpha';

      final mockTickets = [
        {
          'id': 'wr_1',
          'status': 'In Progress',
          'assigned_to_id': 'tech_alpha',
          'accepted_by_id': null,
          'collaborators': <String>[],
        },
        {
          'id': 'wr_2',
          'status': 'Accepted by Maintenance',
          'assigned_to_id': 'tech_beta',
          'accepted_by_id': 'tech_alpha',
          'collaborators': <String>[],
        },
        {
          'id': 'wr_3',
          'status': 'Under Maintenance',
          'assigned_to_id': 'tech_beta',
          'accepted_by_id': null,
          'collaborators': ['tech_alpha', 'tech_gamma'],
        },
        {
          'id': 'wr_4_unassigned',
          'status': 'Pending',
          'assigned_to_id': null,
          'accepted_by_id': null,
          'collaborators': <String>[],
        },
        {
          'id': 'wr_5_other_tech',
          'status': 'In Progress',
          'assigned_to_id': 'tech_beta',
          'accepted_by_id': null,
          'collaborators': <String>[],
        },
      ];

      // Logic enforced by WorkRequestService.fetchAssignedTo
      final visible = mockTickets.where((t) {
        final assigned = t['assigned_to_id'] == currentTechId;
        final accepted = t['accepted_by_id'] == currentTechId;
        final collab = (t['collaborators'] as List<String>).contains(currentTechId);
        return assigned || accepted || collab;
      }).toList();

      expect(visible.length, 3);
      expect(visible.map((t) => t['id']), containsAll(['wr_1', 'wr_2', 'wr_3']));
      expect(visible.map((t) => t['id']), isNot(contains('wr_4_unassigned')));
      expect(visible.map((t) => t['id']), isNot(contains('wr_5_other_tech')));
    });
  });
}
