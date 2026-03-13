import 'package:flutter/material.dart';

class SystemWorkflowPage extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const SystemWorkflowPage({super.key, this.scaffoldKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'System workflow',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Introduction
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Follow these simple steps to report and track maintenance requests in the PSU Maintenance System.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Workflow Steps
          _buildWorkflowStep(
            stepNumber: 1,
            title: 'Scan or Report',
            description: 'Scan a room QR code or manually enter room details to report an issue.',
            icon: Icons.qr_code_scanner,
            iconColor: const Color(0xFF00BFA5),
          ),
          const SizedBox(height: 16),
          _buildWorkflowStep(
            stepNumber: 2,
            title: 'Describe the Issue',
            description: 'Provide details about the maintenance issue, add photos, and select the category.',
            icon: Icons.description,
            iconColor: Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildWorkflowStep(
            stepNumber: 3,
            title: 'Submit Request',
            description: 'Submit your request and receive a tracking number for future reference.',
            icon: Icons.send,
            iconColor: Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildWorkflowStep(
            stepNumber: 4,
            title: 'Admin Review',
            description: 'Admin reviews your request and assigns it to the appropriate maintenance staff.',
            icon: Icons.person_search,
            iconColor: Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildWorkflowStep(
            stepNumber: 5,
            title: 'Staff Action',
            description: 'Maintenance staff receives the assignment and works on resolving the issue.',
            icon: Icons.engineering,
            iconColor: Colors.cyan,
          ),
          const SizedBox(height: 16),
          _buildWorkflowStep(
            stepNumber: 6,
            title: 'Track Progress',
            description: 'Monitor the status of your request in real-time through the Reports section.',
            icon: Icons.track_changes,
            iconColor: Colors.indigo,
          ),
          const SizedBox(height: 16),
          _buildWorkflowStep(
            stepNumber: 7,
            title: 'Resolution',
            description: 'Receive notification when the issue is resolved and review the outcome.',
            icon: Icons.check_circle,
            iconColor: Colors.green,
          ),
          const SizedBox(height: 20),

          // Request Status Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Status Types',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusInfo(
                  'PENDING',
                  'Request submitted and awaiting review',
                  const Color(0xFF00BFA5),
                ),
                const SizedBox(height: 12),
                _buildStatusInfo(
                  'IN PROGRESS',
                  'Request assigned and work is ongoing',
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildStatusInfo(
                  'COMPLETED',
                  'Issue has been resolved successfully',
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildStatusInfo(
                  'DECLINED',
                  'Request was reviewed but not approved',
                  Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tips Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: const Color(0xFF00BFA5), size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Tips for Better Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipItem('Provide clear and detailed descriptions'),
                _buildTipItem('Include photos when possible'),
                _buildTipItem('Use the correct category for your issue'),
                _buildTipItem('Keep your tracking number for reference'),
                _buildTipItem('Check the Reports tab for updates'),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(String status, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            size: 18,
            color: Color(0xFF00BFA5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
