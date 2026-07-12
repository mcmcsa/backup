import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/utils/app_route_observer.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/floor_service.dart';
import '../../../shared/services/room_type_service.dart';
import '../../../shared/services/app_settings_service.dart';
import '../../../shared/services/qr_code_history_service.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import 'room_success_page.dart';

class AddRoomPage extends StatefulWidget {
  const AddRoomPage({super.key});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> with RouteAware {
  static const String _noDepartmentOption = 'Not specified';

  final _dropdownHelper = DropdownDataHelper();
  final _roomCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _buildingController = TextEditingController();
  final _departmentController = TextEditingController();
  final _capacityController = TextEditingController();
  List<String> _departmentOptions = [];
  List<String> _buildingOptionsByDepartment = [];
  List<String> _floors = [];
  List<String> _roomTypes = [];
  String _selectedBuilding = '';
  String _selectedDepartment = _noDepartmentOption;
  String _selectedFloor = '';
  String _selectedRoomType = '';
  String _selectedStatus = 'available';
  List<Room> _existingRooms = [];
  bool _qrGenerated = false;
  bool _isSaving = false;
  String _generatedQrData = '';
  bool _allowQrRegeneration = false;

  bool get _isDepartmentSelected =>
      _selectedDepartment != _noDepartmentOption &&
      _selectedDepartment.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _dropdownHelper.clearCache();
    _loadDropdownOptions();
    _loadExistingRooms();
    _loadQrRegenerationSetting();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _dropdownHelper.clearCache();
    _loadDropdownOptions();
    _loadExistingRooms();
  }

  Future<void> _loadQrRegenerationSetting() async {
    final enabled = await AppSettingsService.isQrRegenerationEnabled();
    if (!mounted) return;
    setState(() => _allowQrRegeneration = enabled);
  }

  Future<void> _loadExistingRooms() async {
    try {
      final rooms = await RoomService.fetchAll();
      if (!mounted) return;
      setState(() => _existingRooms = rooms);
    } catch (_) {}
  }

  List<Room> get _matchingRooms {
    if (_selectedBuilding.isEmpty ||
        _selectedDepartment == _noDepartmentOption ||
        _selectedDepartment.isEmpty ||
        _selectedRoomType.isEmpty) {
      return const [];
    }

    return _existingRooms.where((room) {
      final buildingMatch = room.building.toLowerCase() == _selectedBuilding.toLowerCase();
      final departmentMatch = room.department.toLowerCase() == _selectedDepartment.toLowerCase();
      final typeMatch = room.roomType.toLowerCase() == _selectedRoomType.toLowerCase();
      return buildingMatch && departmentMatch && typeMatch;
    }).toList();
  }

  Future<void> _loadDropdownOptions({
    String? preferredDepartment,
    String? preferredFloor,
  }) async {
    final departments = await _dropdownHelper.getDepartmentNames();
    final floors = await _dropdownHelper.getFloorNames();
    final roomTypes = await _dropdownHelper.getRoomTypes();

    if (!mounted) return;

    setState(() {
      _departmentOptions = departments;
      _floors = floors;
      _roomTypes = roomTypes;

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

      if (_floors.isNotEmpty) {
        final desiredFloor = preferredFloor ?? _selectedFloor;
        _selectedFloor =
            _floors.contains(desiredFloor) ? desiredFloor : _floors.first;
      } else {
        _selectedFloor = preferredFloor ?? _selectedFloor;
      }

      if (_roomTypes.isNotEmpty) {
        if (!_roomTypes.contains(_selectedRoomType)) {
          _selectedRoomType = _roomTypes.first;
        }
      } else {
        _selectedRoomType = '';
      }
    });

    if (_selectedDepartment != _noDepartmentOption && _selectedDepartment.isNotEmpty) {
      await _loadBuildingsByDepartment(_selectedDepartment);
    }
  }

  Future<void> _handleBuildingSelection(String? value) async {
    if (value == null) return;

    setState(() {
      _selectedBuilding = value;
      _buildingController.text = value;
      _qrGenerated = false;
      _generatedQrData = '';
    });
  }

  Future<void> _loadBuildingsByDepartment(String departmentName) async {
    try {
      final normalizedDepartment = departmentName.trim();
      if (normalizedDepartment == _noDepartmentOption ||
          normalizedDepartment.isEmpty) {
        // Building must remain disabled until a department is selected.
        setState(() {
          _buildingOptionsByDepartment = [];
          _selectedBuilding = '';
          _buildingController.text = '';
          _qrGenerated = false;
          _generatedQrData = '';
        });
        return;
      }

      // Get the department object to get its ID
      final department =
          await _dropdownHelper.getDepartmentByName(normalizedDepartment);
      if (department == null) {
        setState(() {
          _buildingOptionsByDepartment = [];
          _selectedBuilding = '';
          _buildingController.text = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Department "$normalizedDepartment" was not found.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final matchingBuildings = await _dropdownHelper.getBuildingNamesByDepartment(department.id);
      
      if (!mounted) return;
      setState(() {
        _buildingOptionsByDepartment = matchingBuildings;
        final currentBuilding = _selectedBuilding;
        _selectedBuilding = matchingBuildings.contains(currentBuilding)
            ? currentBuilding
            : (matchingBuildings.isNotEmpty ? matchingBuildings.first : '');
        _buildingController.text = _selectedBuilding;
        _qrGenerated = false;
        _generatedQrData = '';
      });

      if (matchingBuildings.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No buildings found under $normalizedDepartment yet.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading buildings for this department: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDepartmentSelection(String? value) async {
    if (value == null) return;

    setState(() {
      _selectedDepartment = value;
      _departmentController.text =
          value == _noDepartmentOption ? '' : value;
    });
    
    // Load buildings for the selected department
    await _loadBuildingsByDepartment(value);
  }

  void _handleRoomTypeSelection(String? value) {
    if (value == null) return;
    setState(() {
      _selectedRoomType = value;
      _qrGenerated = false;
      _generatedQrData = '';
    });
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _roomCodeController.dispose();
    _nameController.dispose();
    _buildingController.dispose();
    _departmentController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _generateQRCode() {
    if (_roomCodeController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _selectedBuilding.isEmpty ||
        _selectedDepartment == _noDepartmentOption) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in room code, room name, department, and building first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final qrData = 'ROOM:${_roomCodeController.text.trim().toUpperCase()}';
    setState(() {
      _qrGenerated = true;
      _generatedQrData = qrData;
    });
  }

  void _showConfirmDialog() {
    if (_roomCodeController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _selectedDepartment == _noDepartmentOption ||
        _selectedBuilding.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department and building first'),
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
        final roomCode = _roomCodeController.text.trim().toUpperCase();
      final buildingName = _selectedBuilding.trim();
      final departmentName =
          _selectedDepartment == _noDepartmentOption ? '' : _selectedDepartment.trim();
      final qrData = _generatedQrData.isNotEmpty
          ? _generatedQrData
          : 'ROOM:${roomCode.toUpperCase()}';

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

      final room = Room(
        id: '',
        code: roomCode,
        name: _nameController.text.trim(),
        buildingId: building.id,
        building: building.name,
        floorId: floor.id,
        floor: _selectedFloor,
        seats: int.tryParse(_capacityController.text) ?? 40,
        departmentId: departmentId,
        department: departmentName,
        roomTypeId: roomType.id,
        roomType: _selectedRoomType,
        status: _selectedStatus,
        qrCodeData: qrData,
      );

      // Check for duplicate room code
      final existingByCode = await RoomService.fetchByCode(roomCode);
      if (existingByCode != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room Code already exists'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      // Check for duplicate room name (skipping API call since fetchByName is unsupported)

      await RoomService.insert(room);
      final insertedRoom = await RoomService.fetchByCode(roomCode);
      if (insertedRoom == null) {
        throw Exception('Failed to resolve inserted room UUID.');
      }

      // Save QR code history
      await QRCodeHistoryService.saveQRCode(
        roomId: insertedRoom.id,
        qrCodeValue: qrData,
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
        backgroundColor: const Color(0xFFF2F4F7),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        elevation: 1,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_matchingRooms.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Existing Rooms For Selected Department, Building, and Room Type',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._matchingRooms.take(3).map(
                      (room) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${room.id} - ${room.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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

                  // Room Code
                  _buildTextField(
                    _roomCodeController,
                    hint: 'Room Code (e.g., CLR 2)',
                  ),
                  const SizedBox(height: 18),

                  // Room Name
                  _buildTextField(
                    _nameController,
                    hint: 'Room name (e.g., Computer Laboratory Room 1)',
                  ),
                  const SizedBox(height: 18),

                  // Department
                  _buildDropdown(
                    value: _selectedDepartment == _noDepartmentOption
                        ? null
                        : _selectedDepartment,
                    hintText: 'Select department',
                    items: [
                      _noDepartmentOption,
                      ..._departmentOptions,
                    ],
                    onChanged: _handleDepartmentSelection,
                  ),
                  const SizedBox(height: 18),

                  // Building
                  _buildDropdown(
                    value: _selectedBuilding.isEmpty ? null : _selectedBuilding,
                    hintText: _isDepartmentSelected
                        ? 'Select building'
                        : 'Select department first',
                    items: _buildingOptionsByDepartment,
                    onChanged:
                        _isDepartmentSelected ? _handleBuildingSelection : null,
                  ),
                  const SizedBox(height: 18),

                  // Floor
                  _buildDropdown(
                    value: _selectedFloor.isEmpty ? null : _selectedFloor,
                    hintText: 'Select floor',
                    items: _floors,
                    onChanged: (v) =>
                        setState(() => _selectedFloor = v ?? _selectedFloor),
                  ),
                  const SizedBox(height: 18),

                  // Capacity
                  _buildTextField(
                    _capacityController,
                    hint: 'Room Capacity',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),

                  // Room Type
                  _buildDropdown(
                    value: _selectedRoomType.isEmpty ? null : _selectedRoomType,
                    hintText: 'Select room type',
                    items: _roomTypes,
                    onChanged: _handleRoomTypeSelection,
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
                onPressed: _qrGenerated
                    ? (_allowQrRegeneration ? _generateQRCode : null)
                    : _generateQRCode,
                icon: Icon(Icons.qr_code, color: _qrGenerated ? Colors.grey : Colors.white, size: 20),
                label: Text(
                  _qrGenerated
                      ? (_allowQrRegeneration
                          ? 'Regenerate QR Code'
                          : 'QR Code Generated')
                      : 'Generate QR Code',
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
                        '${_roomCodeController.text.trim()} - ${_nameController.text.trim()}',
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
        color: Colors.white,
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
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth <= 430;

    final statuses = [
      {'key': 'available', 'label': 'Available'},
      {'key': 'reserved', 'label': 'Reserved'},
      {'key': 'maintenance', 'label': 'Under Maintenance'},
    ];

    return Wrap(
      spacing: isCompact ? 6 : 8,
      runSpacing: isCompact ? 6 : 8,
      children: statuses.map((s) {
        final key = s['key'] as String;
        final label = s['label'] as String;
        final isSelected = _selectedStatus == key;

        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = key),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 14,
              vertical: isCompact ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4169E1) : Colors.white,
              borderRadius: BorderRadius.circular(isCompact ? 18 : 20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4169E1)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 11 : 12,
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
