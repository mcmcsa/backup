import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/work_request_provider.dart';
import '../../../shared/providers/room_provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/request_type_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/duplicate_detection_service.dart';
import '../../../shared/widgets/duplicate_detection_dialog.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import '../../../shared/widgets/signature_pad_widget.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../authentication/models/user_model.dart';

class WorkRequestFormPage extends StatefulWidget {
  final String? roomId;
  final String? buildingName;
  final String? roomName;
  final Room? verifiedRoom;
  final bool lockLocationDetails;

  const WorkRequestFormPage({
    super.key,
    this.roomId,
    this.buildingName,
    this.roomName,
    this.verifiedRoom,
    this.lockLocationDetails = false,
  });

  @override
  State<WorkRequestFormPage> createState() => _WorkRequestFormPageState();
}

class _WorkRequestFormPageState extends State<WorkRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _officeRoomNameController =
      TextEditingController();
  final TextEditingController _issueDetailsController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _otherRequestTypeController =
      TextEditingController();

  String _selectedBuilding = '';
  String _selectedCollege = '';
  String _selectedFloor = '';
  String _selectedRequestType = '';
  final String _selectedPriority = '';
  String? _requesterSignatureBase64;
  bool _isSubmitting = false;

  final List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  List<String> _buildings = [];
  List<String> _filteredBuildings = [];
  List<String> _colleges = [];
  List<String> _floors = [];
  List<String> _requestTypes = [];
  final Map<String, List<String>> _buildingsByDepartment = {};

  bool get _isLocationLocked =>
      widget.lockLocationDetails || widget.verifiedRoom != null;

  late ThemeProvider _themeProvider;
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _applyVerifiedRoomDetails();
    _loadDropdownData();
    _loadUserData();
    if (widget.roomId != null) {
      _roomNumberController.text = widget.roomId!;
    }
    if (widget.roomName != null) {
      _officeRoomNameController.text = widget.roomName!;
    }
  }

  void _applyVerifiedRoomDetails() {
    final room = widget.verifiedRoom;
    if (room == null) return;

    _roomNumberController.text = room.code.isNotEmpty ? room.code : room.id;
    _officeRoomNameController.text = room.name;
    _selectedCollege = room.department;
    _selectedBuilding = room.building;
    _selectedFloor = room.floor;

    // Immediately seed the lists so the first build frame has the verified room values
    if (_selectedCollege.isNotEmpty && !_colleges.contains(_selectedCollege)) {
      _colleges = [_selectedCollege, ..._colleges];
    }
    if (_selectedBuilding.isNotEmpty && !_filteredBuildings.contains(_selectedBuilding)) {
      _filteredBuildings = [_selectedBuilding, ..._filteredBuildings];
    }
    if (_selectedFloor.isNotEmpty && !_floors.contains(_selectedFloor)) {
      _floors = [_selectedFloor, ..._floors];
    }
  }

  Future<void> _loadUserData() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user != null && user.name.trim().isNotEmpty) {
      if (_fullNameController.text.trim().isEmpty) {
        _fullNameController.text = user.name.trim();
      }
      if (_positionController.text.trim().isEmpty) {
        final pos = (user.position != null && user.position!.trim().isNotEmpty)
            ? user.position!.trim()
            : user.roleLabel;
        _positionController.text = pos;
      }
      if (mounted) setState(() {});
      return;
    }

    try {
      final sbUser = Supabase.instance.client.auth.currentUser;
      if (sbUser != null) {
        final res = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', sbUser.id)
            .maybeSingle();
        if (res != null && mounted) {
          final name = res['name']?.toString() ??
              res['full_name']?.toString() ??
              sbUser.userMetadata?['name']?.toString() ??
              '';
          final pos = res['position']?.toString() ??
              res['role']?.toString() ??
              'Teacher';
          if (_fullNameController.text.trim().isEmpty && name.isNotEmpty) {
            _fullNameController.text = name;
          }
          if (_positionController.text.trim().isEmpty && pos.isNotEmpty) {
            _positionController.text = pos;
          }
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('[WorkRequestForm] Error fetching user data fallback: $e');
    }
  }

  Future<void> _loadDropdownData() async {
    final helper = DropdownDataHelper();
    final buildings = await helper.getBuildingNames();
    final depts = await helper.getDepartmentNames();
    final floors = await helper.getFloorNames(forceRefresh: true);
    final requestTypes = await helper.getRequestTypeNames();

    if (mounted) {
      // Build map of buildings by department
      _buildingsByDepartment.clear();
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
        _buildings = buildings;
        _colleges = depts.isNotEmpty ? depts : helper.getColleges();
        final normalizedFloors = floors
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _floors = normalizedFloors.isNotEmpty ? normalizedFloors : ['N/A'];
        _requestTypes = requestTypes;

        if (_isLocationLocked && widget.verifiedRoom != null) {
          final room = widget.verifiedRoom!;
          _selectedCollege = room.department;
          _selectedBuilding = room.building;
          _selectedFloor = room.floor;

          if (_selectedCollege.isNotEmpty && !_colleges.contains(_selectedCollege)) {
            _colleges = [_selectedCollege, ..._colleges];
          }
          if (_selectedBuilding.isNotEmpty && !_buildings.contains(_selectedBuilding)) {
            _buildings = [_selectedBuilding, ..._buildings];
          }
          if (_selectedFloor.isNotEmpty && !_floors.contains(_selectedFloor)) {
            _floors = [_selectedFloor, ..._floors];
          }
        } else {
          _selectedCollege = widget.buildingName != null
              ? _colleges.firstWhere(
                  (college) =>
                      _buildingsByDepartment[college]?.contains(
                        widget.buildingName,
                      ) ??
                      false,
                  orElse: () => _colleges.isNotEmpty ? _colleges.first : '',
                )
              : (_colleges.isNotEmpty ? _colleges.first : '');

          _selectedBuilding = widget.buildingName ?? '';
        }
        _updateFilteredBuildings();

        if (!_isLocationLocked) {
          _selectedFloor = _floors.isNotEmpty ? _floors.first : '';
        }
        if (_requestTypes.isNotEmpty && _selectedRequestType.isEmpty) {
          _selectedRequestType = _requestTypes.first;
        }
      });
    }
  }

  void _updateFilteredBuildings() {
    if (_selectedCollege.isEmpty) {
      _filteredBuildings = List.from(_buildings);
    } else {
      _filteredBuildings = _buildingsByDepartment[_selectedCollege] ?? _buildings;
    }
    if (_isLocationLocked && widget.verifiedRoom != null) {
      if (_selectedBuilding.isNotEmpty && !_filteredBuildings.contains(_selectedBuilding)) {
        _filteredBuildings = [_selectedBuilding, ..._filteredBuildings];
      }
    } else {
      // Reset building selection if current selection is not in filtered list
      if (!_filteredBuildings.contains(_selectedBuilding)) {
        _selectedBuilding = _filteredBuildings.isNotEmpty ? _filteredBuildings.first : '';
      }
    }
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _roomNumberController.dispose();
    _officeRoomNameController.dispose();
    _issueDetailsController.dispose();
    _fullNameController.dispose();
    _positionController.dispose();
    _otherRequestTypeController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Error',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF374151),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF4169E1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((img) => File(img.path)));
        });
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Failed to pick images: $e');
    }
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_selectedRequestType.isEmpty) {
          if (!mounted) return;
          _showErrorDialog('Please select a request type');
          return;
        }

        if (_selectedImages.isEmpty) {
          if (!mounted) return;
          _showErrorDialog('Please upload at least one photo of the issue.');
          return;
        }

        if (_requesterSignatureBase64 == null ||
            _requesterSignatureBase64!.isEmpty) {
          if (!mounted) return;
          _showErrorDialog('Electronic signature is required before submitting.');
          return;
        }

        setState(() {
          _isSubmitting = true;
        });

        final verifiedRoom = widget.verifiedRoom;
        final submittedRoomCode = verifiedRoom != null
            ? (verifiedRoom.code.isNotEmpty ? verifiedRoom.code : verifiedRoom.id)
            : _roomNumberController.text.trim();
        final submittedRoomName = verifiedRoom?.name.isNotEmpty == true
            ? verifiedRoom!.name
            : _officeRoomNameController.text.trim();

        var selectedRoom = verifiedRoom;
        selectedRoom ??= await RoomService.findRoomByScannedCode(submittedRoomCode);

        if (selectedRoom == null) {
          if (!mounted) return;
          _showErrorDialog('Room not found. Please check the room code or room name.');
          return;
        }

        // ── Duplicate detection ─────────────────────────────────────────────
        final specify = _otherRequestTypeController.text.trim();
        final typeLabel = _selectedRequestType == 'Others'
            ? (specify.isNotEmpty ? 'Others: $specify' : 'Others')
            : (specify.isNotEmpty
                ? '$_selectedRequestType: $specify'
                : _selectedRequestType.trim());

        final duplicates = await DuplicateDetectionService.detect(
          roomId: selectedRoom.id,
          issueType: typeLabel,
          description: _issueDetailsController.text.trim(),
        );

        if (duplicates.isNotEmpty && mounted) {
          final result =
              await showDuplicateDetectionDialog(context, duplicates);
          if (!mounted) return;

          if (result == null) {
            setState(() => _isSubmitting = false);
            return;
          }

          if (result.choice == DuplicateDialogChoice.viewExisting) {
            final req = result.selectedRequest!;
            setState(() => _isSubmitting = false);
            context.push(
              '/request-details',
              extra: {
                'trackingNumber': req.id,
                'status': req.status,
              },
            );
            return;
          }

          if (result.choice == DuplicateDialogChoice.joinExisting) {
            final authUser = Supabase.instance.client.auth.currentUser;
            if (authUser != null) {
              await DuplicateDetectionService.joinRequest(
                workRequestId: result.selectedRequest!.id,
                reporterId: authUser.id,
                reporterName: _fullNameController.text.trim(),
              );
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'You have been added as a co-reporter to the existing request.'),
                  backgroundColor: Color(0xFF22C55E),
                ),
              );
              Navigator.pop(context);
            }
            return;
          }
          // DuplicateDialogChoice.continueAnyway → fall through to submit
        }
        // ── End duplicate detection ─────────────────────────────────────────

        final authUser = Supabase.instance.client.auth.currentUser;
        final helper = DropdownDataHelper();
        final selectedBuildingRecord = await helper.getBuildingByName(_selectedBuilding);
        final selectedDepartmentRecord = await helper.getDepartmentByName(_selectedCollege);

        if (typeLabel.isEmpty) {
          if (!mounted) return;
          _showErrorDialog('Please specify the request type.');
          return;
        }

        final lookupName = _selectedRequestType == 'Others' ? 'Others' : typeLabel;
        var selectedRequestTypeRecord = await helper.getRequestTypeByName(lookupName);
        if (selectedRequestTypeRecord == null && _selectedRequestType == 'Others') {
          selectedRequestTypeRecord = await helper.getRequestTypeByName('Other');
        }
        if (selectedRequestTypeRecord == null) {
          try {
            final createdType = await Supabase.instance.client
                .from('request_types')
                .insert({'name': lookupName})
                .select()
                .maybeSingle();
            if (createdType != null) {
              selectedRequestTypeRecord = RequestType.fromMap(createdType);
            }
          } catch (_) {
            // If RLS blocks inserting request type for non-admin roles, leave record null.
          }
        }

        final request = WorkRequest(
          id: '',
          title: 'Work Request – $typeLabel',
          description: _issueDetailsController.text.trim(),
          status: 'Pending',
          priority: _selectedPriority,
          buildingName: _selectedBuilding,
          buildingId: selectedBuildingRecord?.id,
          departmentName: _selectedCollege,
          departmentId: selectedDepartmentRecord?.id,
          roomId: selectedRoom.id,
          roomName: submittedRoomName.isNotEmpty ? submittedRoomName : selectedRoom.name,
          requestTypeId: selectedRequestTypeRecord?.id,
          typeOfRequest: typeLabel,
          dateSubmitted: DateTime.now(),
          requestorName: _fullNameController.text.trim(),
          requestorPosition: _positionController.text.trim(),
          reportedByName: _fullNameController.text.trim(),
          requestorId: authUser?.id,
        );

        final requestId = WorkRequestService.generateId();

        List<String> uploadedUrls = [];
        for (var i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          try {
            final bytes = await file.readAsBytes();
            final fileName = file.path.split(RegExp(r'[\\/]')).last;
            final url = await WorkRequestService.uploadAttachmentBytes(
              workRequestId: requestId,
              fileName: fileName,
              bytes: bytes,
            );
            if (url != null && url.isNotEmpty) {
              uploadedUrls.add(url);
            }
          } catch (e) {
            debugPrint('Error uploading image $i: $e');
          }
        }

        final requestToInsert = request.copyWith(
          id: requestId,
          attachmentUrls: uploadedUrls.isNotEmpty ? uploadedUrls : null,
          workEvidence: uploadedUrls.isNotEmpty ? uploadedUrls.join(',') : null,
        );

        var insertedRequest = await WorkRequestService.insert(requestToInsert);

        try {
          context.read<WorkRequestProvider>().refreshRequests(silent: true);
          context.read<RoomProvider>().refreshRooms();
        } catch (_) {}



        if (authUser != null) {
          if (!mounted) return;
          final currentUser = context.read<AuthService>().currentUser;
          final isAdmin = currentUser?.role == UserRole.campadmin || currentUser?.role == UserRole.admin;
          final signerRole = isAdmin ? 'admin' : 'teacher';

          await ESignatureService.insert(
            ESignature(
              id: '',
              workRequestId: insertedRequest.id,
              signerId: authUser.id,
              signerName: _fullNameController.text.trim(),
              signerRole: signerRole,
              signatureType: 'requestor',
              signatureData: _requesterSignatureBase64!,
              signedAt: DateTime.now(),
              notes: 'Requester e-signature at submission',
            ),
          );

          if (isAdmin && currentUser != null) {
            await LoginActivityService.recordAdminAction(
              user: currentUser,
              title: 'Created Work Request',
              details: 'Created work request for $_selectedBuilding • ${_officeRoomNameController.text.trim()}',
              workRequestId: insertedRequest.id,
            );
          }
        }

        await AppNotificationService.createForRoles(
          targetRoles: const ['admin', 'maintenance'],
          title: 'New Work Request Submitted',
          message:
              '$_selectedBuilding • ${_officeRoomNameController.text.trim()} has a new request from ${_fullNameController.text.trim()}.',
          type: 'work_request_submitted',
          workRequestId: insertedRequest.id,
        );

        if (authUser != null) {
          await AppNotificationService.createForUser(
            targetUserId: authUser.id,
            title: 'Work Request Submitted',
            message:
                'Your request for $_selectedBuilding • ${_officeRoomNameController.text.trim()} has been submitted and is pending admin review.',
            type: 'work_request_submitted',
            workRequestId: insertedRequest.id,
            targetPage: '/reports',
          );
        }

        if (!mounted) return;
        final trackingNumber = insertedRequest.id;
        if (!mounted) return;
        context.replace(
          '/work-request-success',
          extra: {
            'trackingNumber': trackingNumber,
            'location':
                '$_selectedBuilding, ${_roomNumberController.text.trim()}',
            'severity': typeLabel,
            'reportedDate': DateTime.now(),
          },
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep user info in sync if late-loaded by AuthService
    final authUser = context.watch<AuthService>().currentUser;
    if (authUser != null && authUser.name.trim().isNotEmpty) {
      if (_fullNameController.text.trim().isEmpty) {
        _fullNameController.text = authUser.name.trim();
      }
      if (_positionController.text.trim().isEmpty) {
        final pos = (authUser.position != null && authUser.position!.trim().isNotEmpty)
            ? authUser.position!.trim()
            : authUser.roleLabel;
        _positionController.text = pos;
      }
    }

    _themeProvider = Provider.of<ThemeProvider>(context);
    _isDark = _themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: _themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Work Request Form',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _themeProvider.textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Details Section
              _buildSectionCard(
                title: '1. Location Details',
                children: [
                  const SizedBox(height: 16),
                  if (_isLocationLocked)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? const Color(0xFF0F766E).withValues(alpha: 0.2)
                            : const Color(0xFF0F766E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isDark
                              ? const Color(0xFF00BFA5).withValues(alpha: 0.4)
                              : const Color(0xFF0F766E).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF00BFA5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location details are locked because the room has already been verified.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 1. Room Code (matching Web layout order)
                  _buildLabel('Room Code'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _roomNumberController,
                    hint: 'e.g., 402 or CLR 1',
                    readOnly: _isLocationLocked,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter room code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 2. Room Name
                  _buildLabel('Room Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _officeRoomNameController,
                    hint: 'e.g., Computer Laboratory Room 2',
                    readOnly: _isLocationLocked,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter room name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 3. Department/College
                  _buildLabel('Department/College'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedCollege,
                    items: _colleges,
                    hintText: 'Select Department/College',
                    onChanged: _isLocationLocked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCollege = value ?? '';
                              _updateFilteredBuildings();
                            });
                          },
                    enabled: !_isLocationLocked,
                  ),
                  const SizedBox(height: 16),
                  // 4. Building
                  _buildLabel('Building'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedBuilding,
                    items: _filteredBuildings,
                    hintText: 'Select Building',
                    onChanged: _selectedCollege.isEmpty || _isLocationLocked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedBuilding = value ?? '';
                            });
                          },
                    enabled: _selectedCollege.isNotEmpty && !_isLocationLocked,
                  ),
                  const SizedBox(height: 16),
                  // 5. Floor
                  _buildLabel('Floor'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedFloor,
                    items: _floors,
                    hintText: 'Select Floor',
                    onChanged: _isLocationLocked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedFloor = value ?? '';
                            });
                          },
                    enabled: !_isLocationLocked,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Request Type Section
              _buildSectionCard(
                title: '2. Request Type',
                children: [
                  const SizedBox(height: 16),
                  _buildLabel('Type of Request *'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ..._requestTypes.map((t) => _buildChoiceChip(t)),
                      _buildChoiceChip('Others'),
                    ],
                  ),
                  if (_selectedRequestType.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildLabel(_getSpecifyDetailsLabel(_selectedRequestType)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _otherRequestTypeController,
                      hint: _selectedRequestType == 'Others'
                          ? 'What kind of request is needed?'
                          : 'e.g. Aircon, Door Lock, Whiteboard, Window Glass',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return _selectedRequestType == 'Others'
                              ? 'Please specify the request type'
                              : 'Please specify details';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              // Issue Details Section
              _buildSectionCard(
                title: '3. Issue Details',
                children: [
                  const SizedBox(height: 16),
                  _buildLabel('Describe the issue in detail *'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    child: TextFormField(
                      controller: _issueDetailsController,
                      maxLines: 4,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Please provide specific details about the problem...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: _isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please describe the issue';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Upload Photos *'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                        label: const Text('Add Photos'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00BFA5),
                          side: const BorderSide(color: Color(0xFF00BFA5)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PNG, JPG up to 10MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _selectedImages.asMap().entries.map((entry) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(entry.value, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(entry.key);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
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
              const SizedBox(height: 20),
              // Requester Info Section (aligned with Web)
              _buildSectionCard(
                title: '4. Requester Info',
                children: [
                  const SizedBox(height: 16),
                  _buildLabel('Full Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _fullNameController,
                    hint: 'Your full name',
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Position/Title'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _positionController,
                    hint: 'e.g., Instructor',
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your position';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Electronic Signature *REQUIRED'),
                  const SizedBox(height: 8),
                  SignaturePadWidget(
                    title: 'E-Signature',
                    subtitle: 'Sign below or upload image to verify this request',
                    height: 170,
                    onSignatureComplete: (base64) {
                      setState(() => _requesterSignatureBase64 = base64);
                    },
                    onSignatureCleared: () {
                      setState(() => _requesterSignatureBase64 = null);
                    },
                  ),
                  if (_requesterSignatureBase64 != null &&
                      _requesterSignatureBase64!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Color(0xFF00BFA5)),
                          SizedBox(width: 8),
                          Text(
                            'Signature captured and verified',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: _isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(
                          0xFF00BFA5,
                        ).withValues(alpha: 0.5),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Submit Work Request',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getSpecifyDetailsLabel(String type) {
    switch (type) {
      case 'Installation of':
        return 'Specify Details (what is to be installed?) *';
      case 'Repair of':
        return 'Specify Details (what is to be repaired?) *';
      case 'Replacement of':
        return 'Specify Details (what is to be replaced?) *';
      case 'Ocular Inspection of':
        return 'Specify Details (what is to be inspected?) *';
      case 'Others':
        return 'Specify Other Type *';
      default:
        if (type.isEmpty) return 'Specify Details *';
        return 'Specify Details ($type) *';
    }
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark
              ? const Color(0xFF00BFA5).withValues(alpha: 0.4)
              : const Color(0xFF00BFA5),
          width: _isDark ? 1.5 : 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA5).withValues(alpha: _isDark ? 0.05 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _themeProvider.textColor,
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _isDark ? Colors.grey.shade200 : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    final bgColor = _isDark
        ? (readOnly ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D))
        : (readOnly ? const Color(0xFFF1F5F9) : Colors.white);
    final borderColor = _isDark
        ? Colors.grey.shade700
        : (readOnly ? const Color(0xFFCBD5E1) : Colors.grey.shade300);
    final txtColor = _isDark
        ? (readOnly ? Colors.grey.shade400 : Colors.white)
        : (readOnly ? const Color(0xFF1E293B) : const Color(0xFF0F172A));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 14,
          fontWeight: readOnly ? FontWeight.w600 : FontWeight.normal,
          color: txtColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: _isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
    bool enabled = true,
    String hintText = 'Select option',
  }) {
    final Set<String> sanitizedSet = {};
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) sanitizedSet.add(trimmed);
    }
    final trimmedVal = value.trim();
    if (trimmedVal.isNotEmpty) {
      sanitizedSet.add(trimmedVal);
    }
    final sanitizedList = sanitizedSet.toList();
    final effectiveValue = (trimmedVal.isNotEmpty && sanitizedList.contains(trimmedVal))
        ? trimmedVal
        : null;

    final bgColor = enabled
        ? (_isDark ? const Color(0xFF2D2D2D) : Colors.white)
        : (_isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9));
    final borderColor = _isDark
        ? Colors.grey.shade700
        : (enabled ? Colors.grey.shade300 : const Color(0xFFCBD5E1));
    final txtColor = _isDark
        ? (enabled ? Colors.white : Colors.grey.shade400)
        : (enabled ? const Color(0xFF0F172A) : const Color(0xFF1E293B));

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          dropdownColor: _isDark ? const Color(0xFF2D2D2D) : Colors.white,
          hint: Text(
            hintText,
            style: TextStyle(
              fontSize: 14,
              color: _isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: _isDark ? Colors.grey.shade300 : (enabled ? Colors.grey.shade600 : const Color(0xFF64748B)),
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
            color: txtColor,
          ),
          items: sanitizedList.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
                  color: txtColor,
                ),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label) {
    final isSelected = _selectedRequestType == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (s) {
        setState(() {
          _selectedRequestType = s ? label : '';
        });
      },
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF00BFA5).withValues(alpha: _isDark ? 0.25 : 0.12);
        }
        return _isDark ? const Color(0xFF2D2D2D) : Colors.white;
      }),
      labelStyle: TextStyle(
        color: isSelected
            ? const Color(0xFF2DD4BF)
            : (_isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF00BFA5)
              : (_isDark ? Colors.grey.shade700 : const Color(0xFFCBD5E1)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      backgroundColor: _isDark ? const Color(0xFF2D2D2D) : Colors.white,
    );
  }
}
