import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/room_model.dart';

class RoomVerificationPage extends StatelessWidget {
  final String roomId;
  final Room? room;

  const RoomVerificationPage({
    super.key,
    required this.roomId,
    this.room,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'available': return const Color(0xFF4CAF50);
      case 'reserved': return const Color(0xFFF59E0B);
      case 'maintenance': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available': return 'AVAILABLE';
      case 'reserved': return 'RESERVED';
      case 'maintenance': return 'UNAVAILABLE';
      default: return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = room != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isVerified ? 'Location Verified' : 'Verification Failed',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Verified / Error Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isVerified
                      ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.check_circle : Icons.cancel_outlined,
                  size: 48,
                  color: isVerified ? const Color(0xFF00BFA5) : const Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Room Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    isVerified ? room!.name : 'Unrecognized Room ($roomId)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVerified
                        ? (room!.building.isNotEmpty ? room!.building : 'Campus Facility')
                        : 'Room not found in campus database',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isVerified ? Colors.grey.shade600 : const Color(0xFFEF4444),
                      fontWeight: isVerified ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.meeting_room,
                            size: 16,
                            color: Color(0xFF00BFA5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          room!.roomType.isNotEmpty ? room!.roomType : 'Room',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    if (room!.floor.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        room!.floor,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  // Availability Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (isVerified ? _statusColor(room!.status) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isVerified ? _statusColor(room!.status) : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isVerified ? _statusLabel(room!.status) : 'UNVERIFIED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isVerified ? _statusColor(room!.status) : const Color(0xFFEF4444),
                                letterSpacing: 0.5,
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
            const SizedBox(height: 24),
            // Proceed to Report Issue Button (only if verified)
            if (isVerified) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/work-request-form',
                      extra: {
                        'roomId': roomId,
                        'buildingName': room!.building,
                        'roomName': room!.name,
                        'verifiedRoom': room,
                        'lockLocationDetails': true,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Proceed to Report Issue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    'Return to Room Entry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A valid, verified room is required to submit a maintenance work request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Footer text
            Text(
              'Reporting issues helps keep our facilities in top condition for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

}
