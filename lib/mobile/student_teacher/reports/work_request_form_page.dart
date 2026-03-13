import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/utils/dropdown_data_helper.dart';

class WorkRequestFormPage extends StatefulWidget {
  final String? roomId;
  final String? buildingName;
  final String? roomName;

  const WorkRequestFormPage({
    super.key,
    this.roomId,
    this.buildingName,
    this.roomName,
  });

  @override
  State<WorkRequestFormPage> createState() => _WorkRequestFormPageState();
}

class _WorkRequestFormPageState extends State<WorkRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _officeRoomNameController = TextEditingController();
  final TextEditingController _issueDetailsController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _otherRequestTypeController = TextEditingController();
  
  String _selectedBuilding = '';
  String _selectedCollege = '';
  String _selectedPosition = '';
  String _selectedRequestType = '';
  bool _isSubmitting = false;

  List<String> _buildings = [];
  List<String> _colleges = [];
  List<String> _positions = [];

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    if (widget.roomId != null) {
      _roomNumberController.text = widget.roomId!;
    }
    if (widget.roomName != null) {
      _officeRoomNameController.text = widget.roomName!;
    }
  }

  Future<void> _loadDropdownData() async {
    final helper = DropdownDataHelper();
    final buildings = await helper.getBuildingNames();
    final depts = await helper.getDepartmentNames();
    final positions = helper.getPositions();

    if (mounted) {
      setState(() {
        _buildings = buildings;
        _colleges = depts.isNotEmpty ? depts : helper.getColleges();
        _positions = positions;
        _selectedBuilding = widget.buildingName ?? (_buildings.isNotEmpty ? _buildings.first : '');
        _selectedCollege = _colleges.isNotEmpty ? _colleges.first : '';
        _selectedPosition = _positions.isNotEmpty ? _positions.first : '';
      });
    }
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _roomNumberController.dispose();
    _officeRoomNameController.dispose();
    _issueDetailsController.dispose();
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _otherRequestTypeController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedRequestType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a request type'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      final typeLabel = _selectedRequestType == 'Others'
          ? _otherRequestTypeController.text
          : _selectedRequestType;

      final request = WorkRequest(
        id: '',
        title: 'Work Request – $typeLabel',
        description: _issueDetailsController.text.trim(),
        status: 'pending',
        priority: 'medium',
        campus: 'PSU San Carlos',
        buildingName: _selectedBuilding,
        department: _selectedCollege,
        officeRoom: _officeRoomNameController.text.trim().isNotEmpty
            ? _officeRoomNameController.text.trim()
            : _roomNumberController.text.trim(),
        typeOfRequest: typeLabel,
        dateSubmitted: DateTime.now(),
        requestorName: _fullNameController.text.trim(),
        requestorPosition: _selectedPosition,
        reportedBy: _fullNameController.text.trim(),
      );

      try {
        await WorkRequestService.insert(request);

        if (!mounted) return;
        final trackingNumber =
            'PSU-SC-MR-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}';
        Navigator.pushReplacementNamed(
          context,
          '/work-request-success',
          arguments: {
            'trackingNumber': trackingNumber,
            'location': '$_selectedBuilding, ${_roomNumberController.text.trim()}',
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
        if (mounted) setState(() { _isSubmitting = false; });
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
                  _buildLabel('Building Name'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedBuilding,
                    items: _buildings,
                    onChanged: (value) {
                      setState(() {
                        _selectedBuilding = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Room Number'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _roomNumberController,
                    hint: 'e.g., 402',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter room number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('College'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedCollege,
                    items: _colleges,
                    onChanged: (value) {
                      setState(() {
                        _selectedCollege = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Office / Room Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _officeRoomNameController,
                    hint: 'e.g., Room-301-Computer Science Lab-B',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter office/room name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Request Type Section
              _buildSectionCard(
                title: '2. Request Type',
                children: [
                  const SizedBox(height: 16),
                  _buildRadioOption('Ocular Inspection'),
                  _buildRadioOption('Installation'),
                  _buildRadioOption('Repair'),
                  _buildRadioOption('Replacement'),
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
              // Issue Details Section
              _buildSectionCard(
                title: '3. Issue Details',
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
                        hintText: 'Please provide specific details about the problem...',
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
                  Container(
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
                          'Drag & drop or click to upload',
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
                ],
              ),
              const SizedBox(height: 20),
              // Requester Info Section
              _buildSectionCard(
                title: '4. Requester Info',
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
                  _buildDropdown(
                    value: _selectedPosition,
                    items: _positions,
                    onChanged: (value) {
                      setState(() {
                        _selectedPosition = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Contact Number (9xxxxxxxx)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _contactNumberController,
                    hint: '+63 9XX XXX XXXX',
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter contact number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Digital Signature (PK-SING-XXXXXXXXX) *OPTIONAL'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        'Signature Pad',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Signature cleared'), duration: Duration(seconds: 1)),
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
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                        disabledBackgroundColor: const Color(0xFF00BFA5).withOpacity(0.5),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            color: const Color(0xFF00BFA5).withOpacity(0.1),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
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
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
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
