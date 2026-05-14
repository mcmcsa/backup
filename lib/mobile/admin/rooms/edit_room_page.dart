import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/floor_service.dart';
import '../../../shared/services/room_type_service.dart';
import '../../../shared/services/qr_code_history_service.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import 'room_success_page.dart';

class EditRoomPage extends StatefulWidget {
  final Room room;

  const EditRoomPage({super.key, required this.room});

  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  static const String _noDepartmentOption = 'Not specified';

  final _dropdownHelper = DropdownDataHelper();
  late TextEditingController _roomCodeController;
  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  List<String> _buildingOptions = [];
  List<String> _departmentOptions = [];
  List<String> _floors = [];
  List<String> _roomTypes = [];
  String _selectedBuilding = '';
  String _selectedDepartment = _noDepartmentOption;
  late String _selectedFloor;
  late String _selectedRoomType;
  late String _selectedStatus;
  bool _isSaving = false;
  String _qrData = '';

  bool get _isDepartmentSelected =>
      _selectedDepartment != _noDepartmentOption &&
      _selectedDepartment.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final roomCode = widget.room.code.isNotEmpty ? widget.room.code : widget.room.id;
    _roomCodeController = TextEditingController(text: roomCode);
    _nameController = TextEditingController(text: widget.room.name);
    _capacityController =
        TextEditingController(text: widget.room.seats.toString());
    _selectedBuilding = widget.room.building;
    _selectedDepartment = widget.room.department.isEmpty
      ? _noDepartmentOption
      : widget.room.department;
    _selectedFloor = widget.room.floor;
    _selectedRoomType = widget.room.roomType;
    _selectedStatus = widget.room.status;
    _qrData = (widget.room.qrCodeData != null && widget.room.qrCodeData!.trim().isNotEmpty)
        ? widget.room.qrCodeData!.trim()
        : RoomService.buildQrCodePayload(
            roomCode: roomCode,
            roomName: widget.room.name,
            buildingName: widget.room.building,
            departmentName: widget.room.department,
            floor: widget.room.floor,
            roomType: widget.room.roomType,
            status: widget.room.status,
          );
    _loadDropdownOptions();
  }

  Future<void> _loadDropdownOptions() async {
    final departments = await _dropdownHelper.getDepartmentNames();
    final floors = await _dropdownHelper.getFloorNames();
    final roomTypes = await _dropdownHelper.getRoomTypes();
    if (!mounted) return;

    setState(() {
      _departmentOptions = _uniqueNonEmpty(departments);
      _floors = _uniqueNonEmpty(floors);
      _roomTypes = _uniqueNonEmpty(roomTypes);

      if (_selectedDepartment != _noDepartmentOption &&
          !_departmentOptions.contains(_selectedDepartment)) {
        _selectedDepartment = _noDepartmentOption;
      }

      if (_roomTypes.isNotEmpty && !_roomTypes.contains(_selectedRoomType)) {
        _roomTypes = [..._roomTypes, _selectedRoomType];
      }

      if (_floors.isNotEmpty && !_floors.contains(_selectedFloor)) {
        _floors = [..._floors, _selectedFloor];
      }
    });

    await _loadBuildingsByDepartment(_selectedDepartment);
  }

  Future<void> _loadBuildingsByDepartment(String departmentName) async {
    final normalizedDepartment = departmentName.trim();
    if (normalizedDepartment == _noDepartmentOption ||
        normalizedDepartment.isEmpty) {
      if (!mounted) return;
      setState(() {
        _buildingOptions = [];
        _selectedBuilding = '';
      });
      return;
    }

    final department = await _dropdownHelper.getDepartmentByName(normalizedDepartment);
    if (department == null) {
      if (!mounted) return;
      setState(() {
        _buildingOptions = [];
        _selectedBuilding = '';
      });
      return;
    }

    final buildings = _uniqueNonEmpty(
      await _dropdownHelper.getBuildingNamesByDepartment(department.id),
    );

    if (!mounted) return;
    setState(() {
      _buildingOptions = buildings;
      if (!_buildingOptions.contains(_selectedBuilding)) {
        _selectedBuilding = _buildingOptions.isNotEmpty
            ? _buildingOptions.first
            : '';
      }
    });
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _showSaveConfirmation() {
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
                'Save Changes?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to save these\nchanges to ${_nameController.text}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
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
        final buildingName = _selectedBuilding.trim();
        final departmentName =
          _selectedDepartment == _noDepartmentOption ? '' : _selectedDepartment.trim();

      if (departmentName.isEmpty) {
        throw Exception('Please select a department');
      }

      final department = await _dropdownHelper.getDepartmentByName(departmentName);
      if (department == null) {
        throw Exception('Selected department was not found');
      }

      final building = await BuildingService.fetchByNameAndDepartment(
        buildingName,
        department.id,
      );
      if (building == null) {
        throw Exception('Selected building was not found under the selected department');
      }

      final departmentId = department.id;
      final floor = await FloorService.findOrCreateByName(_selectedFloor);
      final roomType = await RoomTypeService.fetchByName(_selectedRoomType);
      if (roomType == null) {
        throw Exception('Selected room type was not found');
      }

      final qrData = RoomService.buildQrCodePayload(
        roomCode: _roomCodeController.text.trim(),
        roomName: _nameController.text.trim(),
        buildingName: building.name,
        departmentName: departmentName,
        floor: _selectedFloor,
        roomType: _selectedRoomType,
        status: _selectedStatus,
      );

      final updatedRoom = Room(
        id: widget.room.id,
        code: _roomCodeController.text.trim().isNotEmpty
            ? _roomCodeController.text.trim()
            : (widget.room.code.isNotEmpty ? widget.room.code : widget.room.id),
        name: _nameController.text.trim(),
        buildingId: building.id,
        building: building.name,
        floorId: floor.id,
        floor: _selectedFloor,
        seats: int.tryParse(_capacityController.text) ?? widget.room.seats,
        departmentId: departmentId,
        department: departmentName,
        roomTypeId: roomType.id,
        roomType: _selectedRoomType,
        status: _selectedStatus,
        imageUrl: widget.room.imageUrl,
        qrCodeData: qrData,
      );

      await RoomService.update(updatedRoom);
      await QRCodeHistoryService.updateRoomMetadata(
        roomId: widget.room.id,
        roomName: _nameController.text.trim(),
        building: building.name,
        department: departmentName,
      );
      _qrData = qrData;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoomSuccessPage(
            isEdit: true,
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
          SnackBar(content: Text('Error updating room: $e'), backgroundColor: Colors.red),
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
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Room',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
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
                  _buildLabel('Room Code'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _roomCodeController,
                    hint: 'Room code',
                    readOnly: true,
                  ),
                  const SizedBox(height: 18),

                  // Room Name
                  _buildLabel('Room Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _nameController,
                    hint: 'e.g., CLR 2',
                  ),
                  const SizedBox(height: 18),

                  // Building
                  // Department
                  _buildLabel('Department'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedDepartment,
                    items: [_noDepartmentOption, ..._departmentOptions],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _selectedDepartment = v);
                      await _loadBuildingsByDepartment(v);
                    },
                  ),
                  const SizedBox(height: 18),

                  // Building
                  _buildLabel('Building'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _selectedBuilding,
                    items: _buildingOptions,
                    onChanged: _isDepartmentSelected
                        ? (v) {
                      if (v == null) return;
                      setState(() => _selectedBuilding = v);
                    }
                        : null,
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

            // QR Code Preview
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
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 180,
                        gapless: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_roomCodeController.text.trim()} - ${_nameController.text.trim()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedBuilding.isEmpty ? 'No building' : _selectedBuilding} • $_selectedFloor',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'QR code value is locked for existing rooms.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
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
                      onPressed: _isSaving ? null : _showSaveConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Changes',
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
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final normalizedItems = _uniqueNonEmpty(items);
    final matchingCount = normalizedItems.where((item) => item == value).length;
    final effectiveValue = matchingCount == 1 ? value : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          hint: const Text('Select option'),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          items: normalizedItems
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<String> _uniqueNonEmpty(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) result.add(trimmed);
    }
    return result;
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



