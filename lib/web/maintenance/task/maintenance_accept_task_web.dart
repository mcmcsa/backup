import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/connectivity_service.dart';
import '../../../shared/services/offline_sync_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../admin/shared/admin_styles.dart';
class MaintenanceAcceptTaskWeb extends StatefulWidget {
  final WorkRequest task;

  const MaintenanceAcceptTaskWeb({super.key, required this.task});

  @override
  State<MaintenanceAcceptTaskWeb> createState() => _MaintenanceAcceptTaskWebState();
}

class _MaintenanceAcceptTaskWebState extends State<MaintenanceAcceptTaskWeb> {
  bool _isAccepting = false;

  // --- LOGIC PORTED FROM MOBILE ---

  Future<void> _handleAcceptance(String signatureData) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isAccepting = true);

    try {
      final isOnline = await Provider.of<ConnectivityService>(context, listen: false).checkConnectivity();
      
      if (!isOnline) {
        // Queue for later
        final payload = {
          'workRequestId': widget.task.id,
          'signerId': user.id,
          'signerName': user.name,
          'signatureData': signatureData,
          'adminId': widget.task.approvedById,
          'requestorId': widget.task.requestorId,
        };
        await OfflineSyncService().queueAction('accept_work_request', payload);
        if (mounted) {
          _showSuccess('You are offline. Task acceptance has been queued and will sync when reconnected.');
          Navigator.pop(context, true);
        }
        return;
      }

      // 1. Save drawn signature
      final signature = ESignature(
        id: '',
        workRequestId: widget.task.id,
        signerId: user.id,
        signerName: user.name,
        signerRole: 'maintenance',
        signatureType: 'acceptance',
        signatureData: signatureData,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      // 2. Update work request status
      await WorkRequestService.acceptByMaintenance(
        widget.task.id,
        user.id,
        user.name,
      );

      // 3. Notify parties
      await AppNotificationService.notifyAcceptedToAdminAndRequestor(
        workRequestId: widget.task.id,
        maintenanceName: user.name,
        adminId: widget.task.approvedById,
        requestorId: widget.task.requestorId,
      );

      if (mounted) {
        _showSuccess('Task accepted successfully. You can now begin the maintenance work.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        _showError('Failed to accept task: $e');
      }
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isAccepting
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Task Details
                            Expanded(flex: 4, child: _buildTaskSummary()),
                            const SizedBox(width: 32),
                            // Right: Signature Area
                            Expanded(flex: 6, child: _buildSignatureSection()),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AdminStyles.surface,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AdminStyles.border))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Text('Task Acceptance', style: AdminStyles.headingStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildTaskSummary() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Task Information', style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textSecondary)),
              const SizedBox(height: 24),
              _buildInfoRow('ID', widget.task.id.substring(0, 8).toUpperCase()),
              _buildInfoRow('Title', widget.task.title),
              _buildInfoRow('Location', widget.task.officeRoom ?? '-'),
              _buildInfoRow('Priority', widget.task.priorityLabel),
              const Divider(height: 32),
              Text('Expected Work', style: AdminStyles.headingStyle(fontSize: 12, color: AdminStyles.textMuted)),
              const SizedBox(height: 8),
              Text(widget.task.description, style: AdminStyles.bodyStyle(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminStyles.bodyStyle(fontSize: 13)),
          Flexible(child: Text(value, style: AdminStyles.dataStyle(fontSize: 13), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirmation Signature', style: AdminStyles.headingStyle(fontSize: 18)),
          const SizedBox(height: 12),
          Text('By signing below, you acknowledge the task details and formally accept the assignment.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
          const SizedBox(height: 32),
          SignaturePadWidget(
            title: 'Maintenance Signature',
            subtitle: 'Draw your signature to accept task',
            onSignatureComplete: _handleAcceptance,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AdminStyles.textMuted),
              const SizedBox(width: 8),
              Expanded(child: Text('Note: Acceptance will be recorded and logged for tracking.', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted))),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));
}
