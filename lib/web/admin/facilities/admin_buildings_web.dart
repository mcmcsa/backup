import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/building_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/room_service.dart';
import '../shared/admin_styles.dart';
import 'facility_quick_actions_row.dart';

class AdminBuildingsWeb extends StatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final FacilityQuickActionsConfig quickActionsConfig;

  const AdminBuildingsWeb({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
    required this.quickActionsConfig,
  });

  @override
  State<AdminBuildingsWeb> createState() => _AdminBuildingsWebState();
}

class _AdminBuildingsWebState extends State<AdminBuildingsWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _buildings = [];
  List<Department> _departments = [];
  bool _isLoading = true;

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    try {
      final results = await Future.wait([
        BuildingService.fetchAll(),
        RoomService.fetchAll(),
        DepartmentService.fetchAll(),
      ]);

      final buildings = results[0] as List<Building>;
      final rooms = results[1] as List<Room>;
      final departments = results[2] as List<Department>;

      if (!mounted) return;

      final mapped = buildings.map((building) {
        final buildingRooms = rooms
            .where((room) => room.buildingId == building.id)
            .toList();
        final floorCount = buildingRooms
            .map((room) => room.floor.trim())
            .where((floor) => floor.isNotEmpty)
            .toSet()
            .length;

        final departmentNames =
            buildingRooms
                .map((room) => room.department.trim())
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

        final departmentLabel = building.department.isNotEmpty
            ? building.department
            : departmentNames.isNotEmpty
            ? departmentNames.join(', ')
            : '-';

        return {
          'buildingModel': building,
          'id': building.code.isNotEmpty ? building.code : building.id,
          'name': building.name,
          'department': departmentLabel,
          'floors': floorCount > 0 ? floorCount.toString() : '-',
          'rooms': buildingRooms.length.toString(),
          'status': 'Active',
        };
      }).toList();

      setState(() {
        _buildings = mapped;
        _departments = departments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buildings = [];
        _departments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddBuildingDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String? selectedDepartmentId;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canInputBuildingDetails = selectedDepartmentId != null;

            return AlertDialog(
              title: const Text('Add Building'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments
                            .map(
                              (department) => DropdownMenuItem<String>(
                                value: department.id,
                                child: Text(department.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedDepartmentId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        enabled: canInputBuildingDetails,
                        decoration: const InputDecoration(
                          labelText: 'Building Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        enabled: canInputBuildingDetails,
                        decoration: const InputDecoration(
                          labelText: 'Building Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (selectedDepartmentId == null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Department is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          final selectedDeptId = selectedDepartmentId!;

                          final name = nameController.text.trim();
                          final code = codeController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (code.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building code is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final now = DateTime.now();
                            final building = Building(
                              id: const Uuid().v4(),
                              name: name,
                              code: code,
                              departmentId: selectedDeptId,
                              createdAt: now,
                              updatedAt: now,
                            );
                            await BuildingService.insert(building);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadBuildings();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building added successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    codeController.dispose();
  }

  Future<void> _showEditBuildingDialog(Building building) async {
    final nameController = TextEditingController(text: building.name);
    final codeController = TextEditingController(text: building.code);
    String? selectedDepartmentId = building.departmentId.isNotEmpty
        ? building.departmentId
        : null;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canInputBuildingDetails = selectedDepartmentId != null;

            return AlertDialog(
              title: const Text('Edit Building'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments
                            .map(
                              (department) => DropdownMenuItem<String>(
                                value: department.id,
                                child: Text(department.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedDepartmentId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        enabled: canInputBuildingDetails,
                        decoration: const InputDecoration(
                          labelText: 'Building Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        enabled: canInputBuildingDetails,
                        decoration: const InputDecoration(
                          labelText: 'Building Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (selectedDepartmentId == null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Department is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          final selectedDeptId = selectedDepartmentId!;

                          final name = nameController.text.trim();
                          final code = codeController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (code.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building code is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final updated = building.copyWith(
                              name: name,
                              code: code,
                              departmentId: selectedDeptId,
                              updatedAt: DateTime.now(),
                            );
                            await BuildingService.update(updated);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadBuildings();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building updated successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    codeController.dispose();
  }

  List<Map<String, dynamic>> get _filteredBuildings {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _buildings;
    return _buildings
        .where(
          (b) =>
              b['name'].toLowerCase().contains(query) ||
              b['id'].toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buildings Management', style: AdminStyles.pageTitleStyle()),
            const SizedBox(height: 8),
            Text(
              'Manage facility buildings and information.',
              style: AdminStyles.pageSubtitleStyle(),
            ),
            const SizedBox(height: 32),
            _buildSearchAndActions(),
            const SizedBox(height: 14),
            FacilityQuickActionsRow(
              activeIndex: widget.activeIndex,
              onSelect: widget.onNavigate,
              config: widget.quickActionsConfig,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: _primaryBlue),
              )
            else
              _buildBuildingsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminStyles.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: AdminStyles.searchInputDecoration(
                    hintText: 'Search by name or ID...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddBuildingDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Building'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Container(
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminStyles.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: AdminStyles.searchInputDecoration(
                        hintText: 'Search by name or ID...',
                        prefixIcon: Icons.search_rounded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _showAddBuildingDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Building'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBuildingsTable() {
    final filtered = _filteredBuildings;
    if (filtered.isEmpty) {
      return Center(
        child: Text('No buildings found', style: TextStyle(color: _subtleText)),
      );
    }

    const codeColWidth = 120.0;
    const roomsColWidth = 100.0;
    const actionsColWidth = 120.0;
    const columnsGap = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalInset = 16.0;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: horizontalInset),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _borderColor)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: codeColWidth,
                        child: _buildTableHeader('Code'),
                      ),
                      Expanded(child: _buildTableHeader('Building Name')),
                      Expanded(child: _buildTableHeader('Department')),
                      SizedBox(
                        width: roomsColWidth,
                        child: Center(child: _buildTableHeader('Rooms')),
                      ),
                      SizedBox(width: columnsGap),
                      SizedBox(
                        width: actionsColWidth,
                        child: _buildTableHeader('Actions'),
                      ),
                    ],
                  ),
                ),
                ...filtered.asMap().entries.map((entry) {
                  final isLast = entry.key == filtered.length - 1;
                  final building = entry.value;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: codeColWidth,
                              child: Text(
                                '${building['id'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _darkText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${building['name'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _subtleText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${building['department'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _subtleText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: roomsColWidth,
                              child: Center(
                                child: Text(
                                  '${building['rooms'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _subtleText,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: columnsGap),
                            SizedBox(
                              width: actionsColWidth,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: _primaryBlue,
                                  ),
                                  onPressed: () => _showEditBuildingDialog(
                                    building['buildingModel'] as Building,
                                  ),
                                  tooltip: 'Edit',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) Divider(height: 1, color: _borderColor),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _darkText,
        letterSpacing: 0.2,
      ),
    );
  }
}
