import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/department_model.dart';
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

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await DepartmentService.fetchAll();
      final rooms = await RoomService.fetchAll();

      if (!mounted) return;

      final mapped = departments.map((department) {
        final deptRooms = rooms
            .where((room) => room.departmentId == department.id)
            .toList();
        final primaryBuilding = deptRooms.isNotEmpty
            ? deptRooms.first.building
            : '-';

        return {
          'departmentModel': department,
          'id': department.id,
          'name': department.name,
          'head': '-',
          'building': primaryBuilding,
          'status': 'Active',
        };
      }).toList();

      setState(() {
        _departments = mapped;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _departments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddDepartmentDialog() async {
    String departmentName = '';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Department'),
              content: SizedBox(
                width: 400,
                child: TextFormField(
                  autofocus: true,
                  initialValue: departmentName,
                  onChanged: (value) => departmentName = value,
                  decoration: const InputDecoration(
                    labelText: 'Department Name',
                    border: OutlineInputBorder(),
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
                            final now = DateTime.now();
                            final department = Department(
                              id: const Uuid().v4(),
                              name: name,
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
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Department'),
              content: SizedBox(
                width: 400,
                child: TextFormField(
                  autofocus: true,
                  initialValue: departmentName,
                  onChanged: (value) => departmentName = value,
                  decoration: const InputDecoration(
                    labelText: 'Department Name',
                    border: OutlineInputBorder(),
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
                            final updated = department.copyWith(
                              name: name,
                              updatedAt: DateTime.now(),
                            );
                            await DepartmentService.update(updated);
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
            Text('Departments Management', style: AdminStyles.pageTitleStyle()),
            const SizedBox(height: 8),
            Text(
              'Manage academic and administrative departments.',
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
          style: TextStyle(color: _subtleText),
        ),
      );
    }

    const nameColWidth = 460.0;
    const actionsColWidth = 120.0;
    const tableMinWidth = nameColWidth + actionsColWidth;

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
                                child: _buildTableHeader('Department Name'),
                              ),
                              SizedBox(
                                width: actionsColWidth,
                                child: _buildTableHeader('Actions'),
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
                                      child: Text(
                                        '${dept['name'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _darkText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
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
                                          onPressed: () =>
                                              _showEditDepartmentDialog(
                                                dept['departmentModel']
                                                    as Department,
                                              ),
                                          tooltip: 'Edit',
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
