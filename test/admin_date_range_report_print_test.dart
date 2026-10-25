import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/shared/models/work_request_model.dart';

void main() {
  group('Campus Admin Custom Date Range & Report Filter Tests', () {
    late List<WorkRequest> sampleRequests;

    setUp(() {
      sampleRequests = [
        WorkRequest(
          id: 'WR-001',
          title: 'AC Maintenance Room 101',
          description: 'AC blowing warm air',
          roomCode: 'RM101',
          buildingName: 'Engineering Building',
          requestorName: 'Prof. Juan Dela Cruz',
          requestorPosition: 'Faculty',
          typeOfRequest: 'Repair',
          status: 'Completed',
          priority: 'High',
          dateSubmitted: DateTime(2026, 10, 5, 9, 30),
          dateCompleted: DateTime(2026, 10, 6, 14, 00),
        ),
        WorkRequest(
          id: 'WR-002',
          title: 'Electrical Outlet Repair',
          description: 'Broken socket',
          roomCode: 'RM102',
          buildingName: 'IT Building',
          requestorName: 'Dr. Maria Santos',
          requestorPosition: 'Department Chair',
          typeOfRequest: 'Repair',
          status: 'In Progress',
          priority: 'Medium',
          dateSubmitted: DateTime(2026, 10, 12, 11, 15),
        ),
        WorkRequest(
          id: 'WR-003',
          title: 'Projector Mount Installation',
          description: 'Install ceiling mount',
          roomCode: 'RM205',
          buildingName: 'Main Building',
          requestorName: 'Engr. Pedro Gomez',
          requestorPosition: 'Instructor',
          typeOfRequest: 'Installation',
          status: 'Pending',
          priority: 'Low',
          dateSubmitted: DateTime(2026, 10, 18, 16, 45),
        ),
        WorkRequest(
          id: 'WR-004',
          title: 'Old September Request',
          description: 'Water leak',
          roomCode: 'RM104',
          buildingName: 'Science Building',
          requestorName: 'Prof. Ana Reyes',
          requestorPosition: 'Faculty',
          typeOfRequest: 'Repair',
          status: 'Declined',
          priority: 'High',
          dateSubmitted: DateTime(2026, 9, 20, 8, 00),
        ),
        WorkRequest(
          id: 'WR-005',
          title: 'Late October Request',
          description: 'Broken window latch',
          roomCode: 'RM301',
          buildingName: 'Education Building',
          requestorName: 'Prof. Carlos Tan',
          requestorPosition: 'Instructor',
          typeOfRequest: 'Repair',
          status: 'Completed',
          priority: 'Medium',
          dateSubmitted: DateTime(2026, 10, 25, 10, 00),
        ),
      ];
    });

    test('Custom Date Range strictly filters records between startDate and endDate', () {
      final startDate = DateTime(2026, 10, 10);
      final endDate = DateTime(2026, 10, 20);

      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      final filtered = sampleRequests.where((r) {
        return !r.dateSubmitted.isBefore(start) && !r.dateSubmitted.isAfter(end);
      }).toList();

      // Only WR-002 (Oct 12) and WR-003 (Oct 18) are in range
      expect(filtered.length, 2);
      expect(filtered.map((r) => r.id).toList(), containsAll(['WR-002', 'WR-003']));
      expect(filtered.any((r) => r.id == 'WR-001'), isFalse); // Oct 5 is out of range
      expect(filtered.any((r) => r.id == 'WR-004'), isFalse); // Sep 20 is out of range
      expect(filtered.any((r) => r.id == 'WR-005'), isFalse); // Oct 25 is out of range
    });

    test('Custom Date Range includes records submitted at exact start and end days', () {
      final startDate = DateTime(2026, 10, 5);
      final endDate = DateTime(2026, 10, 12);

      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      final filtered = sampleRequests.where((r) {
        return !r.dateSubmitted.isBefore(start) && !r.dateSubmitted.isAfter(end);
      }).toList();

      expect(filtered.length, 2);
      expect(filtered.map((r) => r.id).toList(), containsAll(['WR-001', 'WR-002']));
    });

    test('Custom Date Range with no matches yields empty list', () {
      final startDate = DateTime(2026, 1, 1);
      final endDate = DateTime(2026, 1, 31);

      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      final filtered = sampleRequests.where((r) {
        return !r.dateSubmitted.isBefore(start) && !r.dateSubmitted.isAfter(end);
      }).toList();

      expect(filtered.isEmpty, isTrue);
    });

    test('Reports History filter combines status and custom date range accurately', () {
      final startDate = DateTime(2026, 10, 1);
      final endDate = DateTime(2026, 10, 31);

      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

      // Only completed records within October 2026
      final filtered = sampleRequests.where((r) {
        final matchesStatus = r.status.toLowerCase() == 'completed';
        final inRange = !r.dateSubmitted.isBefore(start) && !r.dateSubmitted.isAfter(end);
        return matchesStatus && inRange;
      }).toList();

      // WR-001 (Oct 5) and WR-005 (Oct 25)
      expect(filtered.length, 2);
      expect(filtered.map((r) => r.id).toList(), containsAll(['WR-001', 'WR-005']));
    });
  });
}
