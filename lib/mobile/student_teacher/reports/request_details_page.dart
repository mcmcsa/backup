import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';

class RequestDetailsPage extends StatefulWidget {
  final String trackingNumber;
  final String status;

  const RequestDetailsPage({
    super.key,
    required this.trackingNumber,
    required this.status,
  });

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  WorkRequest? _request;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    try {
      final request = await WorkRequestService.fetchById(widget.trackingNumber);
      if (mounted) setState(() { _request = request; });
    } catch (_) {
      if (mounted) setState(() { });
    }
  }

  int _getWorkflowStep() {
    if (_request == null) return 0;
    switch (_request!.status) {
      case 'pending': return 1;
      case 'approved': return 2;
      case 'in_progress': return 3;
      case 'under_maintenance': return 4;
      case 'completed': case 'done': return 6;
      case 'rework': return 3;
      default: return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFA5).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (_request?.status ?? widget.status).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TRACKING NUMBER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.trackingNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Location and Category Row
            Row(
              children: [
                Expanded(
                  child: _buildInfoBox(
                    icon: Icons.place_outlined,
                    label: 'LOCATION',
                    value1: _request?.officeRoom ?? 'N/A',
                    value2: _request?.buildingName ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoBox(
                    icon: Icons.category_outlined,
                    label: 'CATEGORY',
                    value1: _request?.typeOfRequest ?? 'N/A',
                    value2: _request?.priority ?? 'N/A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Problem Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Problem Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _request?.description ?? 'No description provided.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Assigned Users
                  Row(
                    children: [
                      _buildAvatar('assets/images/avatar1.png'),
                      Transform.translate(
                        offset: const Offset(-8, 0),
                        child: _buildAvatar('assets/images/avatar2.png'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // View Digital Form Link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.description,
                  size: 18,
                  color: Color(0xFF4169E1),
                ),
                label: const Text(
                  'View Digital Form',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4169E1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Progress Timeline
            const Text(
              'Progress Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 1 ? Icons.check_circle : Icons.circle_outlined,
              iconColor: _getWorkflowStep() >= 1 ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              title: 'Request Submitted',
              date: _request != null
                  ? _formatDate(_request!.dateSubmitted)
                  : 'Pending...',
              description: 'Logged via Mobile App',
              isCompleted: _getWorkflowStep() >= 1,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 2 ? Icons.check_circle : Icons.circle_outlined,
              iconColor: _getWorkflowStep() >= 2 ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              title: 'Request Approved',
              date: _getWorkflowStep() >= 2 ? 'Admin approved' : 'Waiting for approval',
              description: '',
              isCompleted: _getWorkflowStep() >= 2,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 3 ? Icons.check_circle : (_getWorkflowStep() == 2 ? Icons.circle : Icons.circle_outlined),
              iconColor: _getWorkflowStep() >= 3 ? const Color(0xFF4CAF50) : (_getWorkflowStep() == 2 ? const Color(0xFF2196F3) : Colors.grey.shade400),
              title: 'Maintenance Accepted',
              date: _request?.acceptedDate != null
                  ? _formatDate(_request!.acceptedDate!)
                  : 'Waiting...',
              description: _request?.acceptedByName ?? '',
              isCompleted: _getWorkflowStep() >= 3,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 4 ? Icons.check_circle : (_getWorkflowStep() == 3 ? Icons.circle : Icons.circle_outlined),
              iconColor: _getWorkflowStep() >= 4 ? const Color(0xFF4CAF50) : (_getWorkflowStep() == 3 ? const Color(0xFF2196F3) : Colors.grey.shade400),
              title: 'Pre-Inspection & Repair',
              date: _request?.maintenanceStartTime != null
                  ? 'Started ${_formatDate(_request!.maintenanceStartTime!)}'
                  : 'Not started',
              description: _getWorkflowStep() == 3 ? 'Pre-inspection in progress' : '',
              isCompleted: _getWorkflowStep() >= 4,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 5 ? Icons.check_circle : (_getWorkflowStep() == 4 ? Icons.circle : Icons.circle_outlined),
              iconColor: _getWorkflowStep() >= 5 ? const Color(0xFF4CAF50) : (_getWorkflowStep() == 4 ? Colors.orange : Colors.grey.shade400),
              title: 'Under Maintenance',
              date: _getWorkflowStep() >= 4 ? 'Work in progress' : 'Pending...',
              description: '',
              isCompleted: _getWorkflowStep() >= 5,
            ),
            _buildTimelineItem(
              icon: _getWorkflowStep() >= 6 ? Icons.check_circle : Icons.circle_outlined,
              iconColor: _getWorkflowStep() >= 6 ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              title: 'Resolution & Sign-off',
              date: _request?.maintenanceEndTime != null
                  ? _formatDate(_request!.maintenanceEndTime!)
                  : 'Pending...',
              description: _getWorkflowStep() >= 6 ? 'Completed' : '',
              isCompleted: _getWorkflowStep() >= 6,
              isLast: true,
            ),
            if (_request?.status == 'rework') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rework requested (${_request!.reworkCount} time${_request!.reworkCount > 1 ? 's' : ''})',
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Maintenance Office Contact Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.headset_mic,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maintenance Office',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'For corrections, assistance or safety concerns',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text(
                            'Call: 8422',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BFA5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.email, size: 18),
                          label: const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF00BFA5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value1,
    required String value2,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF00BFA5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value2,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String imagePath) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: Icon(
          Icons.person,
          size: 18,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required String description,
    String? subtitle,
    bool isCompleted = false,
    bool isLast = false,
    bool showActions = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4169E1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 16,
                        color: Color(0xFF4169E1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.phone, size: 18),
                      color: const Color(0xFF2196F3),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.message, size: 18),
                      color: const Color(0xFF2196F3),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour:$minute $period';
  }
}
