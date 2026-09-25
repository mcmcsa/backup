import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/authentication/models/user_model.dart';
import 'package:psu_maintsystem/shared/models/room_model.dart';
import 'package:psu_maintsystem/shared/widgets/department_mismatch_dialog.dart';

void main() {
  group('Department Mismatch Verification Tests', () {
    final itTeacher = AppUser(
      id: 'teacher-it-1',
      email: 'teacher.it@psu.edu.ph',
      name: 'IT Faculty',
      role: UserRole.teacher,
      isActive: true,
      department: 'IT Department',
      departmentId: 'dept-it-uuid',
    );

    final eduTeacher = AppUser(
      id: 'teacher-edu-1',
      email: 'teacher.edu@psu.edu.ph',
      name: 'Education Faculty',
      role: UserRole.teacher,
      isActive: true,
      department: 'Education Department',
      departmentId: 'dept-edu-uuid',
    );

    final unassignedTeacher = AppUser(
      id: 'teacher-none-1',
      email: 'teacher.none@psu.edu.ph',
      name: 'Unassigned Faculty',
      role: UserRole.teacher,
      isActive: true,
      department: null,
      departmentId: null,
    );

    final adminUser = AppUser(
      id: 'admin-1',
      email: 'admin@psu.edu.ph',
      name: 'Campus Admin',
      role: UserRole.campadmin,
      isActive: true,
    );

    final itRoom = Room(
      id: 'room-clr4',
      code: 'CLR 4',
      name: 'Computer Laboratory Room 4',
      building: 'Agro-Business Building',
      floor: '2nd Floor',
      department: 'IT Department',
      departmentId: 'dept-it-uuid',
      seats: 40,
      status: 'available',
    );

    final eduRoom = Room(
      id: 'room-edu101',
      code: 'EDU 101',
      name: 'Education Classroom 101',
      building: 'Education Building',
      floor: '1st Floor',
      department: 'Education Department',
      departmentId: 'dept-edu-uuid',
      seats: 40,
      status: 'available',
    );

    final commonRoom = Room(
      id: 'room-cr1',
      code: 'CR-1F',
      name: 'Comfort Room 1st Floor',
      building: 'Main Building',
      floor: '1st Floor',
      department: '',
      departmentId: '',
      seats: 0,
      status: 'available',
    );

    test('1. Teacher can report issues in their own department room', () {
      expect(isRoomOfOtherDepartment(user: itTeacher, room: itRoom), isFalse);
      expect(isRoomOfOtherDepartment(user: eduTeacher, room: eduRoom), isFalse);
    });

    test('2. Teacher is BLOCKED from reporting issues in another department room', () {
      expect(isRoomOfOtherDepartment(user: eduTeacher, room: itRoom), isTrue);
      expect(isRoomOfOtherDepartment(user: itTeacher, room: eduRoom), isTrue);
    });

    test('3. Teacher can report issues in department-less common facility (e.g. CR, hallway, lobby)', () {
      expect(isRoomOfOtherDepartment(user: itTeacher, room: commonRoom), isFalse);
      expect(isRoomOfOtherDepartment(user: eduTeacher, room: commonRoom), isFalse);
      expect(isRoomOfOtherDepartment(user: unassignedTeacher, room: commonRoom), isFalse);
    });

    test('4. Admin is not restricted by department matching rules', () {
      expect(isRoomOfOtherDepartment(user: adminUser, room: itRoom), isFalse);
      expect(isRoomOfOtherDepartment(user: adminUser, room: eduRoom), isFalse);
      expect(isRoomOfOtherDepartment(user: adminUser, room: commonRoom), isFalse);
    });

    test('5. Teacher with unassigned department is blocked from department-owned room', () {
      expect(isRoomOfOtherDepartment(user: unassignedTeacher, room: itRoom), isTrue);
    });
  });
}
