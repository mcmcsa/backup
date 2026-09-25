import 'package:flutter/material.dart';
import '../../authentication/models/user_model.dart';
import '../models/room_model.dart';

/// Checks if a room belongs to a different department than the requesting teacher/faculty.
/// Returns true if access should be restricted (mismatch).
/// Returns false if allowed (same department, or department-less common facility).
bool isRoomOfOtherDepartment({
  required AppUser? user,
  required Room? room,
}) {
  if (user == null || room == null) return false;
  // Non-teachers (admin, campadmin, maintenance) can report on any room across the university
  if (user.role != UserRole.teacher) return false;

  final roomDeptId = room.departmentId.trim();
  final roomDeptName = room.department.trim();

  // If the room has NO department (common rooms: CR, lobby, hallway, gym, canteen, grounds, etc.),
  // any faculty member is allowed to file maintenance requests.
  if (roomDeptId.isEmpty && roomDeptName.isEmpty) {
    return false;
  }

  final userDeptId = user.departmentId?.trim() ?? '';
  final userDeptName = user.department?.trim() ?? '';

  // 1. Both have non-empty department IDs: direct ID comparison
  if (userDeptId.isNotEmpty && roomDeptId.isNotEmpty) {
    return userDeptId != roomDeptId;
  }

  // 2. Department name comparison (case-insensitive)
  if (userDeptName.isNotEmpty && roomDeptName.isNotEmpty) {
    return userDeptName.toLowerCase() != roomDeptName.toLowerCase();
  }

  // 3. User has a department name/ID but it didn't match the room's department
  if (userDeptId.isNotEmpty || userDeptName.isNotEmpty) {
    return true;
  }

  // 4. Requestor has NO department assigned in their profile, but the room is department-owned
  return true;
}

/// Displays an informative modal dialog notifying the requestor that the scanned or
/// entered room belongs to a different department.
Future<void> showDepartmentMismatchDialog({
  required BuildContext context,
  required String roomCode,
  required String roomName,
  required String roomDepartment,
  required String? userDepartment,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final isDark = theme.brightness == Brightness.dark;
      final displayCode = roomCode.trim().isNotEmpty ? roomCode.trim() : roomName.trim();
      final displayDept = roomDepartment.trim().isNotEmpty ? roomDepartment.trim() : 'another department';
      final cleanUserDept = userDepartment?.trim();

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.domain_disabled_rounded,
                    color: Color(0xFFEF4444),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Department Restricted',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                    children: [
                      const TextSpan(text: 'Room '),
                      TextSpan(
                        text: displayCode,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (roomName.trim().isNotEmpty && roomName.trim() != displayCode)
                        TextSpan(text: ' (${roomName.trim()})'),
                      const TextSpan(text: ' belongs to '),
                      TextSpan(
                        text: displayDept,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const TextSpan(text: '.\n\n'),
                      if (cleanUserDept != null && cleanUserDept.isNotEmpty)
                        TextSpan(
                          text: 'As a member of $cleanUserDept, you can only file maintenance requests for rooms within your department or common campus facilities (e.g. comfort rooms, lobbies, hallways).',
                        )
                      else
                        const TextSpan(
                          text: 'You can only file maintenance requests for rooms assigned to your department or common campus facilities (e.g. comfort rooms, lobbies, hallways).',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Understood',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
