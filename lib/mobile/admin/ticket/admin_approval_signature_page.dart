import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/widgets/workflow_status_badge.dart';

/// Admin screen to review a work request and sign E-signature for approval
class AdminApprovalSignaturePage extends StatefulWidget {
  final WorkRequest request;

  const AdminApprovalSignaturePage({super.key, required this.request});

  @override
  State<AdminApprovalSignaturePage> createState() => _AdminApprovalSignaturePageState();
}

class _AdminApprovalSignaturePageState extends State<AdminApprovalSignaturePage> {
  bool _isLoading = false;
  bool _isApproved = false;
  List<ESignature> _signatures = [];

  @override
  void initState() {
    super.initState();
    _loadSignatures();
    _isApproved = widget.request.status != 'pending';
  }

  Future<void> _loadSignatures() async {
    final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
    if (mounted) {
      setState(() => _signatures = sigs);
    }
  }

  Future<void> _approveWithSignature(String base64Signature) async {
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
        signerRole: 'admin',
        signatureType: 'approval',
        signatureData: base64Signature,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      // Update work request status to approved
      await WorkRequestService.approveRequest(
        widget.request.id,
        user.id,
        user.name,
      );

      if (mounted) {
        setState(() {
          _isApproved = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work request approved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        // Refresh signatures
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
          onPressed: () => Navigator.pop(context, _isApproved),
        ),
        title: const Text(
          'Work Request Approval',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status & Tracking
                _buildTrackingCard(),
                const SizedBox(height: 16),

                // Request details
                _buildDetailsCard(),
                const SizedBox(height: 16),

                // Location
                _buildLocationCard(),
                const SizedBox(height: 16),

                // Issue description
                _buildDescriptionCard(),
                const SizedBox(height: 16),

                // Requestor info
                _buildRequestorCard(),
                const SizedBox(height: 16),

                // Existing signatures
                if (_signatures.isNotEmpty) ...[
                  _buildSignaturesCard(),
                  const SizedBox(height: 16),
                ],

                // Approval action
                if (!_isApproved) ...[
                  const Text(
                    'ADMIN APPROVAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SignaturePadWidget(
                    title: 'E-Signature for Approval',
                    subtitle: 'Sign below to approve this work request',
                    onSignatureComplete: _approveWithSignature,
                  ),
                ] else ...[
                  _buildApprovedBanner(),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildTrackingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4169E1), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TRACKING NUMBER',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(widget.request.id,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
          WorkflowStatusBadge(status: widget.request.status),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
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
          const Text('REQUEST DETAILS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _buildInfoRow('Title', widget.request.title),
          _buildInfoRow('Type', widget.request.typeOfRequest),
          _buildInfoRow('Priority', widget.request.priorityLabel),
          _buildInfoRow('Date Submitted', _formatDate(widget.request.dateSubmitted)),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
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
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF4169E1)),
              const SizedBox(width: 8),
              Text('LOCATION',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Campus', widget.request.campus),
          _buildInfoRow('Building', widget.request.buildingName),
          _buildInfoRow('Room', widget.request.officeRoom),
          _buildInfoRow('Department', widget.request.department),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
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
          const Text('ISSUE DESCRIPTION',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Text(widget.request.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildRequestorCard() {
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
          const Text('REQUESTOR INFO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          _buildInfoRow('Name', widget.request.requestorName),
          _buildInfoRow('Position', widget.request.requestorPosition),
          _buildInfoRow('Reported By', widget.request.reportedBy),
        ],
      ),
    );
  }

  Widget _buildSignaturesCard() {
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
          const Text('SIGNATURES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ..._signatures.map((sig) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4169E1).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 16, color: Color(0xFF4169E1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sig.signerName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                          Text('${sig.signatureTypeLabel} • ${_formatDate(sig.signedAt)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildApprovedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Approved',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                const SizedBox(height: 4),
                Text(
                  widget.request.approvedBy != null
                      ? 'Approved by ${widget.request.approvedBy} on ${_formatDate(widget.request.approvedDate ?? DateTime.now())}'
                      : 'This request has been approved',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}
