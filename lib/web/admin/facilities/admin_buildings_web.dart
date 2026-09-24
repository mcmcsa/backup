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
  bool _isLoading = true;

  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;
  static const Color _cardBg = AdminStyles.surface;
  static const Color _borderColor = AdminStyles.border;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void didUpdateWidget(covariant AdminBuildingsWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex == widget.quickActionsConfig.buildingsIndex &&
        oldWidget.activeIndex != widget.quickActionsConfig.buildingsIndex) {
      _loadBuildings(silent: true);
    }
  }

  Future<void> _loadBuildings({bool silent = false}) async {
    if (!silent && _buildings.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      List<Building> buildings = [];
      List<Room> rooms = [];
      List<Department> departments = [];

      try {
        buildings = await BuildingService.fetchAll();
      } catch (e) {
        debugPrint('[AdminBuildingsWeb] Error loading buildings: $e');
      }

      try {
        rooms = await RoomService.fetchAll();
      } catch (e) {
        debugPrint('[AdminBuildingsWeb] Error loading rooms: $e');
      }

      try {
        departments = await DepartmentService.fetchAll();
      } catch (e) {
        debugPrint('[AdminBuildingsWeb] Error loading departments: $e');
      }

      final deptMap = {for (var d in departments) d.id: d.name};

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

        final List<String> resolvedDeptNames = [];
        if (building.departmentNames.isNotEmpty) {
          resolvedDeptNames.addAll(building.departmentNames);
        } else if (building.departmentIds.isNotEmpty) {
          for (final dId in building.departmentIds) {
            if (deptMap.containsKey(dId)) {
              resolvedDeptNames.add(deptMap[dId]!);
            }
          }
        }
        if (resolvedDeptNames.isEmpty && buildingRooms.isNotEmpty) {
          final roomDepts = buildingRooms
              .map((r) => r.department.trim())
              .where((d) => d.isNotEmpty)
              .toSet();
          resolvedDeptNames.addAll(roomDepts);
        }

        final departmentsDisplay = resolvedDeptNames.isNotEmpty
            ? resolvedDeptNames.join(', ')
            : 'None Assigned';

        return {
          'buildingModel': building,
          'id': building.code.isNotEmpty ? building.code : building.id,
          'name': building.name,
          'floors': floorCount > 0 ? floorCount.toString() : '-',
          'rooms': buildingRooms.length.toString(),
          'departments': departmentsDisplay,
          'departmentsList': resolvedDeptNames,
          'hasDepartment': resolvedDeptNames.isNotEmpty,
          'status': 'Active',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _buildings = mapped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[AdminBuildingsWeb] Unexpected load error: $e');
      if (!mounted) return;
      setState(() {
        if (!silent) _buildings = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddBuildingDialog() async {
    final nameController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Building'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Building Name',
                          hintText: 'ex. New Building',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building name is required'),
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
                              departmentIds: const [],
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
  }

  Future<void> _showEditBuildingDialog(Building building) async {
    final nameController = TextEditingController(text: building.name);
    final Set<String> selectedDeptIds = building.departmentIds.toSet();
    bool isSubmitting = false;

    List<Department> departments = [];
    try {
      departments = await DepartmentService.fetchAll();
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Building'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Building Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Associated Departments',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminStyles.textPrimary,
                            ),
                          ),
                          if (selectedDeptIds.isNotEmpty)
                            Text(
                              '${selectedDeptIds.length} selected',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AdminStyles.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AdminStyles.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: departments.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No departments available.'),
                              )
                            : Scrollbar(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: departments.length,
                                  itemBuilder: (context, index) {
                                    final d = departments[index];
                                    final isChecked = selectedDeptIds.contains(d.id);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                      title: Text(
                                        d.name,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: AdminStyles.textPrimary,
                                        ),
                                      ),
                                      value: isChecked,
                                      activeColor: AdminStyles.primary,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedDeptIds.add(d.id);
                                          } else {
                                            selectedDeptIds.remove(d.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select departments that have rooms or facilities in this building.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Building name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final err = await BuildingService.updateBuilding(
                              id: building.id,
                              name: name,
                              departmentIds: selectedDeptIds.toList(),
                              isActive: building.isActive,
                              allBuildings: _buildings
                                  .map((b) => b['buildingModel'] as Building)
                                  .toList(),
                            );
                            if (err != null) throw Exception(err);
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
  }

  void _showBuildingDetailsDialog(Building building, List<String> departments, int roomCount) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminStyles.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AdminStyles.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.business_rounded,
                            color: AdminStyles.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                building.name,
                                style: AdminStyles.headingStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Building Details & Department Allocations',
                                style: AdminStyles.bodyStyle(
                                  fontSize: 12,
                                  color: AdminStyles.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AdminStyles.textSecondary),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AdminStyles.border),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Stats Row
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminStyles.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminStyles.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AdminStyles.border),
                                      ),
                                      child: const Icon(Icons.meeting_room_outlined, size: 18, color: AdminStyles.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL ROOMS',
                                          style: AdminStyles.bodyStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AdminStyles.textMuted,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '$roomCount',
                                          style: AdminStyles.headingStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AdminStyles.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: AdminStyles.border,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AdminStyles.border),
                                      ),
                                      child: const Icon(Icons.domain_rounded, size: 18, color: AdminStyles.primary),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DEPARTMENTS',
                                          style: AdminStyles.bodyStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AdminStyles.textMuted,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${departments.length}',
                                          style: AdminStyles.headingStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AdminStyles.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Assigned Departments Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ASSIGNED DEPARTMENTS',
                              style: AdminStyles.bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AdminStyles.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AdminStyles.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${departments.length}',
                                style: AdminStyles.bodyStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminStyles.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (departments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AdminStyles.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: AdminStyles.textMuted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No departments are currently assigned to this building.',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 13,
                                      color: AdminStyles.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: SingleChildScrollView(
                              child: Column(
                                children: departments.map((dName) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AdminStyles.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AdminStyles.border),
                                          ),
                                          child: const Icon(
                                            Icons.school_rounded,
                                            size: 16,
                                            color: AdminStyles.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            dName,
                                            style: AdminStyles.bodyStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AdminStyles.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AdminStyles.border),
                  // Footer Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminStyles.textSecondary,
                            side: const BorderSide(color: AdminStyles.border),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _showEditBuildingDialog(building);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Building'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminStyles.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentsCell(Map<String, dynamic> building) {
    final deptsList = (building['departmentsList'] as List<dynamic>?)?.cast<String>() ?? [];
    final bldgModel = building['buildingModel'] as Building;
    final roomCount = int.tryParse(building['rooms']?.toString() ?? '0') ?? 0;

    if (deptsList.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.business_outlined,
            size: 15,
            color: AdminStyles.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            'None Assigned',
            style: AdminStyles.bodyStyle(
              fontSize: 13,
              color: AdminStyles.textMuted,
            ),
          ),
        ],
      );
    }

    final countLabel = deptsList.length == 1
        ? '1 Department'
        : '${deptsList.length} Departments';

    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: deptsList.join(', '),
        child: InkWell(
          onTap: () => _showBuildingDetailsDialog(bldgModel, deptsList, roomCount),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AdminStyles.primary.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AdminStyles.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.domain_rounded,
                  size: 14,
                  color: AdminStyles.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  countLabel,
                  style: AdminStyles.bodyStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminStyles.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: AdminStyles.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredBuildings {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _buildings;
    return _buildings
        .where(
          (b) =>
              (b['name']?.toString().toLowerCase().contains(query) ?? false) ||
              (b['id']?.toString().toLowerCase().contains(query) ?? false),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return Container(
          color: _pageBg,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: isMobile ? 20 : 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buildings', style: AdminStyles.pageTitleStyle()),
                const SizedBox(height: 24),
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
      },
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
        child: Text('No buildings found', style: AdminStyles.bodyStyle(color: _subtleText)),
      );
    }

    const roomsColWidth = 100.0;
    const actionsColWidth = 120.0;
    const columnsGap = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalInset = 16.0;
        final minWidth = constraints.maxWidth > 850.0 ? constraints.maxWidth : 850.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minWidth,
            child: Container(
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
                          Expanded(
                            flex: 3,
                            child: _buildTableHeader('BUILDING NAME', alignment: Alignment.centerLeft),
                          ),
                          Expanded(
                            flex: 4,
                            child: _buildTableHeader('DEPARTMENTS', alignment: Alignment.centerLeft),
                          ),
                          SizedBox(
                            width: roomsColWidth,
                            child: _buildTableHeader('ROOMS', alignment: Alignment.center),
                          ),
                          SizedBox(width: columnsGap),
                          SizedBox(
                            width: actionsColWidth,
                            child: _buildTableHeader('ACTIONS', alignment: Alignment.center),
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
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '${building['name'] ?? '-'}',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _darkText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: _buildDepartmentsCell(building),
                                ),
                                SizedBox(
                                  width: roomsColWidth,
                                  child: Center(
                                    child: Text(
                                      '${building['rooms'] ?? '-'}',
                                      style: AdminStyles.bodyStyle(
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
                                    alignment: Alignment.center,
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
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(String title, {Alignment alignment = Alignment.centerLeft}) {
    return Align(
      alignment: alignment,
      child: Text(
        title.toUpperCase(),
        textAlign: alignment == Alignment.center ? TextAlign.center : TextAlign.left,
        style: AdminStyles.bodyStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
