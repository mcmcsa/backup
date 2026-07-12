import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../shared/models/room_model.dart';
import '../../../../shared/services/building_service.dart';
import '../../../../shared/services/floor_service.dart';
import '../../../../shared/services/qr_code_history_service.dart';
import '../../../../shared/services/room_service.dart';
import '../../../../shared/services/room_type_service.dart';
import '../../../../shared/utils/dropdown_data_helper.dart';
import '../../shared/admin_styles.dart';

class AdminEditRoomPageWeb extends StatefulWidget {
  final Room room;
  final VoidCallback? onClose;

  const AdminEditRoomPageWeb({super.key, required this.room, this.onClose});

  @override
  State<AdminEditRoomPageWeb> createState() => _AdminEditRoomPageWebState();
}

class _AdminEditRoomPageWebState extends State<AdminEditRoomPageWeb> {
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
  bool _isTimedSuccessVisible = false;
  String _qrData = '';

  void _closePage() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    Navigator.pop(context);
  }

  bool get _isDepartmentSelected =>
      _selectedDepartment != _noDepartmentOption &&
      _selectedDepartment.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final roomCode = widget.room.code.isNotEmpty
        ? widget.room.code
        : widget.room.id;
    _roomCodeController = TextEditingController(text: roomCode);
    _nameController = TextEditingController(text: widget.room.name);
    _capacityController = TextEditingController(
      text: widget.room.seats.toString(),
    );
    _selectedBuilding = widget.room.building;
    _selectedDepartment = widget.room.department.isEmpty
        ? _noDepartmentOption
        : widget.room.department;
    _selectedFloor = widget.room.floor;
    _selectedRoomType = widget.room.roomType;
    _selectedStatus = widget.room.status == 'under_maintenance'
        ? 'maintenance'
        : widget.room.status;
    _qrData =
        (widget.room.qrCodeData != null &&
            widget.room.qrCodeData!.trim().isNotEmpty)
        ? widget.room.qrCodeData!.trim()
        : 'ROOM:$roomCode';
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

    final department = await _dropdownHelper.getDepartmentByName(
      normalizedDepartment,
    );
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
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF93C5FD,
                            ).withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Icon(
                          Icons.save_outlined,
                          color: AdminStyles.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Room Update',
                              style: AdminStyles.headingStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: AdminStyles.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This will apply your latest room changes to the system.',
                              style: AdminStyles.bodyStyle(
                                fontSize: 13,
                                color: AdminStyles.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Room Code',
                              style: AdminStyles.bodyStyle(
                                fontSize: 12,
                                color: AdminStyles.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _roomCodeController.text.trim().isEmpty
                                  ? '-'
                                  : _roomCodeController.text.trim(),
                              style: AdminStyles.headingStyle(
                                fontSize: 12,
                                color: AdminStyles.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Room Name',
                              style: AdminStyles.bodyStyle(
                                fontSize: 12,
                                color: AdminStyles.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _nameController.text.trim().isEmpty
                                    ? '-'
                                    : _nameController.text.trim(),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: AdminStyles.headingStyle(
                                  fontSize: 12,
                                  color: AdminStyles.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: AdminStyles.bodyStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
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
                              Navigator.pop(context);
                              _performSave();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminStyles.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Confirm Save',
                              style: AdminStyles.headingStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
        ),
      ),
    );
  }

  void _showTimedSuccessDialog() {
    if (!mounted || _isTimedSuccessVisible) return;

    _isTimedSuccessVisible = true;

    // Legacy bottom-toast success kept for reference:
    // showGeneralDialog<void>(
    //   context: context,
    //   barrierLabel: 'success-notice',
    //   barrierDismissible: true,
    //   pageBuilder: (dialogContext, _, __) => Align(...),
    // );

    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'success-notice',
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
                                  'Room Updated Successfully',
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
                            'The room information has been updated in the PSU Maintenance Management System.',
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
                                  _nameController.text.trim(),
                                  isCompact: isCompact,
                                ),
                                _successInfoRow(
                                  'Building',
                                  _selectedBuilding,
                                  isCompact: isCompact,
                                ),
                                _successInfoRow(
                                  'Floor',
                                  _selectedFloor,
                                  isCompact: isCompact,
                                ),
                                if (_selectedDepartment != _noDepartmentOption)
                                  _successInfoRow(
                                    'Department',
                                    _selectedDepartment,
                                    isCompact: isCompact,
                                  ),
                                _successStatusRow(
                                  'Status',
                                  _statusLabel(_selectedStatus),
                                  _statusColor(_selectedStatus),
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
      transitionBuilder: (context, animation, _, child) {
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
    ).then((_) {
      _isTimedSuccessVisible = false;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || !_isTimedSuccessVisible) return;
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void _performSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final buildingName = _selectedBuilding.trim();
      final departmentName = _selectedDepartment == _noDepartmentOption
          ? ''
          : _selectedDepartment.trim();

      if (departmentName.isEmpty) {
        throw Exception('Please select a department');
      }

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

      final floor = await FloorService.findOrCreateByName(_selectedFloor);
      final roomType = await RoomTypeService.fetchByName(_selectedRoomType);
      if (roomType == null) {
        throw Exception('Selected room type was not found');
      }

      final qrData = 'ROOM:${_roomCodeController.text.trim().toUpperCase()}';

      final updatedRoom = Room(
        id: widget.room.id,
        // Legacy logic kept for reference:
        // code: widget.room.code.isNotEmpty ? widget.room.code : widget.room.id,
        code: _roomCodeController.text.trim().isNotEmpty
            ? _roomCodeController.text.trim()
            : widget.room.id,
        name: _nameController.text.trim(),
        buildingId: building.id,
        building: building.name,
        floorId: floor.id,
        floor: _selectedFloor,
        seats: int.tryParse(_capacityController.text) ?? widget.room.seats,
        departmentId: department.id,
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
      if (widget.onClose != null) {
        await Future<void>.delayed(Duration.zero);
      } else {
        // Legacy flow kept for reference:
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => RoomSuccessPage(...),
        //   ),
        // );
        // await showDialog(
        //   context: context,
        //   barrierDismissible: false,
        //   builder: (dialogContext) => AdminRoomSuccesPopupWeb(...),
        // );
      }

      _showTimedSuccessDialog();
      await Future<void>.delayed(const Duration(seconds: 3));
      if (mounted) _closePage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
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
                // Legacy compact arrangement kept for reference:
                // _buildPageHeader(), _buildFormPanel(), _buildQrPanel(), _buildActionsPanel()
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Room', style: AdminStyles.pageTitleStyle()),
                    const SizedBox(height: 6),
                    Text(
                      'Update room profile and location details with the same workflow as Add Room.',
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
                  Text('Edit Room', style: AdminStyles.pageTitleStyle()),
                  const SizedBox(height: 6),
                  Text(
                    'Update room profile and location details with the same workflow as Add Room.',
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

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFECF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.meeting_room_rounded,
              color: Color(0xFF4169E1),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Room', style: AdminStyles.pageTitleStyle()),
                const SizedBox(height: 4),
                Text(
                  'Update room information, mapping, and availability details.',
                  style: AdminStyles.pageSubtitleStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _closePage,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Back'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
            ),
          ),
        ],
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
              Text(
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
                    value: _selectedDepartment,
                    items: [_noDepartmentOption, ..._departmentOptions],
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _selectedDepartment = v);
                      await _loadBuildingsByDepartment(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFieldBlock(
                  label: 'Building',
                  child: _buildDropdown(
                    value: _selectedBuilding,
                    items: _buildingOptions,
                    onChanged: _isDepartmentSelected
                        ? (v) {
                            if (v == null) return;
                            setState(() => _selectedBuilding = v);
                          }
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
                    value: _selectedFloor,
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
                    value: _selectedRoomType,
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
              Text(
                'QR Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminStyles.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 180,
              gapless: true,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_roomCodeController.text.trim()} - ${_nameController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedBuilding.isEmpty ? 'No building' : _selectedBuilding} • $_selectedFloor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          const Text(
            'QR code value is locked for existing rooms.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
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
                  onPressed: _isSaving ? null : _showSaveConfirmation,
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
                          'Save Changes',
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
              onPressed: _isSaving ? null : _showSaveConfirmation,
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
                      'Save Changes',
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
        children: [_buildLabel(label), const SizedBox(height: 7), child],
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'available':
        return 'AVAILABLE';
      case 'reserved':
        return 'RESERVED';
      case 'maintenance':
      case 'under_maintenance':
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
      case 'under_maintenance':
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

  Widget _buildStatusChips() {
    final statuses = [
      {'key': 'available', 'label': 'Available'},
      {'key': 'reserved', 'label': 'Reserved'},
      {'key': 'maintenance', 'label': 'Unavailable'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final key = s['key'] as String;
        final label = s['label'] as String;
        final isSelected = _selectedStatus == key;
        final tone = key == 'maintenance'
            ? const Color.fromRGBO(249, 26, 22, 1)
            : key == 'reserved'
            ? const Color(0xFFB45309)
            : const Color(0xFF0F766E);

        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? tone.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? tone.withValues(alpha: 0.5)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
