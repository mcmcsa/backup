import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/qr_code_history_service.dart';
import 'room_success_page.dart';

class EditRoomPage extends StatefulWidget {
  final Room room;

  const EditRoomPage({super.key, required this.room});

  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  late TextEditingController _nameController;
  late TextEditingController _buildingController;
  late TextEditingController _capacityController;
  late TextEditingController _departmentController;
  late String _selectedFloor;
  late String _selectedRoomType;
  late String _selectedStatus;
  bool _isSaving = false;
  String _qrData = '';

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
    _nameController = TextEditingController(text: widget.room.name);
    _buildingController = TextEditingController(text: widget.room.building);
    _capacityController =
        TextEditingController(text: widget.room.seats.toString());
    _departmentController =
        TextEditingController(text: widget.room.department);
    _selectedFloor = widget.room.floor;
    _selectedRoomType = widget.room.roomType;
    _selectedStatus = widget.room.status;
    _qrData = 'PSU-ROOM-${widget.room.name}-${widget.room.building}-${widget.room.id.substring(0, 8)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buildingController.dispose();
    _capacityController.dispose();
    _departmentController.dispose();
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
      final buildingName = _buildingController.text.trim();
      final departmentName = _departmentController.text.trim();

      // Find or create building/department in database
      final building = await BuildingService.findOrCreateByName(buildingName);
      String departmentId = '';
      if (departmentName.isNotEmpty) {
        final dept = await DepartmentService.findOrCreateByName(departmentName);
        departmentId = dept.id;
      }

      final updatedRoom = Room(
        id: widget.room.id,
        name: _nameController.text.trim(),
        buildingId: building.id,
        building: building.name,
        floor: _selectedFloor,
        seats: int.tryParse(_capacityController.text) ?? widget.room.seats,
        departmentId: departmentId,
        department: departmentName,
        roomType: _selectedRoomType,
        status: _selectedStatus,
        imageUrl: widget.room.imageUrl,
        description: widget.room.description,
        qrCodeData: widget.room.qrCodeData,
      );

      await RoomService.update(updatedRoom);

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

  void _regenerateQRCode() async {
    final buildingName = _buildingController.text.trim();
    final newQrData = 'PSU-ROOM-${_nameController.text}-$buildingName-${const Uuid().v4().substring(0, 8)}';
    try {
      await QRCodeHistoryService.saveQRCode(
        roomId: widget.room.id,
        qrCodeValue: newQrData,
        qrCodeImage: null,
      );
      setState(() => _qrData = newQrData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code regenerated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error regenerating QR: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            // Room Name
            _buildLabel('Room Name'),
            const SizedBox(height: 8),
            _buildTextField(_nameController),
            const SizedBox(height: 18),

            // Building
            _buildLabel('Building'),
            const SizedBox(height: 8),
            _buildTextField(_buildingController),
            const SizedBox(height: 18),

            // Floor & Capacity Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Floor'),
                      const SizedBox(height: 8),
                      _buildDropdown(
                        value: _selectedFloor,
                        items: _floors,
                        onChanged: (v) =>
                            setState(() => _selectedFloor = v ?? _selectedFloor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Capacity'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _capacityController,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Department
            _buildLabel('Department'),
            const SizedBox(height: 8),
            _buildTextField(_departmentController),
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
            const SizedBox(height: 24),

            // Divider
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 16),

            // QR Code Preview
            Center(
              child: Column(
                children: [
                  // QR Code placeholder
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 104,
                      gapless: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_nameController.text} - ${_buildingController.text.toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '$_selectedFloor • $_selectedRoomType',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _regenerateQRCode,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh,
                            size: 14, color: const Color(0xFF4169E1)),
                        const SizedBox(width: 4),
                        const Text(
                          'Regenerate QR Code',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4169E1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

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
                      onPressed: _showSaveConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4169E1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
      {'key': 'available', 'label': 'Available', 'icon': Icons.check_circle},
      {'key': 'reserved', 'label': 'Reserved', 'icon': Icons.bookmark},
      {'key': 'maintenance', 'label': 'Under Maintenance', 'icon': Icons.build},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((s) {
        final key = s['key'] as String;
        final label = s['label'] as String;
        final icon = s['icon'] as IconData;
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}



