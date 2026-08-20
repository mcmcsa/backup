import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  final String _selectedPriority = '';
  String? _requesterSignatureBase64;
  bool _isSubmitting = false;

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
      _positionController.text = user.position ?? user.roleLabel;
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
            orElse: () => _colleges.isNotEmpty ? _colleges.first : '',
          );
          final availableBuildings = _buildingsByDepartment[_selectedCollege] ?? [];
          _selectedBuilding = availableBuildings.contains(widget.buildingName) 
              ? widget.buildingName! 
              : (availableBuildings.isNotEmpty ? availableBuildings.first : '');
        } else if (_colleges.isNotEmpty) {
          _selectedCollege = _colleges.first;
          _selectedBuilding = _buildingsByDepartment[_selectedCollege]?.first ?? '';
        }

        if (_floors.isNotEmpty) _selectedFloor = _floors.first;
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
    
    if (_requesterSignatureBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature is required'), backgroundColor: AdminStyles.error));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final roomCode = _roomNumberController.text.trim();
      var room = await RoomService.fetchByCode(roomCode);

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
          context.push('/work-request/${req.id}');
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
        status: 'pending',
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
          signatureType: 'approval',
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

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildHeader(isSuccess: true),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
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
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Report Submitted Successfully!',
                        textAlign: TextAlign.center,
                        style: AdminStyles.headingStyle(fontSize: 28, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your maintenance request has been recorded and is being processed by the maintenance team.',
                        textAlign: TextAlign.center,
                        style: AdminStyles.bodyStyle(fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
                      ),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REQUEST DETAILS', style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1)),
                            const SizedBox(height: 16),
                            _buildSuccessDetailRow('Tracking Number', _submittedRequest!.id, isCopyable: true),
                            const Divider(height: 24, color: Color(0xFFE2E8F0)),
                            _buildSuccessDetailRow('Location', '${_submittedRequest!.roomName} - ${_submittedRequest!.buildingName}'),
                            const Divider(height: 24, color: Color(0xFFE2E8F0)),
                            _buildSuccessDetailRow('Reported on', '${_submittedRequest!.dateSubmitted.month}/${_submittedRequest!.dateSubmitted.day}/${_submittedRequest!.dateSubmitted.year}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _submittedRequest = null;
                                  _roomNumberController.clear();
                                  _officeRoomNameController.clear();
                                  _issueDetailsController.clear();
                                  _requesterSignatureBase64 = null;
                                  _selectedImages.clear();
                                });
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isSuccess ? 'Success' : 'Submit Work Request', style: AdminStyles.headingStyle(fontSize: 24)),
              if (!isSuccess)
                Text('Report maintenance issues within your assigned rooms', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
            ],
          ),
          const Spacer(),
          if (!isSuccess)
            ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitRequest,
            icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
            label: const Text('Submit Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainForm() {
    return Column(
      children: [
        _buildCard(
          title: 'Location Details',
          icon: Icons.location_on_rounded,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'Room Code',
                    controller: _roomNumberController,
                    hint: 'e.g. 101, 205',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'Room Name (Optional)',
                    controller: _officeRoomNameController,
                    hint: 'e.g. CS Lab 1',
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
                    items: _colleges,
                    onChanged: (v) => setState(() {
                      _selectedCollege = v!;
                      _selectedBuilding = _buildingsByDepartment[v]?.first ?? '';
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Building',
                    value: _selectedBuilding,
                    items: _buildingsByDepartment[_selectedCollege] ?? [],
                    onChanged: (v) => setState(() => _selectedBuilding = v!),
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
                    items: _floors,
                    onChanged: (v) => setState(() => _selectedFloor = v!),
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
            if (_selectedImages.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminStyles.border, width: 1.5, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Upload', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
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
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 120,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminStyles.border, width: 1.5, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Upload', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
    return Container(
      padding: const EdgeInsets.all(24),
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

  Widget _buildDropdownField({required String label, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AdminStyles.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminStyles.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (value.isEmpty || !items.contains(value)) ? null : value,
              isExpanded: true,
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: AdminStyles.bodyStyle()))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
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
