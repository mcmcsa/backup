import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

/// Admin screen to review a work request and sign E-signature for approval
class AdminApprovalSignaturePage extends StatefulWidget {
  final WorkRequest request;

  const AdminApprovalSignaturePage({super.key, required this.request});

  @override
  State<AdminApprovalSignaturePage> createState() =>
      _AdminApprovalSignaturePageState();
}

class _AdminApprovalSignaturePageState
    extends State<AdminApprovalSignaturePage> {
  bool _isLoading = false;
  bool _isApproved = false;
  List<ESignature> _signatures = [];
  String _selectedPriority = 'medium';
  String _selectedDuration = '2 Hours';
  String? _pendingSignatureBase64;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
    _isApproved = widget.request.status != 'Pending';
    if (widget.request.priority.isNotEmpty) {
      _selectedPriority = widget.request.priority;
    }
  }

  Future<void> _loadSignatures() async {
    final sigs = await ESignatureService.fetchByWorkRequest(widget.request.id);
    if (mounted) {
      setState(() => _signatures = sigs);
    }
  }

  void _openSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Admin E-Signature',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SignaturePadWidget(
                  title: '',
                  subtitle: '',
                  height: 200,
                  onSignatureComplete: (base64) {
                    if (base64.isNotEmpty) {
                      setState(() {
                        _pendingSignatureBase64 = base64;
                      });
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveWithSignature() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    if (_pendingSignatureBase64 == null || _pendingSignatureBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your signature first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final signature = ESignature(
        id: '',
        workRequestId: widget.request.id,
        signerId: user.id,
        signerName: user.name,
        signerRole: 'admin',
        signatureType: 'approval',
        signatureData: _pendingSignatureBase64!,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      await WorkRequestService.approveRequest(
        widget.request.id,
        user.id,
        user.name,
        priority: _selectedPriority,
        estimatedDuration: _selectedDuration,
      );

      await AppNotificationService.notifyApprovedToMaintenance(
        workRequestId: widget.request.id,
        adminName: user.name,
        assignedMaintenanceId: widget.request.assignedToId,
      );

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Approved Request',
        details: 'Approved work request for ${widget.request.officeRoom}',
        workRequestId: widget.request.id,
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
    final requestorName = widget.request.requestorName.isNotEmpty
        ? widget.request.requestorName
        : (widget.request.reportedByName ?? 'Requestor');

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
          'Executive Approval',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4169E1)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Information Card
                _buildCardContainer(
                  title: 'INFORMATION',
                  children: [
                    _buildInfoRow('Tracking #', widget.request.id.substring(0, 8).toUpperCase()),
                    _buildInfoRow('Request Type', widget.request.typeOfRequest.replaceAll('_', ' ').toUpperCase()),
                    _buildInfoRow('Requestor', requestorName),
                    _buildInfoRow('Priority Level', _isApproved ? widget.request.priorityLabel : '--'),
                    _buildInfoRow('Submitted Date', _formatDate(widget.request.dateSubmitted)),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Location Card
                _buildCardContainer(
                  title: 'LOCATION',
                  children: [
                    _buildInfoRow('Building', widget.request.buildingName ?? 'Main Building'),
                    _buildInfoRow('Room / Facility', widget.request.officeRoom ?? 'N/A'),
                    _buildInfoRow('Department', widget.request.department ?? 'General Services'),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Signatures Captured Card
                _buildSignaturesCapturedCard(),
                const SizedBox(height: 20),

                // Approval Form Flow
                if (!_isApproved) ...[
                  // Priority Selection
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 1 — Priority Level',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['low', 'medium', 'high'].map((p) {
                            final isSel = _selectedPriority == p;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: ChoiceChip(
                                  label: Text(p.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.black87)),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF4169E1),
                                  onSelected: (_) => setState(() => _selectedPriority = p),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Step 2 — Target Duration',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedDuration,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: ['1 Hour', '2 Hours', '4 Hours', '1 Day', '2 Days', '1 Week']
                              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedDuration = v ?? '2 Hours'),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Step 3 — E-Signature',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openSignatureDialog,
                              icon: const Icon(Icons.draw_rounded, size: 18),
                              label: Text(_pendingSignatureBase64 != null ? 'Change Signature' : 'Signature'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _pendingSignatureBase64 != null ? const Color(0xFF4169E1).withValues(alpha: 0.1) : const Color(0xFF4169E1),
                                foregroundColor: _pendingSignatureBase64 != null ? const Color(0xFF4169E1) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            if (_pendingSignatureBase64 != null) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.verified, color: Color(0xFF059669), size: 20),
                              const SizedBox(width: 4),
                              const Text('Confirmed', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _approveWithSignature,
                            icon: const Icon(Icons.check_circle, size: 20),
                            label: const Text('Work Request Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4169E1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildApprovedBanner(),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildCardContainer({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSignaturesCapturedCard() {
    final list = <Widget>[];

    final reqName = widget.request.requestorName.isNotEmpty
        ? widget.request.requestorName
        : (widget.request.reportedByName ?? '');

    final hasReqSig = _signatures.any((s) => s.signerRole == 'requestor' || s.signerRole == 'teacher' || s.signatureType == 'request');

    if (!hasReqSig && reqName.isNotEmpty) {
      list.add(_buildSignatureItem(reqName, 'Requestor', widget.request.dateSubmitted));
    }

    final displaySigs = List<ESignature>.from(_signatures);
    if (_pendingSignatureBase64 != null && !displaySigs.any((s) => s.signerRole == 'admin' || s.signatureType == 'approval')) {
      displaySigs.add(
        ESignature(
          id: 'temp',
          workRequestId: widget.request.id,
          signerId: '',
          signerName: 'Campus Administrator',
          signerRole: 'admin',
          signatureType: 'approval',
          signatureData: _pendingSignatureBase64!,
          signedAt: DateTime.now(),
        ),
      );
    }

    for (final sig in displaySigs) {
      String label = sig.signatureTypeLabel;
      if (sig.signerRole == 'requestor' || sig.signerRole == 'teacher' || sig.signatureType == 'request') {
        label = 'Requestor';
      } else if (sig.signerRole == 'admin' || sig.signatureType == 'approval') {
        label = 'Admin Approval';
      } else if (sig.signerRole == 'maintenance' || sig.signatureType == 'post_repair' || sig.signatureType == 'acceptance') {
        label = 'Maintenance';
      }
      list.add(_buildSignatureItem(sig.signerName, label, sig.signedAt));
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return _buildCardContainer(title: 'SIGNATURES CAPTURED', children: list);
  }

  Widget _buildSignatureItem(String name, String label, DateTime date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF4169E1).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.verified, size: 14, color: Color(0xFF4169E1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('$label • ${_formatDate(date)}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approved',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.request.approvedBy != null
                      ? 'Approved by ${widget.request.approvedBy} on ${_formatDate(widget.request.approvedDate ?? DateTime.now())}'
                      : 'This request has been approved',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}
