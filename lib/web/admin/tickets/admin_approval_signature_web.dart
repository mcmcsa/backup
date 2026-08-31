import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final VoidCallback? onBack;

  const AdminApprovalSignatureWeb({
    super.key,
    required this.request,
    this.onBack,
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
  String _selectedPriority = ''; // Admin must set this before signing
  String _selectedDuration = '2 Hours';
  final TextEditingController _customDurationController = TextEditingController();
  String? _durationError;
  String? _maintenanceError;
  String? _priorityError;
  String? _pendingSignatureBase64;
  String? _signatureError;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _isApproved = widget.request.status != 'Pending';
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

  Future<void> _approveWithSignature() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    if (_selectedPriority.isEmpty) {
      setState(() => _priorityError = 'Please set a priority level before approving.');
      _showError('Please set the priority level first.');
      return;
    }

    final finalDuration = _customDurationController.text.trim().isNotEmpty
        ? _customDurationController.text.trim()
        : _selectedDuration;

    if (finalDuration.isEmpty) {
      setState(() => _durationError = 'Please set the estimated target duration before approving.');
      _showError('Please set the estimated duration first.');
      return;
    }

    if (_selectedMaintenanceIds.isEmpty) {
      setState(() => _maintenanceError = 'Please select at least one maintenance staff to assign');
      _showError('Please assign a maintenance staff member first.');
      return;
    }

    if (_pendingSignatureBase64 == null || _pendingSignatureBase64!.isEmpty) {
      setState(() => _signatureError = 'Please add your signature before approving.');
      _showError('Please add your signature first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _maintenanceError = null;
      _priorityError = null;
      _durationError = null;
      _signatureError = null;
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
        signatureData: _pendingSignatureBase64!,
        signedAt: DateTime.now(),
      );
      await ESignatureService.insert(signature);

      // Update work request status to approved, save admin-set priority and estimated duration
      await WorkRequestService.approveRequest(
        widget.request.id,
        user.id,
        user.name,
        priority: _selectedPriority,
        estimatedDuration: finalDuration,
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
                               child: LayoutBuilder(
                                 builder: (context, constraints) {
                                   final isMobile = constraints.maxWidth < 900;
                                   if (isMobile) {
                                     return Column(
                                       children: [
                                         _buildDetailsColumn(),
                                         const SizedBox(height: 24),
                                         _buildSignatureFlow(),
                                         const SizedBox(height: 60),
                                       ],
                                     );
                                   }
                                   return Row(
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
                                   );
                                 },
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
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context, _isApproved);
                }
              },
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
    final requestor = widget.request.requestorName.isNotEmpty
        ? widget.request.requestorName
        : (widget.request.reportedByName ?? 'N/A');
    final priorityDisplay = widget.request.status.toLowerCase() == 'pending'
        ? (_selectedPriority.isNotEmpty ? _selectedPriority.toUpperCase() : '--')
        : widget.request.priorityLabel;

    return Column(
      children: [
        _buildInfoCard('Information', [
          _buildSummaryRow('Tracking #', widget.request.id.substring(0, 8).toUpperCase()),
          _buildSummaryRow('Type', widget.request.typeDisplay),
          _buildSummaryRow('Requestor', requestor),
          _buildSummaryRow('Priority Level', priorityDisplay),
          _buildSummaryRow('Submitted', DateFormat('MMM dd, yyyy · HH:mm').format(widget.request.dateSubmitted)),
        ]),
        const SizedBox(height: 24),
        _buildInfoCard('Location', [
          _buildSummaryRow('Building', widget.request.buildingName ?? 'N/A'),
          _buildSummaryRow('Room', widget.request.officeRoom ?? widget.request.roomName ?? 'N/A'),
          _buildSummaryRow('Department', widget.request.departmentName ?? widget.request.department ?? 'N/A'),
        ]),
        if (_signatures.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSignaturesListCard(),
        ],
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
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    final list = <Widget>[];

    final reqName = widget.request.requestorName.isNotEmpty
        ? widget.request.requestorName
        : (widget.request.reportedByName ?? '');

    final hasReqSig = _signatures.any((s) => s.signerRole == 'requestor' || s.signerRole == 'teacher' || s.signatureType == 'request');

    if (!hasReqSig && reqName.isNotEmpty) {
      list.add(
        _buildSignatureItemRow(
          signerName: reqName,
          label: 'Requestor',
          date: widget.request.dateSubmitted,
        ),
      );
    }

    final displaySignatures = List<ESignature>.from(_signatures);

    if (_pendingSignatureBase64 != null &&
        !displaySignatures.any((s) => s.signerRole == 'admin' || s.signatureType == 'approval')) {
      displaySignatures.add(
        ESignature(
          id: 'temp',
          workRequestId: widget.request.id,
          signerId: user?.id ?? '',
          signerName: user?.name ?? 'Campus Administrator',
          signerRole: 'admin',
          signatureType: 'approval',
          signatureData: _pendingSignatureBase64!,
          signedAt: DateTime.now(),
        ),
      );
    }

    for (final sig in displaySignatures) {
      String label = sig.signatureTypeLabel;
      if (sig.signerRole == 'requestor' || sig.signerRole == 'teacher' || sig.signatureType == 'request') {
        label = 'Requestor';
      } else if (sig.signerRole == 'admin' || sig.signatureType == 'approval') {
        label = 'Admin Approval';
      } else if (sig.signerRole == 'maintenance' || sig.signatureType == 'post_repair' || sig.signatureType == 'acceptance') {
        label = 'Maintenance';
      }

      list.add(
        _buildSignatureItemRow(
          signerName: sig.signerName,
          label: label,
          date: sig.signedAt,
        ),
      );
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIGNATURES CAPTURED',
            style: AdminStyles.headingStyle(fontSize: 10, color: AdminStyles.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 18),
          ...list,
        ],
      ),
    );
  }

  Widget _buildSignatureItemRow({
    required String signerName,
    required String label,
    required DateTime date,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                Text(
                  signerName,
                  style: AdminStyles.headingStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$label • ${DateFormat('MMM dd, yyyy · HH:mm').format(date)}',
                  style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                ),
              ],
            ),
          ),
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
                // ── Step 1: Priority Level ──────────────────────────────────
                Text('Step 1 — Set Priority Level', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'As the Campus Admin, set the urgency level of this request before approving.',
                  style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, priorityConstraints) {
                    final stackPriority = priorityConstraints.maxWidth < 500;
                    
                    final cardsList = ['low', 'medium', 'high'].map((level) {
                      final isSelected = _selectedPriority == level;
                      final color = level == 'high'
                          ? AdminStyles.error
                          : level == 'medium'
                              ? AdminStyles.warning
                              : AdminStyles.success;
                      final icon = level == 'high'
                          ? Icons.priority_high_rounded
                          : level == 'medium'
                              ? Icons.remove_rounded
                              : Icons.arrow_downward_rounded;

                      final card = GestureDetector(
                        onTap: () => setState(() {
                          _selectedPriority = level;
                          _priorityError = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.12) : AdminStyles.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? color : AdminStyles.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(icon, color: isSelected ? color : AdminStyles.textMuted, size: 24),
                              const SizedBox(height: 8),
                              Text(
                                level.toUpperCase(),
                                style: AdminStyles.headingStyle(
                                  fontSize: 13,
                                  color: isSelected ? color : AdminStyles.textMuted,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (stackPriority) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        );
                      }
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: card,
                        ),
                      );
                    }).toList();

                    if (stackPriority) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: cardsList,
                      );
                    }

                    return Row(
                      children: cardsList,
                    );
                  },
                ),
                if (_priorityError != null) ...[
                  const SizedBox(height: 8),
                  Text(_priorityError!, style: AdminStyles.bodyStyle(color: AdminStyles.error, fontSize: 12)),
                ],
                const SizedBox(height: 40),
                // ── Step 2: Target Duration ─────────────────────────────────
                Text('Step 2 — Set Target Duration', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(
                  'As Campus Admin, set the estimated completion duration for this maintenance request.',
                  style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    '1 Hour', '2 Hours', '4 Hours', '8 Hours',
                    '1 Day', '2 Days', '3 Days', '1 Week',
                  ].map((dur) {
                    final isSelected = _selectedDuration == dur && _customDurationController.text.trim().isEmpty;
                    return ChoiceChip(
                      label: Text(dur),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDuration = dur;
                            _customDurationController.clear();
                            _durationError = null;
                          });
                        }
                      },
                      selectedColor: AdminStyles.primary.withValues(alpha: 0.15),
                      backgroundColor: AdminStyles.bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isSelected ? AdminStyles.primary : AdminStyles.border),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AdminStyles.primary : AdminStyles.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customDurationController,
                  decoration: InputDecoration(
                    hintText: 'Or enter custom duration (e.g. 5 Hours, 4 Days)...',
                    hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AdminStyles.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminStyles.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminStyles.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminStyles.primary, width: 2)),
                  ),
                  onChanged: (v) {
                    if (v.trim().isNotEmpty) {
                      setState(() {
                        _durationError = null;
                      });
                    }
                  },
                ),
                if (_durationError != null) ...[
                  const SizedBox(height: 8),
                  Text(_durationError!, style: AdminStyles.bodyStyle(color: AdminStyles.error, fontSize: 12)),
                ],
                const SizedBox(height: 40),
                // ── Step 3: Maintenance Assignment ──────────────────────────
                Text('Step 3 — Maintenance Assignment', style: AdminStyles.headingStyle(fontSize: 18)),
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
                // ── Step 4: E-Signature ──────────────────────────────────────
                Text('Step 4 — E-Signature', style: AdminStyles.headingStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Text('As an administrator, provide your signature before approving this request.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openSignatureDialog,
                      icon: const Icon(Icons.draw_rounded, size: 20),
                      label: Text(_pendingSignatureBase64 != null ? 'View / Change Signature' : 'Signature'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pendingSignatureBase64 != null ? AdminStyles.primary.withValues(alpha: 0.1) : AdminStyles.primary,
                        foregroundColor: _pendingSignatureBase64 != null ? AdminStyles.primary : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                    if (_pendingSignatureBase64 != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AdminStyles.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminStyles.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, color: AdminStyles.success, size: 18),
                            const SizedBox(width: 8),
                            Text('Signature Confirmed', style: AdminStyles.headingStyle(fontSize: 13, color: AdminStyles.success)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (_signatureError != null) ...[
                  const SizedBox(height: 8),
                  Text(_signatureError!, style: AdminStyles.bodyStyle(color: AdminStyles.error, fontSize: 12)),
                ],
                const SizedBox(height: 40),
                // ── Final Approve Button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _approveWithSignature,
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 22),
                    label: const Text(
                      'Work Request Approve',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminStyles.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                  ),
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
    if (status == 'Pending') color = AdminStyles.warning;
    if (status == 'In Progress' || status == 'Confirmed' || status == 'Rework') color = AdminStyles.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(), style: AdminStyles.headingStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  void _openSignatureDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 540,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminStyles.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.draw_rounded, color: AdminStyles.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Administrative E-Signature', style: AdminStyles.headingStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            'Draw your official signature below and click Confirm Signature.',
                            style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SignaturePadWidget(
                  title: '',
                  subtitle: '',
                  height: 220,
                  onSignatureComplete: (base64) {
                    if (base64.isNotEmpty) {
                      setState(() {
                        _pendingSignatureBase64 = base64;
                        _signatureError = null;
                      });
                      Navigator.pop(ctx);
                      _showSuccess('Signature confirmed! Click "Work Request Approve" below to finalize.');
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

  // --- HELPERS ---

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.success));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AdminStyles.error));

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
