import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/maintenance_status_service.dart';
import '../../../shared/services/maintenance_schedule_service.dart';
import '../../../shared/services/collaboration_service.dart';
import '../../../shared/models/collaboration_models.dart';
import '../../../shared/widgets/maintenance_schedule_dialog.dart';
import '../../../shared/widgets/availability_status_badge.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/providers/theme_provider.dart';

/// Campus Admin screen to review a work request and sign E-signature for approval
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
  List<MaintenanceAccount> _maintenanceStaff = [];
  String? _masterScheduleUrl;
  final List<String> _selectedMaintenanceIds = [];
  String? get _selectedMaintenanceId =>
      _selectedMaintenanceIds.isNotEmpty ? _selectedMaintenanceIds.first : null;
  String? _selectedPriority;
  String _selectedDuration = '2 Hours';
  bool _isCustomDuration = false;
  final TextEditingController _customDurationController = TextEditingController();
  String? _pendingSignatureBase64;

  @override
  void initState() {
    super.initState();
    _isApproved = widget.request.status.toLowerCase() != 'pending';
    if (_isApproved) {
      if (widget.request.priority.isNotEmpty) {
        _selectedPriority = widget.request.priority.toLowerCase();
      }
      if (widget.request.assignedToId != null && widget.request.assignedToId!.isNotEmpty) {
        if (!_selectedMaintenanceIds.contains(widget.request.assignedToId!)) {
          _selectedMaintenanceIds.add(widget.request.assignedToId!);
        }
      }
    }
    _loadData();
  }

  @override
  void dispose() {
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ESignatureService.fetchByWorkRequest(widget.request.id),
        MaintenanceStatusService.fetchActiveMaintenanceWithDynamicStatus(),
        MaintenanceScheduleService.getMasterScheduleUrl(),
        CollaborationService.fetchCollaborators(widget.request.id),
      ]);

      if (mounted) {
        setState(() {
          _signatures = results[0] as List<ESignature>;
          _maintenanceStaff = results[1] as List<MaintenanceAccount>;
          _masterScheduleUrl = results[2] as String?;
          final collabs = results[3] as List<WorkRequestCollaborator>;

          if (widget.request.assignedToId != null && widget.request.assignedToId!.isNotEmpty) {
            if (!_selectedMaintenanceIds.contains(widget.request.assignedToId!)) {
              _selectedMaintenanceIds.insert(0, widget.request.assignedToId!);
            }
          }

          for (final c in collabs) {
            if (!_selectedMaintenanceIds.contains(c.userId)) {
              _selectedMaintenanceIds.add(c.userId);
            }
          }

          if (_isApproved) {
            final adminSig = _signatures.cast<ESignature?>().firstWhere(
              (s) =>
                  s != null &&
                  (s.signatureType == 'approval' || s.signatureType == 'admin_approval') &&
                  s.signatureData.isNotEmpty,
              orElse: () => null,
            );
            if (adminSig != null) {
              _pendingSignatureBase64 = adminSig.signatureData;
            }
          } else {
            _pendingSignatureBase64 = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _viewMasterSchedule() async {
    final currentUrl = _masterScheduleUrl ?? await MaintenanceScheduleService.getMasterScheduleUrl();
    if (!mounted) return;
    await showMaintenanceScheduleDialog(
      context,
      title: 'Maintenance Schedule',
      subtitle: 'Campus Master Schedule • All Maintenance Staff',
      scheduleUrl: currentUrl,
      onScheduleChanged: () async {
        final url = await MaintenanceScheduleService.getMasterScheduleUrl();
        if (mounted) setState(() => _masterScheduleUrl = url);
      },
    );
  }

  String _assignedStaffName() {
    if (_selectedMaintenanceId != null && _selectedMaintenanceId!.isNotEmpty) {
      final staff = _maintenanceStaff.cast<MaintenanceAccount?>().firstWhere(
        (m) => m?.userId == _selectedMaintenanceId,
        orElse: () => null,
      );
      if (staff != null && staff.fullName.isNotEmpty) {
        return staff.fullName;
      }
    }
    return 'Unassigned';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _openSignatureDialog() {
    bool isEditing = _pendingSignatureBase64 == null || _pendingSignatureBase64!.isEmpty;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Uint8List? signatureBytes;
            if (_pendingSignatureBase64 != null && _pendingSignatureBase64!.isNotEmpty) {
              try {
                final clean = _pendingSignatureBase64!.contains(',')
                    ? _pendingSignatureBase64!.split(',').last
                    : _pendingSignatureBase64!;
                signatureBytes = base64Decode(clean);
              } catch (_) {
                signatureBytes = null;
              }
            }

            final showViewMode = !isEditing && signatureBytes != null;

            return Dialog(
              backgroundColor: themeProvider.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            showViewMode
                                ? 'Current Signature'
                                : (_pendingSignatureBase64 != null ? 'Change Signature' : 'Admin E-Signature'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.textColor,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: themeProvider.textColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (showViewMode) ...[
                        Container(
                          width: double.infinity,
                          height: 180,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Center(
                            child: Image.memory(
                              signatureBytes,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Text('Unable to preview signature', style: TextStyle(color: Colors.black54)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (!_isApproved) ...[
                              TextButton.icon(
                                onPressed: () {
                                  setState(() => _pendingSignatureBase64 = null);
                                  setDialogState(() => isEditing = true);
                                },
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 13)),
                              ),
                            ],
                            const Spacer(),
                            if (!_isApproved) ...[
                              OutlinedButton.icon(
                                onPressed: () => setDialogState(() => isEditing = true),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Change'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: themeProvider.textColor,
                                  side: BorderSide(color: themeProvider.borderColor),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4169E1),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_isApproved ? 'Close' : 'Keep'),
                            ),
                          ],
                        ),
                      ] else ...[
                        SignaturePadWidget(
                          title: 'Campus Admin Signature',
                          subtitle: 'Sign below or upload image to approve',
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
                        if (_pendingSignatureBase64 != null && _pendingSignatureBase64!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => setDialogState(() => isEditing = false),
                              icon: const Icon(Icons.arrow_back, size: 14),
                              label: const Text('Back to current signature'),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF4169E1)),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveWithSignature() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    if (_selectedPriority == null || _selectedPriority!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a priority level before approving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedMaintenanceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one maintenance staff member to assign.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pendingSignatureBase64 == null || _pendingSignatureBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your signature first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final durationToSave = _isCustomDuration
        ? (_customDurationController.text.trim().isNotEmpty
            ? _customDurationController.text.trim()
            : '2 Hours')
        : _selectedDuration;

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
        priority: _selectedPriority!,
        estimatedDuration: durationToSave,
      );

      final primaryId = _selectedMaintenanceIds.first;
      await WorkRequestService.assignTo(widget.request.id, primaryId);

      // Invite secondary collaborators
      for (int i = 1; i < _selectedMaintenanceIds.length; i++) {
        try {
          await CollaborationService.inviteCollaborator(
            widget.request.id,
            _selectedMaintenanceIds[i],
            'secondary',
            user.id,
          );
        } catch (collabErr) {
          debugPrint('Error inviting secondary collaborator ${_selectedMaintenanceIds[i]}: $collabErr');
        }
      }

      await AppNotificationService.notifyApprovedToMaintenance(
        workRequestId: widget.request.id,
        adminName: user.name,
        assignedMaintenanceId: primaryId,
      );

      for (final staffId in _selectedMaintenanceIds) {
        try {
          final isPrimary = staffId == primaryId;
          await AppNotificationService.createForUser(
            targetUserId: staffId,
            title: isPrimary ? 'New Work Request Assignment' : 'Collaboration Assignment',
            message: isPrimary
                ? 'You were assigned to work request ${widget.request.id} by admin ${user.name}.'
                : 'You were invited to collaborate on work request ${widget.request.id} by admin ${user.name}.',
            type: 'work_request_assigned',
            workRequestId: widget.request.id,
          );
        } catch (_) {}
      }

      await LoginActivityService.recordAdminAction(
        user: user,
        title: 'Approved Request',
        details: 'Approved work request for ${widget.request.officeRoom} and assigned to ${_assignedStaffName()}',
        workRequestId: widget.request.id,
      );

      if (mounted) {
        setState(() {
          _isApproved = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work request approved and maintenance assigned!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        _loadData();
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final requestorName = widget.request.requestorName.isNotEmpty
        ? widget.request.requestorName
        : (widget.request.reportedByName ?? 'Requestor');

    final assignedStaff = _maintenanceStaff.cast<MaintenanceAccount?>().firstWhere(
      (m) => m?.userId == _selectedMaintenanceId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context, _isApproved),
        ),
        title: Text(
          'Campus Admin Approval',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
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
                  themeProvider: themeProvider,
                  children: [
                    _buildInfoRow('Tracking #', widget.request.id.substring(0, 8).toUpperCase(), themeProvider),
                    _buildInfoRow('Request Type', widget.request.typeOfRequest.replaceAll('_', ' ').toUpperCase(), themeProvider),
                    _buildInfoRow('Requestor', requestorName, themeProvider),
                    _buildInfoRow(
                      'Priority Level',
                      _selectedPriority != null && _selectedPriority!.isNotEmpty
                          ? _selectedPriority!.toUpperCase()
                          : 'NOT SET',
                      themeProvider,
                      valueColor: _selectedPriority != null && _selectedPriority!.isNotEmpty
                          ? _getPriorityColor(_selectedPriority!)
                          : themeProvider.mutedTextColor,
                    ),
                    _buildInfoRow(
                      'Assigned Staff',
                      _assignedStaffName(),
                      themeProvider,
                      valueColor: _selectedMaintenanceId != null ? const Color(0xFF4169E1) : themeProvider.mutedTextColor,
                    ),
                    _buildInfoRow('Submitted Date', _formatDate(widget.request.dateSubmitted), themeProvider),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Location Card
                _buildCardContainer(
                  title: 'LOCATION',
                  themeProvider: themeProvider,
                  children: [
                    _buildInfoRow('Building', widget.request.buildingName ?? 'Main Building', themeProvider),
                    _buildInfoRow('Room / Facility', widget.request.officeRoom ?? 'N/A', themeProvider),
                    _buildInfoRow('Department', widget.request.department ?? 'General Services', themeProvider),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Signatures Captured Card
                _buildSignaturesCapturedCard(themeProvider),
                const SizedBox(height: 20),

                // Approval Form Flow
                if (!_isApproved) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeProvider.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeProvider.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step 1: Priority Level (Updates information card in real-time)
                        Text(
                          'Step 1 — Priority Level',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['low', 'medium', 'high'].map((p) {
                            final isSel = _selectedPriority == p;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: ChoiceChip(
                                  label: Text(
                                    p.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : themeProvider.textColor,
                                    ),
                                  ),
                                  selected: isSel,
                                  selectedColor: _getPriorityColor(p),
                                  backgroundColor: themeProvider.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade100,
                                  side: BorderSide(
                                    color: isSel ? _getPriorityColor(p) : themeProvider.borderColor,
                                    width: 1,
                                  ),
                                  onSelected: (_) => setState(() => _selectedPriority = p),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Step 2: Target Duration
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Step 2 — Target Duration',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isCustomDuration = !_isCustomDuration;
                                  if (!_isCustomDuration) {
                                    _selectedDuration = '2 Hours';
                                  }
                                });
                              },
                              icon: Icon(_isCustomDuration ? Icons.list_rounded : Icons.edit_calendar_rounded, size: 14),
                              label: Text(
                                _isCustomDuration ? 'Choose Preset' : 'Custom Time',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF4169E1),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_isCustomDuration) ...[
                          TextFormField(
                            controller: _customDurationController,
                            style: TextStyle(color: themeProvider.textColor, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. 3 Hours, 45 Minutes, 3 Days',
                              hintStyle: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: themeProvider.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: themeProvider.borderColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: themeProvider.inputFillColor,
                              prefixIcon: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF4169E1)),
                            ),
                          ),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDuration,
                            dropdownColor: themeProvider.cardColor,
                            style: TextStyle(color: themeProvider.textColor, fontSize: 13),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: themeProvider.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: themeProvider.borderColor),
                              ),
                              filled: true,
                              fillColor: themeProvider.inputFillColor,
                            ),
                            items: ['1 Hour', '2 Hours', '4 Hours', '1 Day', '2 Days', '1 Week', 'Custom...']
                                .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d, style: TextStyle(color: themeProvider.textColor)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == 'Custom...') {
                                setState(() {
                                  _isCustomDuration = true;
                                });
                              } else {
                                setState(() {
                                  _selectedDuration = v ?? '2 Hours';
                                });
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Step 3: Maintenance Assignment
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Step 3 — Maintenance Assignment',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Assign primary technician & secondary collaborators.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: themeProvider.subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _viewMasterSchedule,
                              icon: const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF0F766E)),
                              label: const Text(
                                'View Schedule',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_maintenanceStaff.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Loading active maintenance personnel...',
                                    style: TextStyle(fontSize: 12, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: themeProvider.inputFillColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: themeProvider.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedMaintenanceIds.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _selectedMaintenanceIds.map((id) {
                                      final staff = _maintenanceStaff.cast<MaintenanceAccount?>().firstWhere(
                                        (m) => m?.userId == id,
                                        orElse: () => null,
                                      );
                                      final isPrimary = _selectedMaintenanceIds.indexOf(id) == 0;
                                      final staffName = staff?.fullName ?? 'Technician';

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isPrimary
                                              ? const Color(0xFF4169E1).withValues(alpha: 0.12)
                                              : (themeProvider.isDarkMode
                                                  ? Colors.white.withValues(alpha: 0.06)
                                                  : Colors.grey.shade100),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isPrimary
                                                ? const Color(0xFF4169E1).withValues(alpha: 0.4)
                                                : themeProvider.borderColor,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (staff != null)
                                              AvailabilityStatusBadge(
                                                status: staff.availabilityStatus,
                                                size: BadgeSize.small,
                                              ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$staffName ${isPrimary ? "(Primary)" : "(Secondary)"}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isPrimary
                                                    ? const Color(0xFF4169E1)
                                                    : themeProvider.textColor,
                                              ),
                                            ),
                                            if (!_isApproved) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedMaintenanceIds.remove(id);
                                                  });
                                                },
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                  color: themeProvider.subtitleColor,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (!_isApproved)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: themeProvider.cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: themeProvider.borderColor),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: null,
                                        isExpanded: true,
                                        dropdownColor: themeProvider.cardColor,
                                        icon: Icon(Icons.arrow_drop_down_rounded, color: themeProvider.subtitleColor),
                                        hint: Row(
                                          children: [
                                            const Icon(
                                              Icons.engineering_outlined,
                                              size: 20,
                                              color: Color(0xFF4169E1),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _selectedMaintenanceIds.isEmpty
                                                  ? 'Select primary technician...'
                                                  : '+ Add collaborator technician...',
                                              style: TextStyle(fontSize: 13, color: themeProvider.subtitleColor),
                                            ),
                                          ],
                                        ),
                                        items: _maintenanceStaff
                                            .where((staff) => !_selectedMaintenanceIds.contains(staff.userId))
                                            .map((staff) {
                                          return DropdownMenuItem<String>(
                                            value: staff.userId,
                                            child: Row(
                                              children: [
                                                AvailabilityStatusBadge(
                                                  status: staff.availabilityStatus,
                                                  size: BadgeSize.small,
                                                  showLabel: true,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${staff.fullName} (${staff.specialization ?? "General"})',
                                                    style: TextStyle(
                                                      color: themeProvider.textColor,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _selectedMaintenanceIds.add(v);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (assignedStaff != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4169E1).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF4169E1).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  AvailabilityStatusBadge(
                                    status: assignedStaff.availabilityStatus,
                                    size: BadgeSize.small,
                                    showLabel: true,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              assignedStaff.fullName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: themeProvider.textColor,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4169E1).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Primary Lead',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF4169E1),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Specialization: ${assignedStaff.specialization ?? "General Maintenance"}'
                                          '${_selectedMaintenanceIds.length > 1 ? " • +${_selectedMaintenanceIds.length - 1} Collaborator(s)" : ""}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: themeProvider.subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),

                        // Step 4: E-Signature
                        Text(
                          'Step 4 — E-Signature',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openSignatureDialog,
                              icon: Icon(
                                _pendingSignatureBase64 != null ? Icons.edit_note_rounded : Icons.draw_rounded,
                                size: 18,
                              ),
                              label: Text(_pendingSignatureBase64 != null ? 'View / Change Signature' : 'Sign Approval'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _pendingSignatureBase64 != null
                                    ? const Color(0xFF4169E1).withValues(alpha: 0.1)
                                    : const Color(0xFF4169E1),
                                foregroundColor: _pendingSignatureBase64 != null ? const Color(0xFF4169E1) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            if (_pendingSignatureBase64 != null && _pendingSignatureBase64!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, color: Color(0xFF059669), size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'Signature Confirmed',
                                    style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
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
                  _buildApprovedBanner(themeProvider),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildCardContainer({
    required String title,
    required List<Widget> children,
    required ThemeProvider themeProvider,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: themeProvider.subtitleColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSignaturesCapturedCard(ThemeProvider themeProvider) {
    final list = <Widget>[];

    final reqName = widget.request.requestorName.isNotEmpty
        ? widget.request.requestorName
        : (widget.request.reportedByName ?? '');

    final hasReqSig = _signatures.any((s) =>
        s.signatureType == 'request' ||
        s.signatureType == 'requestor' ||
        s.signerRole == 'requestor' ||
        s.signerRole == 'teacher');

    if (!hasReqSig && reqName.isNotEmpty) {
      list.add(_buildSignatureItem(reqName, 'Requestor', widget.request.dateSubmitted, themeProvider));
    }

    final displaySigs = List<ESignature>.from(_signatures);
    if (_pendingSignatureBase64 != null &&
        !displaySigs.any((s) => s.signatureType == 'approval' || s.signatureType == 'admin_approval')) {
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
      if (sig.signatureType == 'request' || sig.signatureType == 'requestor') {
        label = 'Requestor';
      } else if (sig.signatureType == 'approval' || sig.signatureType == 'admin_approval') {
        label = 'Admin Approval';
      } else if (sig.signatureType == 'pre_inspection') {
        label = 'Pre-Inspection';
      } else if (sig.signatureType == 'post_repair' || sig.signatureType == 'acceptance') {
        label = 'Maintenance';
      } else if (sig.signerRole == 'requestor' || sig.signerRole == 'teacher') {
        label = 'Requestor';
      } else if (sig.signerRole == 'admin') {
        label = 'Admin Approval';
      }
      list.add(_buildSignatureItem(sig.signerName, label, sig.signedAt, themeProvider));
    }

    if (list.isEmpty) return const SizedBox.shrink();

    return _buildCardContainer(
      title: 'SIGNATURES CAPTURED',
      children: list,
      themeProvider: themeProvider,
    );
  }

  Widget _buildSignatureItem(String name, String label, DateTime date, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4169E1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified, size: 14, color: Color(0xFF4169E1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                Text(
                  '$label • ${_formatDate(date)}',
                  style: TextStyle(fontSize: 11, color: themeProvider.subtitleColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedBanner(ThemeProvider themeProvider) {
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
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ThemeProvider themeProvider, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: themeProvider.subtitleColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? themeProvider.textColor,
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
