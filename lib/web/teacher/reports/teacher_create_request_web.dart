import 'package:flutter/material.dart';
import '../teacher_nav_controller.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/request_type_model.dart';
import '../../../shared/models/e_signature_model.dart';

import '../../../shared/services/connectivity_service.dart';
import '../../../shared/services/offline_sync_service.dart';
import '../../../shared/services/work_request_service.dart';

import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/duplicate_detection_service.dart';
import '../../../shared/widgets/duplicate_detection_dialog.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../admin/shared/admin_styles.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class TeacherCreateRequestWeb extends StatefulWidget {
  final String? roomId;
  final String? buildingName;
  final String? roomName;

  const TeacherCreateRequestWeb({
    super.key,
    this.roomId,
    this.buildingName,
    this.roomName,
  });

  @override
  State<TeacherCreateRequestWeb> createState() => _TeacherCreateRequestWebState();
}

class _TeacherCreateRequestWebState extends State<TeacherCreateRequestWeb> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _officeRoomNameController = TextEditingController();
  final TextEditingController _issueDetailsController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _otherRequestTypeController = TextEditingController();

  String _selectedBuilding = '';
  String _selectedCollege = '';
  String _selectedFloor = '';
  String _selectedRequestType = '';
  String _selectedPriority = 'medium';
  String? _requesterSignatureBase64;
  bool _isSubmitting = false;
  bool _showDropdownErrors = false;

  final List<XFile> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  List<String> _colleges = [];
  List<String> _floors = [];
  List<String> _requestTypes = [];
  final Map<String, List<String>> _buildingsByDepartment = {};

  WorkRequest? _submittedRequest;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    if (widget.roomId != null) _roomNumberController.text = widget.roomId!;
    if (widget.roomName != null) _officeRoomNameController.text = widget.roomName!;
    
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _fullNameController.text = user.name;
      final pos = (user.position != null && user.position!.trim().isNotEmpty)
          ? user.position!.trim()
          : user.roleLabel;
      _positionController.text = pos;
    }
  }

  Future<void> _loadDropdownData() async {
    final helper = DropdownDataHelper();
    final buildings = await helper.getBuildingNames();
    final depts = await helper.getDepartmentNames();
    final floors = await helper.getFloorNames(forceRefresh: true);
    final requestTypes = await helper.getRequestTypeNames();

    if (mounted) {
      for (final deptName in depts) {
        final dept = await helper.getDepartmentByName(deptName);
        if (dept != null) {
          final buildingsForDept = await helper.getBuildingNamesByDepartment(dept.id);
          _buildingsByDepartment[deptName] = buildingsForDept.isNotEmpty ? buildingsForDept : buildings;
        } else {
          _buildingsByDepartment[deptName] = buildings;
        }
      }

      setState(() {
        _colleges = depts;
        _floors = floors.where((f) => f.trim().isNotEmpty).toList();
        if (_floors.isEmpty) _floors = ['N/A'];
        _requestTypes = requestTypes;
        
        if (widget.buildingName != null && widget.buildingName!.isNotEmpty) {
          _selectedCollege = _colleges.firstWhere(
            (c) => _buildingsByDepartment[c]?.contains(widget.buildingName) ?? false,
            orElse: () => '',
          );
          final availableBuildings = _buildingsByDepartment[_selectedCollege] ?? [];
          _selectedBuilding = availableBuildings.contains(widget.buildingName) 
              ? widget.buildingName! 
              : (availableBuildings.isNotEmpty ? availableBuildings.first : '');
        } else {
          _selectedCollege = '';
          _selectedBuilding = '';
        }

        _selectedFloor = '';
        if (_requestTypes.isNotEmpty) _selectedRequestType = _requestTypes.first;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick images: $e'), backgroundColor: AdminStyles.error));
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCollege.isEmpty || _selectedBuilding.isEmpty || _selectedFloor.isEmpty) {
      setState(() => _showDropdownErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Department, Building, and Floor.'),
          backgroundColor: AdminStyles.error,
        ),
      );
      return;
    }

    if (_requesterSignatureBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature is required'), backgroundColor: AdminStyles.error));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final roomCode = _roomNumberController.text.trim();
      var room = await RoomService.findRoomByScannedCode(roomCode);

      if (room == null) {
        throw 'Room not found. Please verify the room code.';
      }

      // ── Duplicate detection ─────────────────────────────────────────────
      final typeLabel = _selectedRequestType == 'Others'
          ? _otherRequestTypeController.text.trim()
          : '$_selectedRequestType: ${_otherRequestTypeController.text.trim()}';

      final duplicates = await DuplicateDetectionService.detect(
        roomId: room.id,
        issueType: typeLabel,
        description: _issueDetailsController.text.trim(),
      );

      if (duplicates.isNotEmpty && mounted) {
        final result = await showDuplicateDetectionDialog(context, duplicates);
        if (!mounted) return;

        if (result == null) return; // dialog dismissed

        if (result.choice == DuplicateDialogChoice.viewExisting) {
          final req = result.selectedRequest!;
          // Navigate to the Reports detail page (index 3) with the existing request
          TeacherNavController.of(context)?.navigateTo(3, request: req);
          return;
        }

        if (result.choice == DuplicateDialogChoice.joinExisting) {
          final authService = context.read<AuthService>();
          final user = authService.currentUser;
          if (user != null) {
            await DuplicateDetectionService.joinRequest(
              workRequestId: result.selectedRequest!.id,
              reporterId: user.id,
              reporterName: _fullNameController.text.trim(),
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have been added as a co-reporter to the existing request.'),
                backgroundColor: Color(0xFF22C55E),
              ),
            );
            TeacherNavController.of(context)?.navigateTo(0);
          }
          return;
        }
        // DuplicateDialogChoice.continueAnyway → fall through to submit
      }
      // ── End duplicate detection ─────────────────────────────────────────

      if (!mounted) return;
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      final helper = DropdownDataHelper();
      
      final building = await helper.getBuildingByName(_selectedBuilding);
      final dept = await helper.getDepartmentByName(_selectedCollege);
      
      var typeRecord = await helper.getRequestTypeByName(typeLabel);
      if (typeRecord == null) {
        try {
          final res = await Supabase.instance.client.from('request_types').insert({'name': typeLabel}).select().maybeSingle();
          if (res != null) typeRecord = RequestType.fromMap(res);
        } catch (_) {
          // If RLS blocks inserting request type for non-admin roles, leave typeRecord null.
          // The work request itself will still be successfully created.
        }
      }

      final request = WorkRequest(
        id: '',
        title: 'Maintenance: $typeLabel',
        description: _issueDetailsController.text.trim(),
        status: 'Pending',
        priority: _selectedPriority,
        buildingName: _selectedBuilding,
        buildingId: building?.id,
        departmentName: _selectedCollege,
        departmentId: dept?.id,
        roomId: room.id,
        roomName: _officeRoomNameController.text.trim().isNotEmpty ? _officeRoomNameController.text.trim() : room.name,
        requestTypeId: typeRecord?.id,
        typeOfRequest: typeLabel,
        dateSubmitted: DateTime.now(),
        requestorName: _fullNameController.text.trim(),
        requestorPosition: _positionController.text.trim(),
        reportedByName: _fullNameController.text.trim(),
        requestorId: user?.id,
      );

      if (!ConnectivityService().isConnected.value) {
        // Queue action for offline sync
        List<String> offlineImagePaths = [];
        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          final bytes = await file.readAsBytes();
          final ext = file.name.split('.').last;
          final path = await OfflineSyncService().saveFileOffline(
            'offline_img_${DateTime.now().millisecondsSinceEpoch}_$i.$ext', 
            bytes
          );
          if (path != null) offlineImagePaths.add(path);
        }

        final payload = {
          'request': request.toMap(),
          'signature': _requesterSignatureBase64,
          'images': offlineImagePaths,
        };

        await OfflineSyncService().queueAction('submit_work_request', payload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved offline. Will submit when internet is restored.'),
              backgroundColor: AdminStyles.warning,
            ),
          );
          TeacherNavController.of(context)?.navigateTo(0);
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final inserted = await WorkRequestService.insert(request);

      List<String> uploadedUrls = [];
      for (var i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final extension = file.name.split('.').last;
        final fileName = '${inserted.id}/image_$i.$extension';
        try {
          final bytes = await file.readAsBytes();
          await Supabase.instance.client.storage
              .from('work-request-attachments')
              .uploadBinary(fileName, bytes);
          final url = Supabase.instance.client.storage
              .from('work-request-attachments')
              .getPublicUrl(fileName);
          uploadedUrls.add(url);
        } catch (e) {
          // ignore upload errors
        }
      }

      if (uploadedUrls.isNotEmpty) {
        final updatedRequest = inserted.copyWith(attachmentUrls: uploadedUrls);
        await WorkRequestService.update(updatedRequest);
      }

      if (user != null) {
        await ESignatureService.insert(ESignature(
          id: '',
          workRequestId: inserted.id,
          signerId: user.id,
          signerName: _fullNameController.text.trim(),
          signerRole: 'teacher',
          signatureType: 'requestor',
          signatureData: _requesterSignatureBase64!,
          signedAt: DateTime.now(),
        ));
      }

      await AppNotificationService.createForRoles(
        targetRoles: ['admin', 'maintenance'],
        title: 'New Request',
        message: 'New request for ${request.roomName} in ${request.buildingName}',
        type: 'work_request_submitted',
        workRequestId: inserted.id,
      );

      if (user != null) {
        await LoginActivityService.recordAction(
          user: user,
          title: 'Submitted Work Request',
          details: 'Reported issue: ${request.typeOfRequest} in ${request.roomName}',
          workRequestId: inserted.id,
        );
      }

      if (mounted) {
        setState(() {
          _submittedRequest = inserted;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AdminStyles.error));
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedRequest != null) {
      return _buildSuccessView();
    }

    final width = MediaQuery.of(context).size.width;
    final useVerticalLayout = width < 900;
    final isNarrow = width < 650;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isNarrow ? 12 : 32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (useVerticalLayout)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildMainForm(),
                              const SizedBox(height: 32),
                              _buildSidePanel(),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildMainForm()),
                              const SizedBox(width: 32),
                              Expanded(flex: 4, child: _buildSidePanel()),
                            ],
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

  Widget _buildSuccessView() {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildHeader(isSuccess: true),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isNarrow ? 16 : 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: EdgeInsets.all(isNarrow ? 20 : 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isNarrow ? 20 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: AdminStyles.primary.withValues(alpha: 0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isNarrow ? 72 : 96,
                        height: isNarrow ? 72 : 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: const Color(0xFF10B981),
                            size: isNarrow ? 36 : 48,
                          ),
                        ),
                      ),
                      SizedBox(height: isNarrow ? 20 : 32),
                      Text(
                        'Report Submitted Successfully!',
                        textAlign: TextAlign.center,
                        style: AdminStyles.headingStyle(
                          fontSize: isNarrow ? 22 : 28,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your maintenance request has been recorded and is being processed by the maintenance team.',
                        textAlign: TextAlign.center,
                        style: AdminStyles.bodyStyle(
                          fontSize: isNarrow ? 14 : 16,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: isNarrow ? 24 : 48),
                      Container(
                        padding: EdgeInsets.all(isNarrow ? 16 : 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REQUEST DETAILS',
                              style: AdminStyles.bodyStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildSuccessDetailRow(
                              'Tracking Number',
                              _submittedRequest!.id,
                              isCopyable: true,
                            ),
                            const Divider(height: 24, color: Color(0xFFE2E8F0)),
                            _buildSuccessDetailRow(
                              'Location',
                              '${_submittedRequest!.roomName} - ${_submittedRequest!.buildingName}',
                            ),
                            const Divider(height: 24, color: Color(0xFFE2E8F0)),
                            _buildSuccessDetailRow(
                              'Reported on',
                              '${_submittedRequest!.dateSubmitted.month}/${_submittedRequest!.dateSubmitted.day}/${_submittedRequest!.dateSubmitted.year}',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isNarrow ? 24 : 48),
                      if (isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: () => TeacherNavController.of(context)?.navigateTo(0),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminStyles.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Go to Dashboard',
                                style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                // Navigate back to Scanner so user can scan/input a new room code
                                TeacherNavController.of(context)?.navigateTo(2);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Submit Another',
                                style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Navigate back to Scanner so user can scan/input a new room code
                                  TeacherNavController.of(context)?.navigateTo(2);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Submit Another', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => TeacherNavController.of(context)?.navigateTo(0),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminStyles.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Go to Dashboard', style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSuccessDetailRow(String label, String value, {bool isTag = false, bool isCopyable = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AdminStyles.bodyStyle(fontSize: 13, color: const Color(0xFF64748B))),
        const SizedBox(height: 4),
        if (isTag)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AdminStyles.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminStyles.warning)),
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(value, style: AdminStyles.bodyStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
              ),
              if (isCopyable)
                const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
            ],
          ),
      ],
    );
  }


  Widget _buildHeader({bool isSuccess = false}) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 32,
        vertical: isNarrow ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        border: Border(bottom: BorderSide(color: AdminStyles.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
            onPressed: () => TeacherNavController.of(context)?.navigateTo(0),
          ),
          SizedBox(width: isNarrow ? 8 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSuccess ? 'Success' : 'Submit Work Request',
                  style: AdminStyles.headingStyle(fontSize: isNarrow ? 18 : 24),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (!isSuccess) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Report maintenance issues within your assigned rooms',
                    style: AdminStyles.bodyStyle(
                      color: AdminStyles.textSecondary,
                      fontSize: isNarrow ? 11 : 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          if (!isSuccess) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 14 : 24,
                  vertical: isNarrow ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : isNarrow
                      ? const Icon(Icons.send_rounded, size: 18)
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _isLocationLocked => widget.roomId != null && widget.roomId!.isNotEmpty;

  Widget _buildMainForm() {
    return Column(
      children: [
        _buildCard(
          title: 'Location Details',
          icon: Icons.location_on_rounded,
          children: [
            if (_isLocationLocked)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location details are locked because the room has already been verified.',
                        style: AdminStyles.bodyStyle(
                          fontSize: 12,
                          color: const Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'Room Code',
                    controller: _roomNumberController,
                    hint: 'ex. CLR 1',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    readOnly: _isLocationLocked,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'Room Name',
                    controller: _officeRoomNameController,
                    hint: 'ex. Computer Lab 1',
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                    readOnly: _isLocationLocked,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Department/College',
                    value: _selectedCollege,
                    hintText: 'Select Department',
                    items: _colleges,
                    enabled: !_isLocationLocked,
                    showError: _showDropdownErrors,
                    onChanged: (v) => setState(() {
                      _selectedCollege = v ?? '';
                      _selectedBuilding = '';
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Building',
                    value: _selectedBuilding,
                    hintText: 'Select Building',
                    items: _selectedCollege.isNotEmpty
                        ? (_buildingsByDepartment[_selectedCollege] ?? [])
                        : (_colleges.expand((c) => _buildingsByDepartment[c] ?? <String>[]).toSet().toList()),
                    enabled: !_isLocationLocked,
                    showError: _showDropdownErrors,
                    onChanged: (v) => setState(() => _selectedBuilding = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Floor',
                    value: _selectedFloor,
                    hintText: 'Select Floor',
                    items: _floors,
                    enabled: !_isLocationLocked,
                    showError: _showDropdownErrors,
                    onChanged: (v) => setState(() => _selectedFloor = v ?? ''),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildCard(
          title: 'Issue Details',
          icon: Icons.error_outline_rounded,
          children: [
            _buildLabel('Type of Request'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._requestTypes.map((t) => _buildChoiceChip(t)),
                _buildChoiceChip('Others'),
              ],
            ),
            if (_selectedRequestType.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInputField(
                label: _selectedRequestType == 'Others' ? 'Specify Other Type' : 'Specify Details (what is to be ${_selectedRequestType.split(" ").first.toLowerCase()}?)',
                controller: _otherRequestTypeController,
                hint: _selectedRequestType == 'Others'
                    ? 'What kind of request is needed?'
                    : 'e.g. Aircon, Door Lock, Whiteboard, Window Glass',
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
            ],
            const SizedBox(height: 24),
            _buildInputField(
              label: 'Description of the Problem',
              controller: _issueDetailsController,
              hint: 'Please describe the issue in detail...',
              maxLines: 5,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _buildLabel('Upload Photos (optional)'),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                  label: const Text('Add Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminStyles.primary,
                    side: const BorderSide(color: AdminStyles.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'PNG, JPG up to 10MB',
                  style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
                ),
              ],
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _selectedImages.asMap().entries.map((entry) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminStyles.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List>(
                            future: entry.value.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              }
                              if (snapshot.hasData) {
                                return Image.memory(snapshot.data!, fit: BoxFit.cover);
                              }
                              return const Icon(Icons.error_outline, color: AdminStyles.error);
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(entry.key);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AdminStyles.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSidePanel() {
    return Column(
      children: [
        _buildCard(
          title: 'Requester Info',
          icon: Icons.person_rounded,
          children: [
            _buildInputField(
              label: 'Full Name',
              controller: _fullNameController,
              hint: 'Your name',
              validator: (v) => v!.isEmpty ? 'Required' : null,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Position/Title',
              controller: _positionController,
              hint: 'e.g. Instructor',
              validator: (v) => v!.isEmpty ? 'Required' : null,
              readOnly: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildCard(
          title: 'Signature',
          icon: Icons.draw_rounded,
          children: [
             SignaturePadWidget(
               title: 'E-Signature',
               subtitle: 'Sign to verify this request',
               onSignatureComplete: (v) => setState(() => _requesterSignatureBase64 = v),
             ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 650;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AdminStyles.primary, size: 20),
              const SizedBox(width: 12),
              Text(title, style: AdminStyles.headingStyle(fontSize: 16)),
            ],
          ),
          const Divider(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller, String? hint, int maxLines = 1, String? Function(String?)? validator, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          style: AdminStyles.bodyStyle(color: readOnly ? AdminStyles.textMuted : AdminStyles.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade200 : AdminStyles.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : AdminStyles.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : AdminStyles.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : AdminStyles.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    String hintText = 'Select Option',
    required List<String> items,
    required void Function(String?)? onChanged,
    bool enabled = true,
    bool isRequired = true,
    bool showError = false,
  }) {
    final hasError = showError && isRequired && value.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildLabel(label),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: AdminStyles.error, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled ? AdminStyles.bg : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError
                  ? AdminStyles.error
                  : (enabled ? AdminStyles.border : Colors.grey.shade300),
              width: hasError ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (value.isNotEmpty && items.contains(value)) ? value : null,
              hint: Text(
                hintText,
                style: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
              ),
              isExpanded: true,
              items: items
                  .map((i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          i,
                          style: AdminStyles.bodyStyle(
                            color: enabled ? AdminStyles.textPrimary : AdminStyles.textMuted,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            'Please select $label',
            style: const TextStyle(color: AdminStyles.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceChip(String label) {
    final isSelected = _selectedRequestType == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (s) => setState(() => _selectedRequestType = label),
      selectedColor: AdminStyles.primary.withValues(alpha: 0.1),
      labelStyle: AdminStyles.bodyStyle(color: isSelected ? AdminStyles.primary : AdminStyles.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? AdminStyles.primary : AdminStyles.border)),
      backgroundColor: AdminStyles.surface,
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: AdminStyles.bodyStyle(fontWeight: FontWeight.bold, color: AdminStyles.textSecondary, fontSize: 13));
  }
}
