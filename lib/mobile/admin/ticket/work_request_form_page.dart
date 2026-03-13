import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/building_service.dart';

class WorkRequestFormPage extends StatefulWidget {
  final WorkRequest? existingRequest;

  const WorkRequestFormPage({super.key, this.existingRequest});

  @override
  State<WorkRequestFormPage> createState() => _WorkRequestFormPageState();
}

class _WorkRequestFormPageState extends State<WorkRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _campusController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _officeRoomController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _requestorNameController = TextEditingController();
  final TextEditingController _requestorPositionController = TextEditingController();
  final TextEditingController _reportedByController = TextEditingController();
  final TextEditingController _approvedByController = TextEditingController();

  String _requestType = 'Ocular Inspection';
  DateTime _selectedDate = DateTime.now();
  String? _selectedBuilding;
  
  bool _isLocationExpanded = true;
  bool _isRequestExpanded = false;
  bool _isPersonnelExpanded = false;

  final List<String> _requestTypes = [
    'Ocular Inspection',
    'Installation',
    'Repair',
    'Replacement',
    'Others',
  ];

  List<String> _buildings = ['Select Building'];

  @override
  void initState() {
    super.initState();
    _loadBuildings();
    if (widget.existingRequest != null) {
      final request = widget.existingRequest!;
      _campusController.text = request.campus;
      _buildingController.text = request.buildingName;
      _departmentController.text = request.department;
      _officeRoomController.text = request.officeRoom;
      _descriptionController.text = request.description;
      _requestorNameController.text = request.requestorName;
      _requestorPositionController.text = request.requestorPosition;
      _reportedByController.text = request.reportedBy;
      _requestType = request.typeOfRequest;
      _selectedDate = request.dateSubmitted;
      if (request.approvedBy != null) {
        _approvedByController.text = request.approvedBy!;
      }
    }
  }

  Future<void> _loadBuildings() async {
    try {
      final buildings = await BuildingService.fetchAll();
      if (mounted) {
        setState(() {
          _buildings = ['Select Building', ...buildings.map((b) => b.name)];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _campusController.dispose();
    _buildingController.dispose();
    _departmentController.dispose();
    _officeRoomController.dispose();
    _descriptionController.dispose();
    _requestorNameController.dispose();
    _requestorPositionController.dispose();
    _reportedByController.dispose();
    _approvedByController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isViewMode = widget.existingRequest != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4169E1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'View',
          style: TextStyle(
            color: Color(0xFF4169E1),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: const Text(
                'Work Request Form',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Location Details Section
                  _buildCollapsibleSection(
                    title: 'LOCATION DETAILS',
                    isExpanded: _isLocationExpanded,
                    onTap: () => setState(() => _isLocationExpanded = !_isLocationExpanded),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Date'),
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedDate.month < 10 ? 'October' : 'November'} ${_selectedDate.day}, ${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Campus'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _campusController,
                            hintText: 'PSU San Carlos',
                            enabled: !isViewMode,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Building Name'),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            value: _selectedBuilding,
                            items: _buildings,
                            hint: 'Select Building',
                            onChanged: isViewMode ? null : (value) {
                              setState(() => _selectedBuilding = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Department'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _departmentController,
                            hintText: 'e.g. College of Computing',
                            enabled: !isViewMode,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Office / Room'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _officeRoomController,
                            hintText: 'e.g. Lab 302',
                            enabled: !isViewMode,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Request Details Section
                  _buildCollapsibleSection(
                    title: 'REQUEST DETAILS',
                    isExpanded: _isRequestExpanded,
                    onTap: () => setState(() => _isRequestExpanded = !_isRequestExpanded),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Type of Request'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _requestTypes.map((type) {
                              final isSelected = _requestType == type;
                              return GestureDetector(
                                onTap: isViewMode ? null : () {
                                  setState(() => _requestType = type);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEEF2FF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4169E1)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF4169E1)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Description of Work'),
                          const SizedBox(height: 8),
                          _buildMultilineTextField(
                            controller: _descriptionController,
                            hintText: 'Provide detailed information about the request...',
                            enabled: !isViewMode,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Personnel Information Section
                  _buildCollapsibleSection(
                    title: 'PERSONNEL INFORMATION',
                    isExpanded: _isPersonnelExpanded,
                    onTap: () => setState(() => _isPersonnelExpanded = !_isPersonnelExpanded),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Requestor:'),
                              TextButton(
                                onPressed: isViewMode ? null : () {
                                  _requestorNameController.clear();
                                  _requestorPositionController.clear();
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Color(0xFF4169E1),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          _buildSignatureArea(
                            controller: _requestorNameController,
                            hintText: 'When user hits requestor',
                            label: 'Human',
                            sublabel: 'REQUESTOR OVER PRINTED NAME',
                            enabled: !isViewMode,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Position / Designation :'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _requestorPositionController,
                            hintText: 'IT Staff',
                            enabled: !isViewMode,
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Approved by:'),
                              TextButton(
                                onPressed: isViewMode ? null : () {
                                  _approvedByController.clear();
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Color(0xFF4169E1),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          _buildSignatureArea(
                            controller: _approvedByController,
                            hintText: 'signature of user 2',
                            label: 'Ramon admin',
                            sublabel: 'REQUESTOR OVER PRINTED NAME',
                            enabled: !isViewMode,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Date:'),
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedDate.month < 10 ? 'October' : 'November'} ${_selectedDate.day}, ${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCollapsibleSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    color: const Color(0xFF4169E1),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4169E1),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) child,
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
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF4169E1),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildMultilineTextField({
    required TextEditingController controller,
    required String hintText,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF4169E1),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Color(0xFF4169E1),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 14),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSignatureArea({
    required TextEditingController controller,
    required String hintText,
    required String label,
    required String sublabel,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 80,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              controller.text.isEmpty ? hintText : controller.text,
              style: TextStyle(
                fontSize: 14,
                color: controller.text.isEmpty 
                    ? Colors.grey.shade400 
                    : const Color(0xFF111827),
                fontStyle: controller.text.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

