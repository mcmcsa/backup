import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/building_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/models/room_model.dart';
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
      List<Department> departments = [];
      List<Room> rooms = [];
      List<Building> buildings = [];

      try {
        departments = await DepartmentService.fetchAll();
      } catch (e) {
        debugPrint('[AdminDepartmentsWeb] Error loading departments: $e');
      }

      try {
        rooms = await RoomService.fetchAll();
      } catch (e) {
        debugPrint('[AdminDepartmentsWeb] Error loading rooms: $e');
      }

      try {
        buildings = await BuildingService.fetchAll();
      } catch (e) {
        debugPrint('[AdminDepartmentsWeb] Error loading buildings: $e');
      }

      final bldgMap = {for (var b in buildings) b.id: b.name};

      if (!mounted) return;

      final mapped = departments.map((department) {
        final deptRooms = rooms
            .where((r) => r.departmentId == department.id || r.department.toLowerCase() == department.name.toLowerCase())
            .toList();
        final List<String> resolvedBuildingNames = [];
        if (department.buildingNames.isNotEmpty) {
          resolvedBuildingNames.addAll(department.buildingNames);
        } else if (department.buildingIds.isNotEmpty) {
          for (final bId in department.buildingIds) {
            if (bldgMap.containsKey(bId)) {
              resolvedBuildingNames.add(bldgMap[bId]!);
            }
          }
        }
        if (resolvedBuildingNames.isEmpty && deptRooms.isNotEmpty) {
          final roomBldgs = deptRooms
              .map((r) => r.building.trim())
              .where((b) => b.isNotEmpty)
              .toSet();
          resolvedBuildingNames.addAll(roomBldgs);
        }

        final buildingsDisplay = resolvedBuildingNames.isNotEmpty
            ? resolvedBuildingNames.join(', ')
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
          'building': buildingsDisplay,
          'buildings': resolvedBuildingNames,
          'hasBuilding': buildingsDisplay != 'None Assigned',
          'status': 'Active',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _departments = mapped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[AdminDepartmentsWeb] Unexpected load error: $e');
      if (!mounted) return;
      setState(() {
        if (!silent) _departments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddDepartmentDialog() async {
    String departmentName = '';
    final Set<String> selectedBuildingIds = {};
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
            return AlertDialog(
              title: const Text('Add Department'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        autofocus: true,
                        initialValue: departmentName,
                        onChanged: (value) => departmentName = value,
                        decoration: const InputDecoration(
                          labelText: 'Department Name *',
                          hintText: 'e.g., Information Technology',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Associated Buildings',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminStyles.textPrimary,
                            ),
                          ),
                          if (selectedBuildingIds.isNotEmpty)
                            Text(
                              '${selectedBuildingIds.length} selected',
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
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AdminStyles.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: buildings.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No buildings available.'),
                              )
                            : Scrollbar(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: buildings.length,
                                  itemBuilder: (context, index) {
                                    final b = buildings[index];
                                    final isChecked = selectedBuildingIds.contains(b.id);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                      title: Text(
                                        b.name,
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
                                            selectedBuildingIds.add(b.id);
                                          } else {
                                            selectedBuildingIds.remove(b.id);
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
                        'Select one or more buildings this department belongs to.',
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
                              buildingIds: selectedBuildingIds.toList(),
                              createdAt: now,
                              updatedAt: now,
                            );
                            await DepartmentService.insert(
                              department,
                              buildingIds: selectedBuildingIds.toList(),
                            );
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
    final Set<String> selectedBuildingIds = department.buildingIds.toSet();
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Associated Buildings',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminStyles.textPrimary,
                            ),
                          ),
                          if (selectedBuildingIds.isNotEmpty)
                            Text(
                              '${selectedBuildingIds.length} selected',
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
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AdminStyles.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: buildings.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No buildings available.'),
                              )
                            : Scrollbar(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: buildings.length,
                                  itemBuilder: (context, index) {
                                    final b = buildings[index];
                                    final isChecked = selectedBuildingIds.contains(b.id);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                      title: Text(
                                        b.name,
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
                                            selectedBuildingIds.add(b.id);
                                          } else {
                                            selectedBuildingIds.remove(b.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
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
                            await DepartmentService.updateDepartment(
                              id: department.id,
                              name: name,
                              buildingIds: selectedBuildingIds.toList(),
                              isActive: department.isActive,
                              allDepartments: _departments
                                  .map((d) => d['departmentModel'] as Department)
                                  .toList(),
                            );

                            // If Department Head selection changed
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

  void _showDepartmentDetailsDialog(Department department, List<String> buildings) {
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
                            Icons.domain_rounded,
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
                                department.name,
                                style: AdminStyles.headingStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Department Details & Facility Allocations',
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
                        // Department Head Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminStyles.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminStyles.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AdminStyles.border),
                                ),
                                child: Icon(
                                  (department.headUserName != null && department.headUserName!.isNotEmpty)
                                      ? Icons.verified_user_rounded
                                      : Icons.person_off_outlined,
                                  color: (department.headUserName != null && department.headUserName!.isNotEmpty)
                                      ? AdminStyles.primary
                                      : AdminStyles.textMuted,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DEPARTMENT HEAD',
                                      style: AdminStyles.bodyStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AdminStyles.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (department.headUserName != null && department.headUserName!.isNotEmpty)
                                          ? department.headUserName!
                                          : 'None Assigned',
                                      style: AdminStyles.headingStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AdminStyles.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Assigned Buildings Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ASSIGNED BUILDINGS',
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
                                '${buildings.length}',
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
                        if (buildings.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AdminStyles.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.apartment_outlined, size: 18, color: AdminStyles.textMuted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No buildings are currently assigned to this department.',
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
                                children: buildings.map((bName) {
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
                                            Icons.apartment_rounded,
                                            size: 16,
                                            color: AdminStyles.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            bName,
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
                            _showEditDepartmentDialog(department);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Department'),
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

  Widget _buildBuildingsCell(Map<String, dynamic> dept) {
    final buildingsList = (dept['buildings'] as List<dynamic>?)?.cast<String>() ?? [];
    final department = dept['departmentModel'] as Department;

    if (buildingsList.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.apartment_outlined,
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

    final countLabel = buildingsList.length == 1
        ? '1 Building'
        : '${buildingsList.length} Buildings';

    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: buildingsList.join(', '),
        child: InkWell(
          onTap: () => _showDepartmentDetailsDialog(department, buildingsList),
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
                  Icons.apartment_rounded,
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
                                child: _buildTableHeader('Buildings', alignment: Alignment.centerLeft),
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
                                      child: _buildBuildingsCell(dept),
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
