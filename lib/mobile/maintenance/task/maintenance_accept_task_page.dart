import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/widgets/workflow_status_badge.dart';

/// Maintenance screen to accept a work request with E-signature
class MaintenanceAcceptTaskPage extends StatefulWidget {
  final WorkRequest request;

  const MaintenanceAcceptTaskPage({super.key, required this.request});

  @override
  State<MaintenanceAcceptTaskPage> createState() => _MaintenanceAcceptTaskPageState();
}

class _MaintenanceAcceptTaskPageState extends State<MaintenanceAcceptTaskPage> {
  bool _isLoading = false;
  bool _isAccepted = false;
  List<ESignature> _signatures = [];

  @override
  void initState() {
    super.initState();
    _loadSignatures();
    _isAccepted = widget.request.acceptedById != null;
  }

  Future<void> _loadSignatures() async {
    final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
    if (mounted) setState(() => _signatures = sigs);
  }

  Future<void> _acceptWithSignature(String base64Signature) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Save e-signature
      final signature = ESignature(
        id: '',
        workRequestId: widget.request.id,
        signerId: user.id,
        signerName: user.name,
        signerRole: 'maintenance',
        signatureType: 'acceptance',
        signatureData: base64Signature,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      // Accept the work request
      await WorkRequestService.acceptByMaintenance(
        widget.request.id,
        user.id,
        user.name,
      );

      if (mounted) {
        setState(() {
          _isAccepted = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work request accepted! You can now proceed with pre-inspection.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _loadSignatures();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
          onPressed: () => Navigator.pop(context, _isAccepted),
        ),
        title: const Text('Accept Work Request',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Request overview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4169E1), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(widget.request.id,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4169E1))),
                          WorkflowStatusBadge(status: widget.request.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.request.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${widget.request.buildingName} • ${widget.request.officeRoom}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Request details
                _buildSection('REQUEST DETAILS', [
                  _buildInfoRow('Type', widget.request.typeOfRequest),
                  _buildInfoRow('Priority', widget.request.priorityLabel),
                  _buildInfoRow('Campus', widget.request.campus),
                  _buildInfoRow('Department', widget.request.department),
                  _buildInfoRow('Requestor', widget.request.requestorName),
                ]),
                const SizedBox(height: 16),

                // Issue description
                _buildSection('ISSUE DESCRIPTION', [
                  Text(widget.request.description,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
                ]),
                const SizedBox(height: 16),

                // Admin approval info
                if (widget.request.approvedBy != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Color(0xFF059669), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin Approved',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              const SizedBox(height: 4),
                              Text('Approved by ${widget.request.approvedBy}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Signatures
                if (_signatures.isNotEmpty) ...[
                  _buildSection('SIGNATURES', [
                    ..._signatures.map((sig) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4169E1).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 14, color: Color(0xFF4169E1)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sig.signerName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    Text(sig.signatureTypeLabel,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Accept with signature
                if (!_isAccepted && widget.request.status == 'approved') ...[
                  const Text('ACCEPT THIS TASK',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  const Text('By signing below, you accept this work request and will proceed with pre-inspection.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 12),
                  SignaturePadWidget(
                    title: 'E-Signature to Accept',
                    subtitle: 'Sign to confirm acceptance of this task',
                    onSignatureComplete: _acceptWithSignature,
                  ),
                ] else if (_isAccepted) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF4169E1), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('You have accepted this task. Proceed to Pre-Inspection.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4169E1))),
                        ),
                      ],
                    ),
                  ),
                ] else if (widget.request.status == 'pending') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.hourglass_empty, color: Color(0xFFD97706), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Waiting for admin approval before you can accept.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }
}
