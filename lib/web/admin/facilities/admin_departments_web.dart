import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/building_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/room_service.dart';
import '../shared/admin_styles.dart';
import 'facility_quick_actions_row.dart';

class AdminDepartmentsWeb extends StatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final FacilityQuickActionsConfig quickActionsConfig;

  const AdminDepartmentsWeb({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
    required this.quickActionsConfig,
  });

  @override
  State<AdminDepartmentsWeb> createState() => _AdminDepartmentsWebState();
}

class _AdminDepartmentsWebState extends State<AdminDepartmentsWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _departments = [];
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
    _loadDepartments();
  }

  @override
  void didUpdateWidget(covariant AdminDepartmentsWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex == widget.quickActionsConfig.departmentsIndex &&
        oldWidget.activeIndex != widget.quickActionsConfig.departmentsIndex) {
      _loadDepartments(silent: true);
    }
  }

  Future<void> _loadDepartments({bool silent = false}) async {
    if (!silent && _departments.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final departments = await DepartmentService.fetchAll();
      final rooms = await RoomService.fetchAll();
      final buildings = await BuildingService.fetchAll();
      final bldgMap = {for (var b in buildings) b.id: b.name};

      if (!mounted) return;

      final mapped = departments.map((department) {
        final deptRooms = rooms
            .where((room) => room.departmentId == department.id)
            .toList();

        final buildingName = (department.buildingName != null && department.buildingName!.isNotEmpty)
            ? department.buildingName!
            : (department.buildingId != null && bldgMap.containsKey(department.buildingId))
            ? bldgMap[department.buildingId]!
            : deptRooms.isNotEmpty
            ? deptRooms.first.building
            : 'None Assigned';

        final headName = (department.headUserName != null && department.headUserName!.trim().isNotEmpty)
            ? department.headUserName!.trim()
            : 'None Assigned';

        return {
          'departmentModel': department,
          'id': department.id,
          'name': department.name,
          'head': headName,
          'hasHead': headName != 'None Assigned',
          'building': buildingName,
          'hasBuilding': buildingName != 'None Assigned',
          'status': 'Active',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _departments = mapped;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!silent) _departments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddDepartmentDialog() async {
    String departmentName = '';
    String? selectedBuildingId;
    bool isSubmitting = false;

    // Load available buildings
    List<Building> buildings = [];
    try {
      buildings = await BuildingService.fetchAll();
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canInputDepartment = selectedBuildingId != null && selectedBuildingId!.isNotEmpty;

            return AlertDialog(
              title: const Text('Add Department'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedBuildingId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Building *',
                        border: OutlineInputBorder(),
                        helperText: 'Select the building this department belongs to',
                      ),
                      items: buildings
                          .map(
                            (b) => DropdownMenuItem<String>(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedBuildingId = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      enabled: canInputDepartment,
                      initialValue: departmentName,
                      onChanged: (value) => departmentName = value,
                      decoration: InputDecoration(
                        labelText: 'Department Name *',
                        hintText: canInputDepartment
                            ? 'e.g., Information Technology'
                            : 'Select a building first',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
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
                          if (selectedBuildingId == null || selectedBuildingId!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a building first.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final name = departmentName.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Department name is required.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final now = DateTime.now();
                            final department = Department(
                              id: const Uuid().v4(),
                              name: name,
                              buildingId: selectedBuildingId,
                              createdAt: now,
                              updatedAt: now,
                            );
                            await DepartmentService.insert(department);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadDepartments();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Department added successfully.'),
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
  }

  Future<void> _showEditDepartmentDialog(Department department) async {
    String departmentName = department.name;
    String? selectedHeadId = department.headUserId;
    String? selectedBuildingId = department.buildingId;
    bool isSubmitting = false;

    // Load available buildings
    List<Building> buildings = [];
    try {
      buildings = await BuildingService.fetchAll();
    } catch (_) {}

    // Load active faculty for this department
    List<Map<String, String>> eligibleTeachers = [];
    try {
      final res = await Supabase.instance.client
          .from('teacher_users')
          .select('user_id, position, users!teacher_users_user_id_fkey(id, name, is_active)')
          .eq('department_id', department.id);
      for (final t in (res as List)) {
        final u = t['users'];
        if (u is Map && u['is_active'] == true) {
          eligibleTeachers.add({
            'id': u['id'].toString(),
            'name': u['name']?.toString() ?? 'Unnamed',
            'position': t['position']?.toString() ?? '',
          });
        }
      }
    } catch (_) {}

    // Verify selectedHeadId is in list, else add current if present
    if (selectedHeadId != null && !eligibleTeachers.any((t) => t['id'] == selectedHeadId)) {
      if (department.headUserName != null && department.headUserName!.isNotEmpty) {
        eligibleTeachers.insert(0, {
          'id': selectedHeadId,
          'name': department.headUserName!,
          'position': 'Head',
        });
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Department'),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: selectedBuildingId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Building',
                        border: OutlineInputBorder(),
                        helperText: 'Select the building this department belongs to',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None Assigned (Unassigned)'),
                        ),
                        ...buildings.map(
                          (b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedBuildingId = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      autofocus: true,
                      initialValue: departmentName,
                      onChanged: (value) => departmentName = value,
                      decoration: const InputDecoration(
                        labelText: 'Department Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedHeadId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Official Department Head',
                        border: OutlineInputBorder(),
                        helperText: 'Select from active faculty in this department',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None Assigned (Unassigned)'),
                        ),
                        ...eligibleTeachers.map(
                          (t) => DropdownMenuItem<String?>(
                            value: t['id'],
                            child: Text('${t['name']}${t['position']!.isNotEmpty ? ' (${t['position']})' : ''}'),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedHeadId = val);
                      },
                    ),
                  ],
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
                          final name = departmentName.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Department name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            if (name != department.name || selectedBuildingId != department.buildingId) {
                              final updated = department.copyWith(
                                name: name,
                                buildingId: selectedBuildingId,
                                updatedAt: DateTime.now(),
                              );
                              await DepartmentService.update(updated);
                            }

                            // Rule 4: If Department Head selection changed
                            if (selectedHeadId != department.headUserId) {
                              await DepartmentService.setDepartmentHead(
                                department.id,
                                selectedHeadId,
                              );
                            }

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadDepartments();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Department updated successfully.',
                                ),
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
  }

  List<Map<String, dynamic>> get _filteredDepartments {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _departments;
    return _departments
        .where(
          (d) =>
              d['name'].toLowerCase().contains(query) ||
              d['id'].toLowerCase().contains(query),
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
            Text('Departments', style: AdminStyles.pageTitleStyle()),
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
              _buildDepartmentsTable(),
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
                    hintText: 'Search by name or code...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddDepartmentDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Department'),
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
                        hintText: 'Search by name or code...',
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
                onPressed: _showAddDepartmentDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Department'),
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

  Widget _buildDepartmentsTable() {
    final filtered = _filteredDepartments;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No departments found',
          style: AdminStyles.bodyStyle(color: _subtleText),
        ),
      );
    }

    const nameColWidth = 260.0;
    const buildingColWidth = 240.0;
    const headColWidth = 260.0;
    const actionsColWidth = 100.0;
    const tableMinWidth = nameColWidth + buildingColWidth + headColWidth + actionsColWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth > tableMinWidth
            ? constraints.maxWidth
            : tableMinWidth;
        const horizontalInset = 16.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minWidth,
            child: Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: horizontalInset,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _borderColor),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildTableHeader('Department Name', alignment: Alignment.centerLeft),
                              ),
                              Expanded(
                                flex: 3,
                                child: _buildTableHeader('Building', alignment: Alignment.centerLeft),
                              ),
                              Expanded(
                                flex: 3,
                                child: _buildTableHeader('Department Head', alignment: Alignment.centerLeft),
                              ),
                              SizedBox(
                                width: actionsColWidth,
                                child: _buildTableHeader('Actions', alignment: Alignment.center),
                              ),
                            ],
                          ),
                        ),
                        ...filtered.asMap().entries.map((entry) {
                          final isLast = entry.key == filtered.length - 1;
                          final dept = entry.value;
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
                                        '${dept['name'] ?? '-'}',
                                        style: AdminStyles.headingStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _darkText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.apartment_outlined,
                                            size: 15,
                                            color: dept['hasBuilding'] == true ? AdminStyles.primary : AdminStyles.textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${dept['building'] ?? 'None Assigned'}',
                                              style: AdminStyles.bodyStyle(
                                                fontSize: 13,
                                                fontWeight: dept['hasBuilding'] == true ? FontWeight.w500 : FontWeight.normal,
                                                color: dept['hasBuilding'] == true ? _darkText : AdminStyles.textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Icon(
                                            dept['hasHead'] == true ? Icons.verified_user_rounded : Icons.person_off_outlined,
                                            size: 15,
                                            color: dept['hasHead'] == true ? AdminStyles.primary : AdminStyles.textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${dept['head'] ?? 'None Assigned'}',
                                              style: AdminStyles.bodyStyle(
                                                fontSize: 13,
                                                fontWeight: dept['hasHead'] == true ? FontWeight.w600 : FontWeight.normal,
                                                color: dept['hasHead'] == true ? _darkText : AdminStyles.textMuted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                          onPressed: () =>
                                              _showEditDepartmentDialog(
                                                dept['departmentModel']
                                                    as Department,
                                              ),
                                          tooltip: 'Edit Department & Head',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(height: 1, color: _borderColor),
                            ],
                          );
                        }),
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
