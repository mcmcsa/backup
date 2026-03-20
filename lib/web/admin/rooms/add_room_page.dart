import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/qr_code_history_service.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import 'room_success_page.dart';
import 'qr_code_history_page.dart';

class AddRoomPage extends StatefulWidget {
  const AddRoomPage({super.key});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  static const String _addBuildingOption = 'Add new building...';
  static const String _addDepartmentOption = 'Add new department...';
  static const String _noDepartmentOption = 'Not specified';

  final _dropdownHelper = DropdownDataHelper();
  final _nameController = TextEditingController();
  final _buildingController = TextEditingController();
  final _departmentController = TextEditingController();
  final _capacityController = TextEditingController(text: '40');
  List<String> _buildingOptions = [];
  List<String> _departmentOptions = [];
  String _selectedBuilding = '';
  String _selectedDepartment = _noDepartmentOption;
  String _selectedFloor = '1st Floor';
  String _selectedRoomType = 'Laboratory';
  String _selectedStatus = 'available';
  bool _qrGenerated = false;
  bool _isSaving = false;
  String _generatedQrData = '';

  final List<String> _floors = [
    '1st Floor',
    '2nd Floor',
    '3rd Floor',
    '4th Floor',
  ];
  final List<String> _roomTypes = [
    'Laboratory',
    'Lecture Hall',
    'Seminar Room',
    'Office',
  ];

  @override
  void initState() {
    super.initState();
    _loadDropdownOptions();
  }

  Future<void> _loadDropdownOptions({
    String? preferredBuilding,
    String? preferredDepartment,
  }) async {
    final buildings = await _dropdownHelper.getBuildingNames();
    final departments = await _dropdownHelper.getDepartmentNames();

    if (!mounted) return;

    setState(() {
      _buildingOptions = buildings;
      _departmentOptions = departments;

      if (_buildingOptions.isNotEmpty) {
        final desiredBuilding = preferredBuilding ?? _selectedBuilding;
        _selectedBuilding = _buildingOptions.contains(desiredBuilding)
            ? desiredBuilding
            : _buildingOptions.first;
      } else {
        _selectedBuilding = preferredBuilding ?? _selectedBuilding;
      }
      _buildingController.text = _selectedBuilding;

      final desiredDepartment = preferredDepartment ?? _selectedDepartment;
      if (desiredDepartment == _noDepartmentOption || desiredDepartment.isEmpty) {
        _selectedDepartment = _noDepartmentOption;
      } else {
        _selectedDepartment = _departmentOptions.contains(desiredDepartment)
            ? desiredDepartment
            : _noDepartmentOption;
      }
      _departmentController.text =
          _selectedDepartment == _noDepartmentOption ? '' : _selectedDepartment;
    });
  }

  Future<void> _handleBuildingSelection(String? value) async {
    if (value == null) return;

    if (value == _addBuildingOption) {
      final newBuilding = await _showAddOptionDialog(
        title: 'Add Building',
        hintText: 'Enter building name',
      );
      if (newBuilding == null) return;

      await BuildingService.findOrCreateByName(newBuilding);
      _dropdownHelper.clearCache();
      await _loadDropdownOptions(preferredBuilding: newBuilding);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Building "$newBuilding" is now available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedBuilding = value;
      _buildingController.text = value;
      _qrGenerated = false;
      _generatedQrData = '';
    });
  }

  Future<void> _handleDepartmentSelection(String? value) async {
    if (value == null) return;

    if (value == _addDepartmentOption) {
      final newDepartment = await _showAddOptionDialog(
        title: 'Add Department',
        hintText: 'Enter department name',
      );
      if (newDepartment == null) return;

      await DepartmentService.findOrCreateByName(newDepartment);
      _dropdownHelper.clearCache();
      await _loadDropdownOptions(preferredDepartment: newDepartment);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Department "$newDepartment" is now available.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedDepartment = value;
      _departmentController.text =
          value == _noDepartmentOption ? '' : value;
      _qrGenerated = false;
      _generatedQrData = '';
    });
  }

  Future<String?> _showAddOptionDialog({
    required String title,
    required String hintText,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buildingController.dispose();
    _departmentController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _generateQRCode() {
    if (_nameController.text.isEmpty || _selectedBuilding.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in Room Name and Building first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final qrData =
      'PSU-ROOM-${_nameController.text}-$_selectedBuilding-${const Uuid().v4().substring(0, 8)}';
    setState(() {
      _qrGenerated = true;
      _generatedQrData = qrData;
    });
  }

  void _showConfirmDialog() {
    if (_nameController.text.isEmpty || _selectedBuilding.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in required fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_qrGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate a QR code first before saving'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4169E1).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Color(0xFF4169E1),
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm New Room',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to add this room\nto the system?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // close dialog
                          _performSave();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4169E1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final roomId = await RoomService.generateNextId();
      final buildingName = _selectedBuilding.trim();
      final departmentName =
          _selectedDepartment == _noDepartmentOption ? '' : _selectedDepartment.trim();
      final qrData = _generatedQrData.isNotEmpty
          ? _generatedQrData
          : 'PSU-ROOM-${_nameController.text}-$buildingName-$roomId';

      // Find or create building/department in database
      final building = await BuildingService.findOrCreateByName(buildingName);
      String departmentId = '';
      if (departmentName.isNotEmpty) {
        final dept = await DepartmentService.findOrCreateByName(departmentName);
        departmentId = dept.id;
      }

      final room = Room(
        id: roomId,
        name: _nameController.text.trim(),
        buildingId: building.id,
        building: building.name,
        floor: _selectedFloor,
        seats: int.tryParse(_capacityController.text) ?? 40,
        departmentId: departmentId,
        department: departmentName,
        roomType: _selectedRoomType,
        status: _selectedStatus,
        qrCodeData: qrData,
      );

      // Check for duplicate room name
      final existingRoom = await RoomService.fetchByName(_nameController.text.trim());
      if (existingRoom != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Already Exist'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      await RoomService.insert(room);

      // Save QR code history
      await QRCodeHistoryService.saveQRCode(
        roomId: roomId,
        qrCodeValue: qrData,
        qrCodeImage: null,
        roomName: _nameController.text.trim(),
        building: buildingName.isNotEmpty ? buildingName : null,
        department: departmentName.isNotEmpty ? departmentName : null,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomSuccessPage(
            isEdit: false,
            roomName: _nameController.text,
            building: building.name,
            floor: _selectedFloor,
            department: departmentName,
            status: _selectedStatus,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving room: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add New Room',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF4169E1)),
            tooltip: 'QR Code History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QRCodeHistoryPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room Information Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: const Color(0xFF4169E1)),
                      const SizedBox(width: 8),
                      const Text(
                        'Room Information',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Room Name
                  _buildLabel('Room Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _nameController,
                    hint: 'e.g., CLR 2',
                  ),
                  const SizedBox(height: 18),

                  // Building
                  _buildLabel('Building'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedBuilding.isEmpty ? null : _selectedBuilding,
                    hintText: 'Select building',
                    items: [..._buildingOptions, _addBuildingOption],
                    onChanged: _handleBuildingSelection,
                  ),
                  const SizedBox(height: 18),

                  // Floor
                  _buildLabel('Floor'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedFloor,
                    items: _floors,
                    onChanged: (v) =>
                        setState(() => _selectedFloor = v ?? _selectedFloor),
                  ),
                  const SizedBox(height: 18),

                  // Department
                  _buildLabel('Department'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedDepartment,
                    items: [
                      _noDepartmentOption,
                      ..._departmentOptions,
                      _addDepartmentOption,
                    ],
                    onChanged: _handleDepartmentSelection,
                  ),
                  const SizedBox(height: 18),

                  // Capacity
                  _buildLabel('Capacity'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _capacityController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),

                  // Room Type
                  _buildLabel('Room Type'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedRoomType,
                    items: _roomTypes,
                    onChanged: (v) =>
                        setState(() => _selectedRoomType = v ?? _selectedRoomType),
                  ),
                  const SizedBox(height: 18),

                  // Status
                  _buildLabel('Status'),
                  const SizedBox(height: 10),
                  _buildStatusChips(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Generate QR Code Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _qrGenerated ? null : _generateQRCode,
                icon: Icon(Icons.qr_code, color: _qrGenerated ? Colors.grey : Colors.white, size: 20),
                label: Text(
                  _qrGenerated ? 'QR Code Generated' : 'Generate QR Code',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _qrGenerated ? Colors.grey : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _qrGenerated ? Colors.grey.shade200 : const Color(0xFF4169E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // QR Code Preview (shown after generate)
            if (_qrGenerated)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: QrImageView(
                          data: _generatedQrData,
                          version: QrVersions.auto,
                          size: 180,
                          gapless: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nameController.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedBuilding.isEmpty ? 'No building selected' : _selectedBuilding} • $_selectedFloor',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This QR code will be saved as a PDF when you create the room',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _showConfirmDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Room',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: hintText != null
              ? Text(
                  hintText,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                )
              : null,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatusChips() {
    final statuses = [
      {'key': 'available', 'label': 'Available'},
      {'key': 'reserved', 'label': 'Reserved'},
      {'key': 'maintenance', 'label': 'Under Maintenance'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final key = s['key'] as String;
        final label = s['label'] as String;
        final isSelected = _selectedStatus == key;

        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4169E1) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4169E1)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
