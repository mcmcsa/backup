import 'package:flutter/material.dart';

import '../../shared/admin_styles.dart';

class AdminRoomSuccesPopupWeb extends StatelessWidget {
  final bool isEdit;
  final String roomName;
  final String building;
  final String floor;
  final String department;
  final String status;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  const AdminRoomSuccesPopupWeb({
    super.key,
    required this.isEdit,
    required this.roomName,
    required this.building,
    required this.floor,
    this.department = '',
    required this.status,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  String get _statusLabel {
    switch (status) {
      case 'available':
        return 'AVAILABLE';
      case 'reserved':
        return 'RESERVED';
      case 'maintenance':
        return 'UNAVAILABLE';
      default:
        return status.toUpperCase();
    }
  }

  Color get _statusColor {
    switch (status) {
      case 'available':
        return const Color(0xFF10B981);
      case 'reserved':
        return const Color(0xFFF59E0B);
      case 'maintenance':
        return const Color(0xFFF91A16);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 36,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 30,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Room Updated Successfully' : 'Room Added Successfully',
                                  style: AdminStyles.headingStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AdminStyles.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isEdit
                                      ? 'Changes for $roomName are now live in your room records.'
                                      : '$roomName has been saved and is now visible in room management.',
                                  style: AdminStyles.bodyStyle(
                                    fontSize: 13,
                                    color: AdminStyles.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Room Name', roomName),
                            _buildInfoRow('Building', building),
                            _buildInfoRow('Floor', floor),
                            if (department.isNotEmpty) _buildInfoRow('Department', department),
                            _buildStatusRow('Status', _statusLabel, _statusColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: onPrimaryAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Back to Room Management',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onSecondaryAction,
                        child: Text(
                          isEdit ? 'Close' : 'Add Another Room',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
