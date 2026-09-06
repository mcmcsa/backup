import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/request_type_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../shared/admin_styles.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../teacher/reports/teacher_request_success_web.dart';

class AdminCreateRequestWeb extends StatefulWidget {
  final String? roomId;
  final String? buildingName;
  final String? roomName;
  final String? departmentName;
  final String? floor;
  final VoidCallback? onBack;

  const AdminCreateRequestWeb({
    super.key,
    this.roomId,
    this.buildingName,
    this.roomName,
    this.departmentName,
    this.floor,
    this.onBack,
  });

  @override
  State<AdminCreateRequestWeb> createState() => _AdminCreateRequestWebState();
}

class _AdminCreateRequestWebState extends State<AdminCreateRequestWeb> {
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

  bool get _isLocationLocked =>
      (widget.roomId != null && widget.roomId!.isNotEmpty) ||
      (widget.buildingName != null && widget.buildingName!.isNotEmpty);

  String _lastCheckedRoomCode = '';

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    if (widget.roomId != null) _roomNumberController.text = widget.roomId!;
    if (widget.roomName != null) _officeRoomNameController.text = widget.roomName!;
    if (widget.floor != null && widget.floor!.isNotEmpty) _selectedFloor = widget.floor!;
    if (widget.departmentName != null && widget.departmentName!.isNotEmpty) _selectedCollege = widget.departmentName!;

    final initialCode = widget.roomId ?? _roomNumberController.text;
    if (initialCode.trim().isNotEmpty) {
      _lastCheckedRoomCode = initialCode.trim().toUpperCase();
      _fetchRoomDetails(initialCode.trim());
    }

    _roomNumberController.addListener(_onRoomCodeChanged);
    
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _fullNameController.text = user.name;
      final pos = (user.position != null && user.position!.trim().isNotEmpty)
          ? user.position!.trim()
          : user.roleLabel;
      _positionController.text = pos;
    }
  }

  @override
  void dispose() {
    _roomNumberController.removeListener(_onRoomCodeChanged);
    super.dispose();
  }

  void _onRoomCodeChanged() {
    final text = _roomNumberController.text.trim().toUpperCase();
    if (text.isNotEmpty && text != _lastCheckedRoomCode) {
      _lastCheckedRoomCode = text;
      _fetchRoomDetails(text);
    }
  }

  Future<void> _fetchRoomDetails(String roomCode) async {
    final code = roomCode.trim();
    if (code.isEmpty) return;

    try {
      final room = await RoomService.findRoomByScannedCode(code);
      if (room != null && mounted) {
        setState(() {
          if (_officeRoomNameController.text.trim().isEmpty || widget.roomName == null) {
            _officeRoomNameController.text = room.name;
          }
          if (room.department.isNotEmpty && (_colleges.isEmpty || _colleges.contains(room.department))) {
            _selectedCollege = room.department;
          }
          if (room.building.isNotEmpty) {
            final availableBuildings = _buildingsByDepartment[_selectedCollege] ?? [];
            if (availableBuildings.contains(room.building)) {
              _selectedBuilding = room.building;
            } else {
              _selectedBuilding = room.building;
            }
          }
          if (room.floor.isNotEmpty) {
            _selectedFloor = room.floor;
            if (!_floors.contains(_selectedFloor)) {
              _floors.add(_selectedFloor);
            }
          }
        });
      }
    } catch (_) {}
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
        
        if (widget.departmentName != null && widget.departmentName!.isNotEmpty && _colleges.contains(widget.departmentName)) {
          _selectedCollege = widget.departmentName!;
        } else if (widget.buildingName != null && widget.buildingName!.isNotEmpty) {
          _selectedCollege = _colleges.firstWhere(
            (c) => _buildingsByDepartment[c]?.contains(widget.buildingName) ?? false,
            orElse: () => '',
          );
        } else if (_selectedCollege.isEmpty) {
          _selectedCollege = '';
        }

        if (widget.buildingName != null && widget.buildingName!.isNotEmpty) {
          final availableBuildings = _buildingsByDepartment[_selectedCollege] ?? [];
          _selectedBuilding = availableBuildings.contains(widget.buildingName) 
              ? widget.buildingName! 
              : (availableBuildings.isNotEmpty ? availableBuildings.first : widget.buildingName!);
        }

        if (widget.floor != null && widget.floor!.isNotEmpty) {
          _selectedFloor = widget.floor!;
        }

        if (_selectedFloor.isNotEmpty && !_floors.contains(_selectedFloor)) {
          _floors.add(_selectedFloor);
        }

        if (_requestTypes.isNotEmpty && _selectedRequestType.isEmpty) {
          _selectedRequestType = _requestTypes.first;
        }
      });

      if (_selectedFloor.isEmpty && _roomNumberController.text.trim().isNotEmpty) {
        _fetchRoomDetails(_roomNumberController.text.trim());
      }
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

    if (_selectedImages.isEmpty) {
      setState(() => _showDropdownErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one photo of the issue.'),
          backgroundColor: AdminStyles.error,
        ),
      );
      return;
    }

    if (_requesterSignatureBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature is required'), backgroundColor: AdminStyles.error));
      return;
    }

    final authService = context.read<AuthService>();
    setState(() => _isSubmitting = true);

    try {
      final roomCode = _roomNumberController.text.trim();
      var room = await RoomService.fetchByCode(roomCode);

      if (room == null) {
        throw 'Room not found. Please verify the room code.';
      }

      final hasActive = await WorkRequestService.hasActiveRequestForRoom(room.id);
      if (hasActive) {
        throw 'This room already has an active maintenance request.';
      }

      final user = authService.currentUser;
      final helper = DropdownDataHelper();
      
      final building = await helper.getBuildingByName(_selectedBuilding);
      final dept = await helper.getDepartmentByName(_selectedCollege);
      
      final typeLabel = _selectedRequestType == 'Others' ? _otherRequestTypeController.text.trim() : _selectedRequestType;
      var typeRecord = await helper.getRequestTypeByName(typeLabel);
      if (typeRecord == null) {
         final res = await Supabase.instance.client.from('request_types').insert({'name': typeLabel}).select().maybeSingle();
         if (res != null) typeRecord = RequestType.fromMap(res);
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
          signerRole: 'admin',
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

      if (mounted) {
        TeacherRequestSuccessWeb.showAsDialog(
          context,
          trackingNumber: inserted.id,
          location: '${inserted.roomName} - ${inserted.buildingName}',
          severity: inserted.priority.toUpperCase(),
          reportedDate: inserted.dateSubmitted,
          onViewStatus: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              context.go('/admin/dashboard');
            }
          },
          onBackToHome: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              context.go('/admin/dashboard');
            }
          },
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AdminStyles.error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: Column(
        children: [
          _buildHeader(isMobile),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile) ...[
                          _buildMainForm(isMobile),
                          const SizedBox(height: 24),
                          _buildSidePanel(isMobile),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: _buildMainForm(isMobile)),
                              const SizedBox(width: 32),
                              Expanded(flex: 4, child: _buildSidePanel(isMobile)),
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

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AdminStyles.surface,
        border: Border(bottom: BorderSide(color: AdminStyles.border)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          context.go('/admin/dashboard');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Submit Work Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    label: const Text('Submit Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminStyles.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AdminStyles.textPrimary),
                  onPressed: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      context.go('/admin/dashboard');
                    }
                  },
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Submit Work Request', style: AdminStyles.headingStyle(fontSize: 24)),
                    Text('Report maintenance issues within your assigned rooms', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
                  ],
                ),
                const Spacer(),
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

  Widget _buildMainForm(bool isMobile) {
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
            if (isMobile) ...[
              _buildInputField(
                label: 'Room Code',
                controller: _roomNumberController,
                hint: 'ex. CLR 1',
                validator: (v) => v!.isEmpty ? 'Required' : null,
                readOnly: _isLocationLocked,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Room Name (Optional)',
                controller: _officeRoomNameController,
                hint: 'ex. Computer Lab 1',
                readOnly: _isLocationLocked,
              ),
            ] else
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
                      label: 'Room Name (Optional)',
                      controller: _officeRoomNameController,
                      hint: 'ex. Computer Lab 1',
                      readOnly: _isLocationLocked,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (isMobile) ...[
              _buildDropdownField(
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
              const SizedBox(height: 16),
              _buildDropdownField(
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
            ] else
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
            if (isMobile)
              _buildDropdownField(
                label: 'Floor',
                value: _selectedFloor,
                hintText: 'Select Floor',
                items: _floors,
                enabled: !_isLocationLocked,
                showError: _showDropdownErrors,
                onChanged: (v) => setState(() => _selectedFloor = v ?? ''),
              )
            else
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
            if (_selectedRequestType == 'Others') ...[
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Specify Other Type',
                controller: _otherRequestTypeController,
                hint: 'What kind of repair is needed?',
              ),
            ],
            const SizedBox(height: 24),
            _buildDropdownField(
              label: 'Priority Level',
              value: _selectedPriority,
              hintText: 'Select Priority',
              items: const ['low', 'medium', 'high'],
              isRequired: false,
              onChanged: (v) => setState(() => _selectedPriority = v!),
            ),
            const SizedBox(height: 24),
            _buildInputField(
              label: 'Description of the Problem',
              controller: _issueDetailsController,
              hint: 'Please describe the issue in detail...',
              maxLines: 5,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildLabel('Upload Photos'),
                const Text(
                  ' *',
                  style: TextStyle(color: AdminStyles.error, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                  label: const Text('Add Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminStyles.primary,
                    side: BorderSide(
                      color: (_showDropdownErrors && _selectedImages.isEmpty)
                          ? AdminStyles.error
                          : AdminStyles.primary,
                    ),
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
            if (_showDropdownErrors && _selectedImages.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Please upload at least one photo of the issue.',
                style: TextStyle(color: AdminStyles.error, fontSize: 12),
              ),
            ],
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
                            decoration: const BoxDecoration(
                              color: AdminStyles.error,
                              shape: BoxShape.circle,
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

  Widget _buildSidePanel(bool isMobile) {
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
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Position/Title',
              controller: _positionController,
              hint: 'e.g. Instructor',
              validator: (v) => v!.isEmpty ? 'Required' : null,
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
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
