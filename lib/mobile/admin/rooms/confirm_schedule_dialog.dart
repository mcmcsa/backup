import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/models/schedule_model.dart';
import '../../../shared/services/schedule_service.dart';
import 'schedule_success_page.dart';

class ConfirmScheduleDialog extends StatelessWidget {
  final Room room;
  final String subjectName;
  final String instructor;
  final String scheduledDate;
  final String startTime;
  final String endTime;
  final bool isMaintenanceWindow;
  final String notes;

  const ConfirmScheduleDialog({
    super.key,
    required this.room,
    required this.subjectName,
    required this.instructor,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.isMaintenanceWindow,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Confirm Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review the details before confirming',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Room Header with Icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4169E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        room.building,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Schedule Details
          _buildDetailRow(Icons.book_outlined, 'Subject', subjectName),
          _buildDetailRow(Icons.person_outline, 'Instructor', instructor),
          _buildDetailRow(
              Icons.calendar_today_outlined, 'Date', scheduledDate),
          _buildDetailRow(
              Icons.access_time, 'Time Slot', '$startTime - $endTime'),
          _buildDetailRow(
              Icons.location_on_outlined, 'Location', room.building),
          if (isMaintenanceWindow)
            _buildDetailRow(
                Icons.build_outlined, 'Type', 'Maintenance Window'),
          if (notes.isNotEmpty)
            _buildDetailRow(Icons.notes_outlined, 'Notes', notes),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final schedule = RoomSchedule(
                          id: const Uuid().v4(),
                          roomId: room.id,
                          subjectName: subjectName,
                          instructor: instructor,
                          scheduledDate: DateTime.parse(_toIsoDate(scheduledDate)),
                          startTime: startTime,
                          endTime: endTime,
                          isMaintenanceWindow: isMaintenanceWindow,
                          notes: notes.isNotEmpty ? notes : null,
                          status: 'active',
                        );

                        await ScheduleService.insert(schedule);

                        if (!context.mounted) return;
                        // Close the bottom sheet
                        Navigator.pop(context);
                        // Navigate to success screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScheduleSuccessPage(
                              roomName: room.name,
                              subjectName: subjectName,
                              instructor: instructor,
                              scheduledDate: scheduledDate,
                              timeSlot: '$startTime - $endTime',
                              location: room.building,
                              room: room,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4169E1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm Schedule',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _toIsoDate(String dateStr) {
    // Parse "January 1, 2025" format to ISO date
    final months = {
      'January': '01', 'February': '02', 'March': '03', 'April': '04',
      'May': '05', 'June': '06', 'July': '07', 'August': '08',
      'September': '09', 'October': '10', 'November': '11', 'December': '12',
    };
    final parts = dateStr.replaceAll(',', '').split(' ');
    final month = months[parts[0]] ?? '01';
    final day = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$year-$month-$day';
  }
}

