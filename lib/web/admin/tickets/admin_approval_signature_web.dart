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
import '../../../../shared/services/maintenance_account_service.dart';
import '../../../../shared/widgets/availability_status_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/admin_styles.dart';
import '../../../shared/services/collaboration_service.dart';

class AdminApprovalSignatureWeb extends StatefulWidget {
  final WorkRequest request;

  const AdminApprovalSignatureWeb({
    super.key,
    required this.request,
  });

  @override
  State<AdminApprovalSignatureWeb> createState() => _AdminApprovalSignatureWebState();
}

class _AdminApprovalSignatureWebState extends State<AdminApprovalSignatureWeb> {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isApproved = false;
  List<ESignature> _signatures = [];
  List<MaintenanceAccount> _maintenanceStaff = [];
  final List<String> _selectedMaintenanceIds = [];
  String? _maintenanceError;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _isApproved = widget.request.status != 'pending';
    _setupRealtime();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:maintenance_users')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'maintenance_users',
          callback: (payload) {
            final updatedRecord = payload.newRecord;
            final userId = updatedRecord['user_id'] as String?;
            final newStatus = updatedRecord['availability_status'] as String?;
            if (userId != null && newStatus != null) {
              setState(() {
                final index = _maintenanceStaff.indexWhere((m) => m.userId == userId);
                if (index != -1) {
                  final old = _maintenanceStaff[index];
                  _maintenanceStaff[index] = MaintenanceAccount(
                    userId: old.userId,
                    email: old.email,
                    fullName: old.fullName,
                    employeeId: old.employeeId,
                    specialization: old.specialization,
                    contactNo: old.contactNo,
                    isActive: old.isActive,
                    archivedAt: old.archivedAt,
                    createdAt: old.createdAt,
                    availabilityStatus: newStatus,
                    currentLocation: old.currentLocation,
                    currentAssignmentId: old.currentAssignmentId,
                    estimatedCompletionTime: old.estimatedCompletionTime,
                    lastActiveAt: old.lastActiveAt,
                    workingHoursStart: old.workingHoursStart,
                    workingHoursEnd: old.workingHoursEnd,
                    statusUpdatedAt: old.statusUpdatedAt,
                  );
                }
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_realtimeChannel!);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ESignatureService.fetchByWorkRequest(widget.request.id),
        MaintenanceAccountService.fetchAllActiveMaintenance(),
      ]);

      if (mounted) {
        setState(() {
          _signatures = results[0] as List<ESignature>;
          _maintenanceStaff = results[1] as List<MaintenanceAccount>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC PORTED FROM MOBILE ---

  Future<void> _approveWithSignature(String base64Signature) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    if (_selectedMaintenanceIds.isEmpty) {
      setState(() => _maintenanceError = 'Please select at least one maintenance staff to assign');
      _showError('Please assign a maintenance staff member first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _maintenanceError = null;
    });

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

      // Assign the work request to the primary maintenance staff
      final primaryId = _selectedMaintenanceIds.first;
      await WorkRequestService.assignTo(widget.request.id, primaryId);
      
      // Invite secondary collaborators
      for (int i = 1; i < _selectedMaintenanceIds.length; i++) {
        await CollaborationService.inviteCollaborator(
          widget.request.id,
          _selectedMaintenanceIds[i],
          'secondary',
          user.id,
        );
      }

      await AppNotificationService.notifyApprovedToMaintenance(
        workRequestId: widget.request.id,
        adminName: user.name,
        assignedMaintenanceId: primaryId,
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
          _isProcessing = false;
        });
        _showSuccess('Work request approved successfully!');
        _loadData(); // Refresh signatures
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }

  // --- UI BUILDING REDESIGNED FOR WEB ---

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminStyles.bg,
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AdminStyles.primary),
                  )
                : _isProcessing
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AdminStyles.primary,
                        ),
                      )
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Sticky Context
                                  SizedBox(
                                    width: 400,
                                    child: _buildDetailsColumn(),
                                  ),
                                  const SizedBox(width: 40),
                                  // Right Column: Professional Flow
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildSignatureFlow(),
                                        const SizedBox(height: 100),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: AdminStyles.glassDecoration(
        color: Colors.white,
        opacity: 1.0,
        borderRadius: 0,
        hasBorder: false,
      ).copyWith(
        border: Border(bottom: BorderSide(color: AdminStyles.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context, _isApproved),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AdminStyles.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AdminStyles.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workflow Phase',
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                'EXECUTIVE APPROVAL',
                style: AdminStyles.headingStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Spacer(),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildDetailsColumn() {
    return Column(
      children: [
        _buildInfoCard('Information', [
          _buildSummaryRow('Tracking #', widget.request.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Type', widget.request.typeOfRequest),
          _buildSummaryRow('Priority', widget.request.priorityLabel),
          _buildSummaryRow('Submitted', _formatDate(widget.request.dateSubmitted)),
        ]),
        const SizedBox(height: 24),
        _buildInfoCard('Location', [
          _buildSummaryRow('Building', widget.request.buildingName ?? 'N/A'),
          _buildSummaryRow('Room', widget.request.officeRoom ?? 'N/A'),
          _buildSummaryRow('Department', widget.request.department ?? 'N/A'),
        ]),
        const SizedBox(height: 24),
        if (_signatures.isNotEmpty) _buildSignaturesListCard(),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AdminStyles.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: AdminStyles.dataStyle(fontSize: 13, color: AdminStyles.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSignaturesListCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signatures Captured', style: AdminStyles.headingStyle(fontSize: 14, color: AdminStyles.textSecondary)),
          const SizedBox(height: 16),
          ..._signatures.map((sig) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AdminStyles.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_rounded, size: 16, color: AdminStyles.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sig.signerName, style: AdminStyles.headingStyle(fontSize: 13)),
                      Text('${sig.signatureTypeLabel} • ${_formatDate(sig.signedAt)}', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
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

  Widget _buildSignatureFlow() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: AdminStyles.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Issue Overview', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AdminStyles.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AdminStyles.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.request.title, style: AdminStyles.headingStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Text(widget.request.description, style: AdminStyles.bodyStyle(fontSize: 14, height: 1.6, color: AdminStyles.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (!_isApproved) ...[
                Text('Maintenance Assignment', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Text('Assign this ticket to an active maintenance staff member.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AdminStyles.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _maintenanceError != null ? AdminStyles.error : AdminStyles.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedMaintenanceIds.map((id) {
                          final staff = _maintenanceStaff.firstWhere((m) => m.userId == id);
                          final isPrimary = _selectedMaintenanceIds.indexOf(id) == 0;
                          return Chip(
                            backgroundColor: isPrimary ? AdminStyles.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                            side: BorderSide(color: isPrimary ? AdminStyles.primary.withValues(alpha: 0.3) : Colors.grey.shade300),
                            label: Text(
                              '${staff.fullName} ${isPrimary ? "(Primary)" : "(Secondary)"}',
                              style: AdminStyles.bodyStyle(fontSize: 13, color: isPrimary ? AdminStyles.primary : Colors.black87),
                            ),
                            onDeleted: () {
                              setState(() => _selectedMaintenanceIds.remove(id));
                            },
                          );
                        }).toList(),
                      ),
                      if (_selectedMaintenanceIds.isNotEmpty) const SizedBox(height: 12),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: null,
                          hint: Text('Select maintenance staff to add', style: AdminStyles.bodyStyle(color: Colors.grey)),
                          items: _maintenanceStaff.where((staff) => !_selectedMaintenanceIds.contains(staff.userId)).map((staff) {
                            return DropdownMenuItem<String>(
                              value: staff.userId,
                              child: Row(
                                children: [
                                  AvailabilityStatusBadge(
                                    status: staff.availabilityStatus,
                                    size: BadgeSize.small,
                                    showLabel: false,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${staff.fullName} (${staff.specialization ?? "General"})',
                                    style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMaintenanceIds.add(val);
                                _maintenanceError = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_maintenanceError != null) ...[
                  const SizedBox(height: 8),
                  Text(_maintenanceError!, style: AdminStyles.bodyStyle(color: AdminStyles.error, fontSize: 12)),
                ],
                const SizedBox(height: 40),
                Text('E-Signature Approval', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Text('As an administrator, please sign below to formally approve this maintenance work request.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                const SizedBox(height: 24),
                SignaturePadWidget(
                  title: 'Admin Approval Signature',
                  subtitle: 'Use your mouse or touch device to sign',
                  height: 250,
                  onSignatureComplete: _approveWithSignature,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AdminStyles.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminStyles.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AdminStyles.success, size: 48),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Request Approved', style: AdminStyles.headingStyle(fontSize: 20, color: AdminStyles.success)),
                            const SizedBox(height: 8),
                            Text('This work request has been formally approved and scheduled for maintenance.', style: AdminStyles.bodyStyle(fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = widget.request.status;
    Color color = AdminStyles.warning;
    if (status == 'pending') color = AdminStyles.warning;
    if (status == 'approved' || status == 'under_maintenance') color = AdminStyles.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  // --- HELPERS ---

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
