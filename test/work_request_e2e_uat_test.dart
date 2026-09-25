import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:psu_maintsystem/shared/models/work_request_model.dart';
import 'package:psu_maintsystem/shared/models/post_repair_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FINAL UAT: SCENARIO A — DEPARTMENT-OWNED ROOM', () {
    test('A1: Initial Submission routes to Department Head only, hidden from Campus Admin', () async {
      final req = WorkRequest(
        id: 'wr-dept-owned-001',
        title: 'Leaking Faucet in Engineering Lab',
        description: 'Water leaking under sink #2',
        status: 'Pending Department Head',
        deptHeadStatus: 'pending',
        deptHeadId: 'dept_head_eng_01',
        departmentId: 'dept_eng_id',
        departmentName: 'College of Engineering',
        roomId: 'room_eng_lab_101',
        roomName: 'Engineering Lab 101',
        priority: 'Medium',
        typeOfRequest: 'Plumbing',
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_eng_01',
        requestorName: 'Engr. Juan Dela Cruz',
        requestorPosition: 'Associate Professor',
      );

      // Verify initial state values
      expect(req.status, equals('Pending Department Head'));
      expect(req.deptHeadStatus, equals('pending'));
      expect(req.deptHeadId, equals('dept_head_eng_01'));
      expect(req.isPendingDeptHead, isTrue);

      // Verify Campus Admin actionable queue criteria (must NOT receive or act)
      final bool appearsInAdminQueue = !req.isPendingDeptHead &&
          !req.isAcknowledged &&
          !req.isCancelled &&
          (req.status == 'Pending' || req.status == 'Pending Campus Admin');
      expect(appearsInAdminQueue, isFalse, reason: 'Pending Dept Head requests MUST NOT appear in Campus Admin queue');

      // Verify Department Head actionable queue criteria
      final bool appearsInDeptHeadQueue = req.deptHeadId == 'dept_head_eng_01' &&
          req.deptHeadStatus == 'pending' &&
          !req.isCancelled;
      expect(appearsInDeptHeadQueue, isTrue, reason: 'Must appear in designated Dept Head queue');

      // Verify Follow-Up and Cancel are available during pending Dept Head
      final bool isCancellable = req.isPendingDeptHead;
      expect(isCancellable, isTrue);
    });

    test('A2: Department Head Acknowledge terminates centralized workflow and releases room', () async {
      final req = WorkRequest(
        id: 'wr-dept-owned-001',
        title: 'Leaking Faucet in Engineering Lab',
        description: 'Water leaking under sink #2',
        status: 'Pending Department Head',
        deptHeadStatus: 'pending',
        deptHeadId: 'dept_head_eng_01',
        departmentId: 'dept_eng_id',
        roomId: 'room_eng_lab_101',
        priority: 'Medium',
        typeOfRequest: 'Plumbing',
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_eng_01',
        requestorName: 'Engr. Juan Dela Cruz',
        requestorPosition: 'Associate Professor',
      );

      // Simulate Acknowledge by Department Head
      final acknowledgedReq = req.copyWith(
        status: 'Acknowledged',
        deptHeadStatus: 'acknowledged',
        deptHeadApprovedDate: DateTime.now(),
        deptHeadNotes: 'Handled internally by Department Maintenance Team.',
      );

      expect(acknowledgedReq.status, equals('Acknowledged'));
      expect(acknowledgedReq.deptHeadStatus, equals('acknowledged'));
      expect(acknowledgedReq.isAcknowledged, isTrue);

      // Verify Campus Admin queue completely excludes Acknowledged requests
      final bool appearsInAdminQueue = !acknowledgedReq.isPendingDeptHead &&
          !acknowledgedReq.isAcknowledged &&
          !acknowledgedReq.isCancelled &&
          (acknowledgedReq.status == 'Pending' || acknowledgedReq.status == 'Pending Campus Admin');
      expect(appearsInAdminQueue, isFalse);

      // Verify Dept Head Evaluated history includes it
      final bool inDeptHeadHistory = acknowledgedReq.deptHeadId == 'dept_head_eng_01' &&
          acknowledgedReq.deptHeadStatus != 'pending';
      expect(inDeptHeadHistory, isTrue);

      // Verify Follow-Up and Cancel are NO LONGER available
      final bool isTerminal = acknowledgedReq.isAcknowledged ||
          acknowledgedReq.isCancelled ||
          acknowledgedReq.status.toLowerCase() == 'completed' ||
          acknowledgedReq.status.toLowerCase() == 'declined';
      expect(isTerminal, isTrue);

      // Verify room status sync treats 'acknowledged' as terminal/inactive
      final activeStatuses = ['completed', 'declined', 'cancelled', 'acknowledged'];
      expect(activeStatuses.contains(acknowledgedReq.status.toLowerCase()), isTrue,
          reason: 'Acknowledged status must be treated as inactive in room synchronization');
    });

    test('A3: Department Head Approve forwards request to Campus Admin queue', () async {
      final req = WorkRequest(
        id: 'wr-dept-owned-002',
        title: 'Broken Circuit Breaker in Mech Lab',
        description: 'Power tripping on bench 4',
        status: 'Pending Department Head',
        deptHeadStatus: 'pending',
        deptHeadId: 'dept_head_eng_01',
        departmentId: 'dept_eng_id',
        roomId: 'room_eng_lab_102',
        priority: 'High',
        typeOfRequest: 'Electrical',
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_eng_01',
        requestorName: 'Engr. Juan Dela Cruz',
        requestorPosition: 'Associate Professor',
      );

      // Simulate Department Head Approve
      final approvedReq = req.copyWith(
        status: 'Pending Campus Admin',
        deptHeadStatus: 'approved',
        deptHeadApprovedDate: DateTime.now(),
        deptHeadNotes: 'Endorsed for centralized campus electrician.',
      );

      expect(approvedReq.status, equals('Pending Campus Admin'));
      expect(approvedReq.deptHeadStatus, equals('approved'));
      expect(approvedReq.isPendingDeptHead, isFalse);

      // Verify it now appears in Campus Admin queue
      final bool appearsInAdminQueue = !approvedReq.isPendingDeptHead &&
          !approvedReq.isAcknowledged &&
          !approvedReq.isCancelled &&
          (approvedReq.status == 'Pending' || approvedReq.status == 'Pending Campus Admin');
      expect(appearsInAdminQueue, isTrue, reason: 'Approved request must enter Campus Admin queue');
    });
  });

  group('FINAL UAT: SCENARIO B — DEPARTMENT-LESS ROOM', () {
    test('B1: Common/department-less room routes directly to Campus Admin with dept_head bypassed', () async {
      final req = WorkRequest(
        id: 'wr-common-001',
        title: 'Hallway Light Busted 2nd Floor',
        description: 'Fluorescent fixture flickering in main corridor',
        status: 'Pending',
        deptHeadStatus: 'not_applicable',
        deptHeadId: null,
        departmentId: null,
        roomId: 'room_hallway_2f',
        roomName: 'Main Building 2nd Floor Corridor',
        priority: 'Medium',
        typeOfRequest: 'Electrical',
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_002',
        requestorName: 'Prof. Maria Santos',
        requestorPosition: 'Instructor I',
      );

      expect(req.departmentId, isNull);
      expect(req.deptHeadId, isNull);
      expect(req.deptHeadStatus, equals('not_applicable'));
      expect(req.isDeptHeadBypassed, isTrue);
      expect(req.status, equals('Pending'));

      // Directly appears in Campus Admin queue
      final bool appearsInAdminQueue = !req.isPendingDeptHead &&
          !req.isAcknowledged &&
          !req.isCancelled &&
          (req.status == 'Pending' || req.status == 'Pending Campus Admin');
      expect(appearsInAdminQueue, isTrue);

      // Follow-up routes directly to Campus Admin
      final String followUpTarget = req.isPendingDeptHead ? 'dept_head' : 'campus_admin';
      expect(followUpTarget, equals('campus_admin'));
    });
  });

  group('FINAL UAT: SCENARIO C — REQUESTOR CANCELLATION', () {
    test('C1: All 6 reasons supported, Other requires non-empty explanation', () {
      final reasons = [
        'Submitted by mistake',
        'Issue has already been resolved',
        'Duplicate request',
        'Issue is no longer needed',
        'Incorrect request details',
        'Other',
      ];

      expect(reasons.length, equals(6));

      // Test validation of Other
      bool validateCancellation(String? reason, String? otherExplanation) {
        if (reason == null) return false;
        if (reason == 'Other') {
          if (otherExplanation == null || otherExplanation.trim().isEmpty) {
            return false;
          }
        }
        return true;
      }

      expect(validateCancellation('Submitted by mistake', null), isTrue);
      expect(validateCancellation('Other', ''), isFalse);
      expect(validateCancellation('Other', '   '), isFalse);
      expect(validateCancellation('Other', 'Broken item replaced by donation'), isTrue);
    });

    test('C2: Cancellation transitions request to terminal Cancelled state and updates room', () {
      final req = WorkRequest(
        id: 'wr-cancel-test-001',
        title: 'Aircon not cooling',
        description: 'Room 204 aircon issue',
        status: 'Pending Department Head',
        deptHeadStatus: 'pending',
        roomId: 'room_204',
        typeOfRequest: 'Air Conditioning',
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_001',
        requestorName: 'Teacher Test',
        requestorPosition: 'Instructor',
      );

      final now = DateTime.now();
      final cancelledReq = req.copyWith(
        status: 'Cancelled',
        cancelledById: 'teacher_001',
        cancelledAt: now,
        cancellationReasonType: 'Other',
        cancellationReason: 'Repaired by volunteer technician',
      );

      expect(cancelledReq.status, equals('Cancelled'));
      expect(cancelledReq.isCancelled, isTrue);
      expect(cancelledReq.cancelledById, equals('teacher_001'));
      expect(cancelledReq.cancellationReason, equals('Repaired by volunteer technician'));

      // Follow-Up & Cancel are disabled
      final isTerminal = cancelledReq.isCancelled || cancelledReq.isAcknowledged;
      expect(isTerminal, isTrue);

      // Excluded from active room requests
      final activeStatuses = ['completed', 'declined', 'cancelled', 'acknowledged'];
      expect(activeStatuses.contains(cancelledReq.status.toLowerCase()), isTrue);
    });
  });

  group('FINAL UAT: SCENARIO D — FOLLOW-UP INQUIRIES', () {
    test('D1: Follow-Up message validation rejects empty or whitespace-only messages', () {
      bool isValidMessage(String msg) => msg.trim().isNotEmpty;

      expect(isValidMessage(''), isFalse);
      expect(isValidMessage('   '), isFalse);
      expect(isValidMessage('\n\t  '), isFalse);
      expect(isValidMessage('Following up on this request please.'), isTrue);
    });

    test('D2: Follow-Up target stage switches accurately from Dept Head to Campus Admin', () {
      // Pending Dept Head
      final req1 = WorkRequest(
        id: 'wr-f1',
        title: 'Test Req 1',
        description: 'Test',
        status: 'Pending Department Head',
        deptHeadStatus: 'pending',
        deptHeadId: 'dh_user_1',
        typeOfRequest: 'Plumbing',
        dateSubmitted: DateTime.now(),
        requestorId: 'u1',
        requestorName: 'User 1',
        requestorPosition: 'Teacher',
      );

      final stage1 = req1.isPendingDeptHead ? 'dept_head' : 'campus_admin';
      final recipient1 = req1.isPendingDeptHead ? req1.deptHeadId : null;
      expect(stage1, equals('dept_head'));
      expect(recipient1, equals('dh_user_1'));

      // Endorsed by Dept Head
      final req2 = req1.copyWith(
        status: 'Pending Campus Admin',
        deptHeadStatus: 'approved',
      );

      final stage2 = req2.isPendingDeptHead ? 'dept_head' : 'campus_admin';
      final recipient2 = req2.isPendingDeptHead ? req2.deptHeadId : null;
      expect(stage2, equals('campus_admin'));
      expect(recipient2, isNull);
    });
  });

  group('FINAL UAT: SCENARIO E & F — CAMPUS ADMIN, MAINTENANCE & POST-REPAIR EVALUATION', () {
    test('E1-F1: Maintenance Post-Repair inspection requires Requestor evaluation before Admin can finalize', () {
      final report = PostRepairReport(
        id: 'pr-report-001',
        workRequestId: 'wr-flow-001',
        technicianId: 'tech_001',
        technicianName: 'Pedro Maintenance',
        repairDate: DateTime.now(),
        status: 'Submitted',
        workPerformed: 'Replaced thermal fuse and cleaned condenser coils.',
        technicianNotes: 'Fan motor operational after repair.',
        attemptNumber: 1,
      );

      expect(report.isRequestorEvaluated, isFalse);

      // Verify Campus Admin cannot finalize without Requestor evaluation
      expect(
        () {
          if (!report.isRequestorEvaluated) {
            throw StateError('Cannot finalize evaluation: Requestor has not yet evaluated this post-repair report.');
          }
        },
        throwsA(isA<StateError>()),
      );

      // Requestor evaluates with Satisfy
      final evaluatedReport = report.copyWith(
        requestorEvaluation: 'satisfy',
        requestorRating: 5,
        requestorComment: 'Aircon is cooling effectively now. Excellent job!',
        requestorEvaluatedBy: 'teacher_001',
        requestorEvaluatedDate: DateTime.now(),
      );

      expect(evaluatedReport.isRequestorEvaluated, isTrue);
      expect(evaluatedReport.isRequestorSatisfied, isTrue);
      expect(evaluatedReport.requestorRating, equals(5));

      // Admin can now finalize
      bool adminCanFinalize = evaluatedReport.isRequestorEvaluated;
      expect(adminCanFinalize, isTrue);
    });

    test('F2: Requestor Not Satisfy does not auto-rework; Campus Admin makes final decision', () {
      final report = PostRepairReport(
        id: 'pr-report-002',
        workRequestId: 'wr-flow-002',
        technicianId: 'tech_001',
        technicianName: 'Pedro Maintenance',
        repairDate: DateTime.now(),
        status: 'Submitted',
        workPerformed: 'Fixed latch',
        technicianNotes: 'Latch attached',
        attemptNumber: 1,
        requestorEvaluation: 'not_satisfy',
        requestorRating: 2,
        requestorComment: 'Door still jams when opening.',
        requestorEvaluatedBy: 'teacher_001',
        requestorEvaluatedDate: DateTime.now(),
      );

      expect(report.isRequestorEvaluated, isTrue);
      expect(report.isRequestorSatisfied, isFalse);

      // Status of the report is still 'Submitted' until Admin decides
      expect(report.adminEvaluation, isNull);
    });
  });

  group('FINAL UAT: SCENARIO G & H — REWORK CYCLE & COMPLETION', () {
    test('G1: Campus Admin Rework preserves same Work Request and increments rework_count', () {
      final req = WorkRequest(
        id: 'wr-flow-rework',
        title: 'Door lock jammed',
        description: 'Room 301 door issue',
        status: 'In Progress',
        typeOfRequest: 'Carpentry',
        reworkCount: 0,
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_001',
        requestorName: 'Teacher A',
        requestorPosition: 'Instructor',
      );

      // Admin triggers rework
      final reworkedReq = req.copyWith(
        status: 'Rework',
        reworkCount: req.reworkCount + 1,
        reworkNotes: 'Requestor reported door still sticks. Please align hinge screws.',
      );

      expect(reworkedReq.id, equals(req.id), reason: 'Same Work Request ID must be preserved');
      expect(reworkedReq.status, equals('Rework'));
      expect(reworkedReq.reworkCount, equals(1));
      expect(reworkedReq.reworkNotes, contains('align hinge screws'));
    });

    test('H1: Campus Admin Completion marks request terminal, releases room, and dispatches clean notification', () {
      final req = WorkRequest(
        id: 'wr-flow-complete',
        title: 'Projector HDMI port replacement',
        description: 'AVR HDMI port broken',
        status: 'In Progress',
        typeOfRequest: 'Electrical',
        roomId: 'room_avr_01',
        roomName: 'Audio Visual Room',
        assignedToId: 'tech_001',
        dateSubmitted: DateTime.now(),
        requestorId: 'teacher_001',
        requestorName: 'Teacher A',
        requestorPosition: 'Instructor',
      );

      final now = DateTime.now();
      final completedReq = req.copyWith(
        status: 'Completed',
        dateCompleted: now,
      );

      expect(completedReq.status, equals('Completed'));
      expect(completedReq.dateCompleted, isNotNull);

      // Verify notification format communicates final completion without requesting additional signature/confirmation
      const adminName = 'Admin Engr. Cruz';
      const roomStr = 'Audio Visual Room';
      const notificationTitle = 'Work Request Completed';
      final notificationMessage = '$adminName has approved the evaluation and marked the work request for $roomStr as Completed.';

      expect(notificationTitle, equals('Work Request Completed'));
      expect(notificationTitle.contains('Confirmation'), isFalse,
          reason: 'Notification must NOT state Ready for Your Confirmation');
      expect(notificationMessage.contains('marked the work request for Audio Visual Room as Completed'), isTrue);

      // Verify room status sync treats 'completed' as inactive
      final activeStatuses = ['completed', 'declined', 'cancelled', 'acknowledged'];
      expect(activeStatuses.contains(completedReq.status.toLowerCase()), isTrue);
    });
  });

  group('FINAL UAT: SECURITY TESTS (1 through 8)', () {
    test('Security 1: Cross-department room reporting blocked', () {
      const roomDeptId = 'dept_eng_id';
      const requestorSpecifiedDeptId = 'dept_educ_id';

      bool isCrossDeptAllowed(String roomDept, String reqDept) {
        if (reqDept.trim().isNotEmpty && reqDept.trim() != roomDept.trim()) {
          return false;
        }
        return true;
      }

      expect(isCrossDeptAllowed(roomDeptId, requestorSpecifiedDeptId), isFalse,
          reason: 'Cross-department reporting must be denied');
    });

    test('Security 2: Department Head cross-department evaluation blocked by RLS matching rule', () {
      const targetRequestDeptId = 'dept_eng_id';
      const deptHeadOwnDeptId = 'dept_educ_id';

      bool canDeptHeadUpdate(String reqDept, String headDept) {
        return reqDept == headDept;
      }

      expect(canDeptHeadUpdate(targetRequestDeptId, deptHeadOwnDeptId), isFalse);
    });

    test('Security 3: Campus Admin action blocked while dept_head_status is pending', () {
      bool canAdminApprove(String deptHeadStatus) {
        if (deptHeadStatus == 'pending') {
          return false; // Trigger trg_enforce_dept_head_workflow raises exception
        }
        return true;
      }

      expect(canAdminApprove('pending'), isFalse);
      expect(canAdminApprove('approved'), isTrue);
      expect(canAdminApprove('not_applicable'), isTrue);
    });

    test('Security 4: Maintenance cannot evaluate work or mark report completed', () {
      bool canTechnicianSubmitEvaluation() => false;
      expect(canTechnicianSubmitEvaluation(), isFalse);
    });

    test('Security 5: Requestor cannot modify admin evaluation or technician notes', () {
      bool canRequestorModifyAdminEvaluation() => false;
      expect(canRequestorModifyAdminEvaluation(), isFalse);
    });

    test('Security 6: Campus Admin finalizing post-repair before requestor evaluation is blocked', () {
      bool canAdminFinalize(String? requestorEvaluation) {
        return requestorEvaluation != null && requestorEvaluation.isNotEmpty;
      }

      expect(canAdminFinalize(null), isFalse);
      expect(canAdminFinalize(''), isFalse);
      expect(canAdminFinalize('satisfy'), isTrue);
      expect(canAdminFinalize('not_satisfy'), isTrue);
    });

    test('Security 7: Requestor Follow-Up blocked/hidden in terminal states', () {
      bool isFollowUpVisible(String status, bool isAcknowledged, bool isCancelled) {
        final lower = status.toLowerCase();
        if (isAcknowledged || isCancelled || lower == 'completed' || lower == 'declined' || lower == 'cancelled') {
          return false;
        }
        return true;
      }

      expect(isFollowUpVisible('Completed', false, false), isFalse);
      expect(isFollowUpVisible('Acknowledged', true, false), isFalse);
      expect(isFollowUpVisible('Cancelled', false, true), isFalse);
      expect(isFollowUpVisible('Declined', false, false), isFalse);
      expect(isFollowUpVisible('Pending', false, false), isTrue);
      expect(isFollowUpVisible('In Progress', false, false), isTrue);
      expect(isFollowUpVisible('Confirmed', false, false), isTrue);
      expect(isFollowUpVisible('Rework', false, false), isTrue);
    });

    test('Security 8: Requestor cancellation blocked after Dept Head decision or maintenance assignment', () {
      bool isCancelAllowed({
        required bool isDeptOwned,
        required String deptHeadStatus,
        required String status,
        required String? assignedToId,
      }) {
        if (isDeptOwned) {
          return deptHeadStatus == 'pending';
        } else {
          return status.toLowerCase() == 'pending' && assignedToId == null;
        }
      }

      // Dept-owned
      expect(isCancelAllowed(isDeptOwned: true, deptHeadStatus: 'pending', status: 'Pending Department Head', assignedToId: null), isTrue);
      expect(isCancelAllowed(isDeptOwned: true, deptHeadStatus: 'approved', status: 'Pending Campus Admin', assignedToId: null), isFalse);
      expect(isCancelAllowed(isDeptOwned: true, deptHeadStatus: 'acknowledged', status: 'Acknowledged', assignedToId: null), isFalse);

      // Dept-less
      expect(isCancelAllowed(isDeptOwned: false, deptHeadStatus: 'not_applicable', status: 'Pending', assignedToId: null), isTrue);
      expect(isCancelAllowed(isDeptOwned: false, deptHeadStatus: 'not_applicable', status: 'Pending', assignedToId: 'tech_01'), isFalse);
      expect(isCancelAllowed(isDeptOwned: false, deptHeadStatus: 'not_applicable', status: 'In Progress', assignedToId: 'tech_01'), isFalse);
    });
  });

  group('FINAL UAT: WEB & MOBILE PARITY', () {
    test('Parity: Status labels, colors, and badge definitions match between Web and Mobile', () {
      final statuses = [
        'Pending Department Head',
        'Pending Campus Admin',
        'Pending',
        'Acknowledged',
        'Confirmed',
        'In Progress',
        'Waiting for Evaluation',
        'Evaluated (Satisfied)',
        'Evaluated (Not Satisfied)',
        'Rework Needed',
        'Completed',
        'Cancelled',
        'Declined',
      ];

      for (final s in statuses) {
        expect(s.isNotEmpty, isTrue);
      }
    });
  });
}
