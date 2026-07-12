import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/models/request_type_model.dart';
import '../../../shared/models/e_signature_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/e_signature_service.dart';
import '../../../shared/services/app_notification_service.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import '../../../shared/widgets/signature_pad_widget.dart';

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
  String _selectedPriority = 'medium';
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

  @override
  void initState() {
    super.initState();
    _applyVerifiedRoomDetails();
    _loadDropdownData();
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
          if (_selectedCollege.isEmpty) {
            _selectedCollege = widget.verifiedRoom!.department;
          }
          _selectedBuilding = widget.verifiedRoom!.building;
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

        if (_isLocationLocked && widget.verifiedRoom != null) {
          if (_selectedFloor.isEmpty) {
            _selectedFloor = widget.verifiedRoom!.floor;
          }
        } else {
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
      _filteredBuildings = [];
    } else {
      _filteredBuildings = _buildingsByDepartment[_selectedCollege] ?? _buildings;
    }
    // Reset building selection if current selection is not in filtered list
    if (!_filteredBuildings.contains(_selectedBuilding)) {
      _selectedBuilding = _filteredBuildings.isNotEmpty ? _filteredBuildings.first : '';
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
        selectedRoom ??= await RoomService.fetchByCode(submittedRoomCode);

        if (selectedRoom == null) {
          if (!mounted) return;
          _showErrorDialog('Room not found. Please check the room code or room name.');
          return;
        }

        final hasActiveRequest = await WorkRequestService.hasActiveRequestForRoom(
          selectedRoom.id,
        );
        if (hasActiveRequest) {
          if (!mounted) return;
          _showErrorDialog('This room is already reported.');
          return;
        }

        final authUser = Supabase.instance.client.auth.currentUser;
        final helper = DropdownDataHelper();
        final selectedBuildingRecord = await helper.getBuildingByName(_selectedBuilding);
        final selectedDepartmentRecord = await helper.getDepartmentByName(_selectedCollege);

        final typeLabel = _selectedRequestType == 'Others'
            ? _otherRequestTypeController.text.trim()
            : _selectedRequestType.trim();
        if (typeLabel.isEmpty) {
          if (!mounted) return;
          _showErrorDialog('Please specify the request type.');
          return;
        }

        var selectedRequestTypeRecord = await helper.getRequestTypeByName(typeLabel);
        if (selectedRequestTypeRecord == null) {
          final createdType = await Supabase.instance.client
              .from('request_types')
              .insert({'name': typeLabel})
              .select()
              .maybeSingle();
          if (createdType != null) {
            selectedRequestTypeRecord = RequestType.fromMap(createdType);
          }
        }

        final request = WorkRequest(
          id: '',
          title: 'Work Request – $typeLabel',
          description: _issueDetailsController.text.trim(),
          status: 'pending',
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

        final insertedRequest = await WorkRequestService.insert(request);

        List<String> uploadedUrls = [];
        for (var i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          final extension = file.path.split('.').last;
          final fileName = '${insertedRequest.id}/image_$i.$extension';
          try {
            await Supabase.instance.client.storage
                .from('work-request-attachments')
                .upload(fileName, file);
            final url = Supabase.instance.client.storage
                .from('work-request-attachments')
                .getPublicUrl(fileName);
            uploadedUrls.add(url);
          } catch (e) {
            // ignore upload errors
          }
        }

        if (uploadedUrls.isNotEmpty) {
          final updatedRequest = insertedRequest.copyWith(attachmentUrls: uploadedUrls);
          await WorkRequestService.update(updatedRequest);
        }

        if (authUser != null) {
          await ESignatureService.insert(
            ESignature(
              id: '',
              workRequestId: insertedRequest.id,
              signerId: authUser.id,
              signerName: _fullNameController.text.trim(),
              signerRole: 'teacher',
              signatureType: 'approval',
              signatureData: _requesterSignatureBase64!,
              signedAt: DateTime.now(),
              notes: 'Requester e-signature at submission',
            ),
          );
        }

        await AppNotificationService.createForRoles(
          targetRoles: const ['admin', 'maintenance'],
          title: 'New Work Request Submitted',
          message:
              '$_selectedBuilding • ${_officeRoomNameController.text.trim()} has a new request from ${_fullNameController.text.trim()}.',
          type: 'work_request_submitted',
          workRequestId: insertedRequest.id,
        );

        if (!mounted) return;
        final trackingNumber =
            'PSU-SC-MR-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Work Request Form',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
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
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'Location details are locked because the room has already been verified.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  _buildLabel('Room Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _officeRoomNameController,
                    hint: 'e.g., Room-301-Computer Science Lab-B',
                    readOnly: _isLocationLocked,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter room name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Room Code'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _roomNumberController,
                    hint: 'e.g., 402',
                    readOnly: _isLocationLocked,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter room code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Department'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedCollege,
                    items: _colleges,
                    onChanged: _isLocationLocked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCollege = value!;
                              _updateFilteredBuildings();
                            });
                          },
                    enabled: !_isLocationLocked,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Building'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedBuilding,
                    items: _filteredBuildings,
                    onChanged: _selectedCollege.isEmpty || _isLocationLocked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedBuilding = value!;
                            });
                          },
                    enabled: _selectedCollege.isNotEmpty && !_isLocationLocked,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Floor'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedFloor,
                    items: _floors,
                    onChanged: _isLocationLocked
                        ? null
                        : (value) {
                            setState(() {
                              _selectedFloor = value!;
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
                  ..._requestTypes.map(_buildRadioOption),
                  _buildRadioOption('Others'),
                  if (_selectedRequestType == 'Others')
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 8),
                      child: _buildTextField(
                        controller: _otherRequestTypeController,
                        hint: 'Please specify...',
                        validator: (value) {
                          if (_selectedRequestType == 'Others' &&
                              (value == null || value.isEmpty)) {
                            return 'Please specify the request type';
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Priority Level Section
              _buildSectionCard(
                title: '3. Priority Level',
                children: [
                  const SizedBox(height: 16),
                  _buildDropdown(
                    value: _selectedPriority,
                    items: const ['low', 'medium', 'high'],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPriority = value;
                        });
                      }
                    },
                    enabled: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Issue Details Section
              _buildSectionCard(
                title: '4. Issue Details',
                children: [
                  const SizedBox(height: 16),
                  _buildLabel('Describe the issue in detail'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextFormField(
                      controller: _issueDetailsController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Please provide specific details about the problem...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please describe the issue';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Upload Photos (optional)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to upload photos',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PNG, JPG up to 10MB',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedImages.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                entry.value,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(entry.key);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
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
              // Requester Info Section
              _buildSectionCard(
                title: '5. Requester Info',
                children: [
                  const SizedBox(height: 16),
                  _buildLabel('Full Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _fullNameController,
                    hint: 'Enter your full name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Position'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _positionController,
                    hint: 'e.g., Instructor, Professor, Staff',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your position';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Electronic Signature *REQUIRED'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (_requesterSignatureBase64 != null &&
                                _requesterSignatureBase64!.isNotEmpty)
                            ? const Color(0xFF00BFA5)
                            : Colors.grey.shade300,
                        width:
                            (_requesterSignatureBase64 != null &&
                                _requesterSignatureBase64!.isNotEmpty)
                            ? 1.8
                            : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (_requesterSignatureBase64 != null &&
                                    _requesterSignatureBase64!.isNotEmpty)
                                ? 'Signature captured successfully'
                                : 'No signature yet',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  (_requesterSignatureBase64 != null &&
                                      _requesterSignatureBase64!.isNotEmpty)
                                  ? const Color(0xFF00BFA5)
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final signature = await SignatureDialog.show(
                              context,
                              title: 'Requester E-Signature',
                              subtitle:
                                  'Please sign to confirm this work request',
                            );
                            if (signature == null || signature.isEmpty) return;
                            if (!mounted) return;
                            setState(
                              () => _requesterSignatureBase64 = signature,
                            );
                          },
                          icon: const Icon(Icons.draw_rounded, size: 16),
                          label: Text(
                            (_requesterSignatureBase64 != null &&
                                    _requesterSignatureBase64!.isNotEmpty)
                                ? 'Re-sign'
                                : 'Sign',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BFA5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() => _requesterSignatureBase64 = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signature cleared'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF00BFA5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
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
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
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

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00BFA5),
          width: 2,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
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
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: readOnly ? Colors.grey.shade200 : Colors.grey.shade300,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
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
  }) {
    String displayValue = value;
    if (items.isNotEmpty && !items.contains(value)) {
      displayValue = items.first;
    }
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: enabled ? Colors.grey.shade300 : Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: displayValue,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: enabled ? Colors.grey.shade600 : Colors.grey.shade400),
          style: TextStyle(
            fontSize: 14,
            color: enabled ? Colors.black87 : Colors.grey.shade500,
          ),
          items: items.isEmpty
              ? [DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    enabled ? 'No options available' : 'Select department first',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                )]
              : items.map((String item) {
                  return DropdownMenuItem<String>(value: item, child: Text(item));
                }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildRadioOption(String value) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRequestType = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedRequestType == value
                      ? const Color(0xFF00BFA5)
                      : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: _selectedRequestType == value
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00BFA5),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: _selectedRequestType == value
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
