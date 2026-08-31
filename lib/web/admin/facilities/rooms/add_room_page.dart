import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../shared/utils/app_route_observer.dart';
import '../../../../shared/models/room_model.dart';
import '../../../../shared/services/room_service.dart';
import '../../../../shared/services/building_service.dart';
import '../../../../shared/services/floor_service.dart';
import '../../../../shared/services/room_type_service.dart';
import '../../../../shared/services/app_settings_service.dart';
import '../../../../shared/services/qr_code_history_service.dart';
import '../../../../shared/utils/dropdown_data_helper.dart';
import '../../shared/admin_styles.dart';

class AddRoomPage extends StatefulWidget {
  final VoidCallback? onClose;

  const AddRoomPage({super.key, this.onClose});

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
  bool _qrGenerated = false;
  bool _isSaving = false;
  String _generatedQrData = '';
  bool _allowQrRegeneration = false;

  bool get _isDepartmentSelected =>
      _selectedDepartment != _noDepartmentOption &&
      _selectedDepartment.isNotEmpty;

  void _closePage() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _dropdownHelper.clearCache();
    _loadDropdownOptions();
    _loadQrRegenerationSetting();
    _roomCodeController.addListener(_forceUppercase);
  }

  void _forceUppercase() {
    final text = _roomCodeController.text;
    final upper = text.toUpperCase();
    if (text != upper) {
      _roomCodeController.value = _roomCodeController.value.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
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
  }

  Future<void> _loadQrRegenerationSetting() async {
    final enabled = await AppSettingsService.isQrRegenerationEnabled();
    if (!mounted) return;
    setState(() => _allowQrRegeneration = enabled);
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
      if (desiredDepartment == _noDepartmentOption ||
          desiredDepartment.isEmpty) {
        _selectedDepartment = _noDepartmentOption;
      } else {
        _selectedDepartment = _departmentOptions.contains(desiredDepartment)
            ? desiredDepartment
            : _noDepartmentOption;
      }
      _departmentController.text = _selectedDepartment == _noDepartmentOption
          ? ''
          : _selectedDepartment;

      if (_floors.isNotEmpty) {
        final desiredFloor = preferredFloor ?? _selectedFloor;
        _selectedFloor = _floors.contains(desiredFloor)
            ? desiredFloor
            : _floors.first;
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

    if (_selectedDepartment != _noDepartmentOption &&
        _selectedDepartment.isNotEmpty) {
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
      final department = await _dropdownHelper.getDepartmentByName(
        normalizedDepartment,
      );
      if (department == null) {
        setState(() {
          _buildingOptionsByDepartment = [];
          _selectedBuilding = '';
          _buildingController.text = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Department "$normalizedDepartment" was not found.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final matchingBuildings = await _dropdownHelper
          .getBuildingNamesByDepartment(department.id);

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
            content: Text(
              'No buildings found under $normalizedDepartment yet.',
            ),
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
      _departmentController.text = value == _noDepartmentOption ? '' : value;
    });

    // Load buildings for the selected department
    await _loadBuildingsByDepartment(value);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _roomCodeController.removeListener(_forceUppercase);
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
        _nameController.text.isEmpty ||
        _selectedDepartment == _noDepartmentOption ||
        _selectedBuilding.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in Room Code, Department, and Building first',
          ),
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B1324).withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEAF1FF), Color(0xFFDCE8FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFF4169E1,
                          ).withValues(alpha: 0.28),
                          width: 1.6,
                        ),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF3556C8),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Confirm New Room',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will create a new room profile and save the generated QR code to the system.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD7E3FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Room Code: ${_roomCodeController.text.trim()}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Building: $_selectedBuilding',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stackButtons = constraints.maxWidth < 420;
                        if (stackButtons) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context); // close dialog
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          _performSave();
                                        });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3556C8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Confirm & Save',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context); // close dialog
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          _performSave();
                                        });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3556C8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Confirm & Save',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    var didNavigate = false;

    try {
      final roomCode = _roomCodeController.text.trim();
      if (roomCode.isEmpty) {
        throw Exception('Room Code is required');
      }
      final buildingName = _selectedBuilding.trim();
      final departmentName = _selectedDepartment == _noDepartmentOption
          ? ''
          : _selectedDepartment.trim();
      final qrData = _generatedQrData.isNotEmpty
          ? _generatedQrData
          : 'ROOM:${roomCode.toUpperCase()}';

      // Find or create building/department in database
      final department = await _dropdownHelper.getDepartmentByName(
        departmentName,
      );
      if (department == null) {
        throw Exception('Selected department was not found');
      }

      final building = await BuildingService.fetchByNameAndDepartment(
        buildingName,
        department.id,
      );
      if (building == null) {
        throw Exception(
          'Selected building was not found under the selected department',
        );
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
      didNavigate = true;
      // Legacy flow kept for reference:
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => RoomSuccessPage(
      //       isEdit: false,
      //       roomName: _nameController.text,
      //       building: building.name,
      //       floor: _selectedFloor,
      //       department: departmentName,
      //       status: _selectedStatus,
      //       onDone: widget.onClose,
      //     ),
      //   ),
      // );

      await _showTimedSuccessMessageDialog(
        roomName: _nameController.text.trim(),
        building: building.name,
        floor: _selectedFloor,
        department: departmentName,
        status: _selectedStatus,
      );

      if (mounted) {
        _closePage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted && !didNavigate) setState(() => _isSaving = false);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'AVAILABLE';
      case 'reserved':
        return 'RESERVED';
      case 'maintenance':
        return 'UNAVAILABLE';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF22C55E);
      case 'reserved':
        return const Color(0xFFF59E0B);
      case 'maintenance':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  Widget _successInfoRow(
    String label,
    String value, {
    required bool isCompact,
  }) {
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successStatusRow(
    String label,
    String value,
    Color color, {
    required bool isCompact,
  }) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTimedSuccessMessageDialog({
    required String roomName,
    required String building,
    required String floor,
    required String department,
    required String status,
  }) async {
    if (!mounted) return;

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'room-added-success',
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        return SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 460;
                    return Container(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 18 : 24,
                        isCompact ? 18 : 22,
                        isCompact ? 18 : 24,
                        isCompact ? 16 : 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF0EA5E9)],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFDCFCE7),
                                      Color(0xFFBBF7D0),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Room Added Successfully',
                                  style: TextStyle(
                                    fontSize: isCompact ? 19 : 23,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    height: 1.2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'The new room has been registered in the PSU MMS.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Color(0xFF64748B),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isCompact ? 14 : 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _successInfoRow(
                                  'Room Name',
                                  roomName,
                                  isCompact: isCompact,
                                ),
                                _successInfoRow(
                                  'Building',
                                  building,
                                  isCompact: isCompact,
                                ),
                                _successInfoRow(
                                  'Floor',
                                  floor,
                                  isCompact: isCompact,
                                ),
                                if (department.isNotEmpty)
                                  _successInfoRow(
                                    'Department',
                                    department,
                                    isCompact: isCompact,
                                  ),
                                _successStatusRow(
                                  'Status',
                                  _statusLabel(status),
                                  _statusColor(status),
                                  isCompact: isCompact,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 1.0, end: 0.0),
                            duration: const Duration(seconds: 3),
                            builder: (context, value, _) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 5,
                                  value: value,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF22C55E),
                                      ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Closing in 3 seconds...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Scaffold(
      backgroundColor: AdminStyles.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 32,
            vertical: isCompact ? 16 : 24,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildFormPanel()),
                  if (!isCompact) const SizedBox(width: 24),
                  if (isCompact) const SizedBox(height: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildQrPanel(),
                        const SizedBox(height: 24),
                        _buildActionsPanel(),
                      ],
                    ),
                  ),
                ],
              );

              if (isCompact) {
                // Legacy mobile-like app bar flow kept for reference.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add New Room', style: AdminStyles.pageTitleStyle()),
                    const SizedBox(height: 6),
                    Text(
                      'Create a new room profile and generate a QR code before saving.',
                      style: AdminStyles.pageSubtitleStyle(),
                    ),
                    const SizedBox(height: 20),
                    _buildFormPanel(),
                    const SizedBox(height: 20),
                    _buildQrPanel(),
                    const SizedBox(height: 20),
                    _buildActionsPanel(),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add New Room', style: AdminStyles.pageTitleStyle()),
                  const SizedBox(height: 6),
                  Text(
                    'Create a new room profile and generate a QR code before saving.',
                    style: AdminStyles.pageSubtitleStyle(),
                  ),
                  const SizedBox(height: 20),
                  content,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AdminStyles.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Room Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFieldBlock(
            label: 'Room Code',
            child: _buildTextField(_roomCodeController, hint: 'e.g., CLR 2'),
          ),
          _buildFieldBlock(
            label: 'Room Name',
            child: _buildTextField(
              _nameController,
              hint: 'e.g., Computer Laboratory Room 2',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildFieldBlock(
                  label: 'Department',
                  child: _buildDropdown(
                    value: _selectedDepartment == _noDepartmentOption
                        ? null
                        : _selectedDepartment,
                    hintText: 'Select department',
                    items: [_noDepartmentOption, ..._departmentOptions],
                    onChanged: _handleDepartmentSelection,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFieldBlock(
                  label: 'Building',
                  child: _buildDropdown(
                    value: _selectedBuilding.isEmpty ? null : _selectedBuilding,
                    hintText: _isDepartmentSelected
                        ? 'Select building'
                        : 'Select department first',
                    items: _buildingOptionsByDepartment,
                    onChanged: _isDepartmentSelected
                        ? _handleBuildingSelection
                        : null,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildFieldBlock(
                  label: 'Floor',
                  child: _buildDropdown(
                    value: _selectedFloor.isEmpty ? null : _selectedFloor,
                    hintText: 'Select floor',
                    items: _floors,
                    onChanged: (v) =>
                        setState(() => _selectedFloor = v ?? _selectedFloor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFieldBlock(
                  label: 'Room Type',
                  child: _buildDropdown(
                    value: _selectedRoomType.isEmpty ? null : _selectedRoomType,
                    hintText: 'Select room type',
                    items: _roomTypes,
                    onChanged: (v) => setState(
                      () => _selectedRoomType = v ?? _selectedRoomType,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildFieldBlock(
                  label: 'Capacity',
                  child: _buildTextField(
                    _capacityController,
                    hint: 'Room Capacity',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFieldBlock(
                  label: 'Status',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _buildStatusChips(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: AdminStyles.cardDecoration(borderRadius: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminStyles.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 20,
                  color: AdminStyles.secondary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'QR Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _qrGenerated
                ? QrImageView(
                    data: _generatedQrData,
                    version: QrVersions.auto,
                    size: 180,
                    gapless: true,
                  )
                : Center(
                    child: Text(
                      'Generate a QR code\nfor preview',
                      textAlign: TextAlign.center,
                      style: AdminStyles.bodyStyle(
                        fontSize: 12,
                        color: AdminStyles.textMuted,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            _nameController.text.trim().isEmpty
                ? 'New Room'
                : _nameController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedBuilding.isEmpty ? 'No building selected' : _selectedBuilding} • ${_selectedFloor.isEmpty ? '-' : _selectedFloor}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          const Text(
            'This QR code will be saved when you create the room.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          FractionallySizedBox(
            widthFactor: 0.5,
            child: SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _qrGenerated
                    ? (_allowQrRegeneration ? _generateQRCode : null)
                    : _generateQRCode,
                icon: Icon(
                  Icons.qr_code,
                  color: _qrGenerated ? Colors.grey.shade600 : Colors.white,
                  size: 18,
                ),
                label: Text(
                  _qrGenerated
                      ? (_allowQrRegeneration
                            ? 'Regenerate QR Code'
                            : 'QR Code Generated')
                      : 'Generate QR Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _qrGenerated ? Colors.grey.shade700 : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _qrGenerated
                      ? const Color(0xFFE5E7EB)
                      : AdminStyles.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions = constraints.maxWidth < 360;

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _closePage,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AdminStyles.bodyStyle(
                      fontWeight: FontWeight.w600,
                      color: AdminStyles.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _showConfirmDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                      : Text(
                          'Save Room',
                          style: AdminStyles.headingStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _closePage,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
              child: Text(
                'Cancel',
                style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _showConfirmDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminStyles.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Save Room',
                      style: AdminStyles.headingStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldBlock({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildLabel(label), const SizedBox(height: 8), child],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AdminStyles.bodyStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AdminStyles.textSecondary,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: AdminStyles.bodyStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AdminStyles.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AdminStyles.bodyStyle(
          fontSize: 14,
          color: AdminStyles.textMuted,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: const Color(0xFFFCFEFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AdminStyles.primary, width: 1.4),
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
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFCFEFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: hintText != null
              ? Text(
                  hintText,
                  style: AdminStyles.bodyStyle(
                    color: AdminStyles.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : null,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AdminStyles.textMuted,
          ),
          style: AdminStyles.bodyStyle(
            fontSize: 14,
            color: AdminStyles.textPrimary,
            fontWeight: FontWeight.w600,
          ),
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
      {'key': 'maintenance', 'label': 'Unavailable'},
    ];

    return Wrap(
      spacing: isCompact ? 6 : 8,
      runSpacing: isCompact ? 6 : 8,
      children: statuses.map((s) {
        final key = s['key'] as String;
        final label = s['label'] as String;
        final isSelected = _selectedStatus == key;

        final tone = key == 'maintenance'
            ? const Color(0xFFDC2626)
            : const Color(0xFF0F766E);

        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = key),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 14,
              vertical: isCompact ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? tone.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(isCompact ? 18 : 20),
              border: Border.all(
                color: isSelected
                    ? tone.withValues(alpha: 0.5)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? tone : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
