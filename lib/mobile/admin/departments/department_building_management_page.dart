import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/building_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/models/floor_model.dart';
import '../../../shared/models/request_type_model.dart';
import '../../../shared/models/room_type_model.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/floor_service.dart';
import '../../../shared/services/request_type_service.dart';
import '../../../shared/services/room_type_service.dart';

enum _ManagementView { departments, buildings, roomTypes, floors, requestTypes }

class DepartmentBuildingManagementPage extends StatefulWidget {
  final VoidCallback openDrawer;

  const DepartmentBuildingManagementPage({super.key, required this.openDrawer});

  @override
  State<DepartmentBuildingManagementPage> createState() =>
      _DepartmentBuildingManagementPageState();
}

class _DepartmentBuildingManagementPageState
    extends State<DepartmentBuildingManagementPage> {
  final TextEditingController _searchController = TextEditingController();

  _ManagementView _activeView = _ManagementView.departments;
  List<Department> _departments = [];
  List<Building> _buildings = [];
  List<RoomType> _roomTypes = [];
  List<Floor> _floors = [];
  List<RequestType> _requestTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final departments = await DepartmentService.fetchAll();
      final buildings = await BuildingService.fetchAll();
      final roomTypes = await RoomTypeService.fetchAll();
      final floors = await FloorService.fetchAll();
      final requestTypes = await RequestTypeService.fetchAll();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _buildings = buildings;
        _roomTypes = roomTypes;
        _floors = floors;
        _requestTypes = requestTypes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Department> get _filteredDepartments {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _departments;
    return _departments
        .where((d) => d.name.toLowerCase().contains(query))
        .toList();
  }

  List<Building> get _filteredBuildings {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _buildings;
    return _buildings
        .where((b) => b.name.toLowerCase().contains(query))
        .toList();
  }

  List<RoomType> get _filteredRoomTypes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _roomTypes;
    return _roomTypes
        .where(
          (t) =>
              t.name.toLowerCase().contains(query) ||
              t.code.toLowerCase().contains(query),
        )
        .toList();
  }

  List<Floor> get _filteredFloors {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _floors;
    return _floors.where((f) => f.name.toLowerCase().contains(query)).toList();
  }

  List<RequestType> get _filteredRequestTypes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _requestTypes;
    return _requestTypes
        .where((r) => r.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDepartmentDialog() async {
    final nameController = TextEditingController();
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
                child: TextField(
                  controller: nameController,
                  autofocus: true,
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
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
                            final dept = Department(
                              id: const Uuid().v4(),
                              name: name,
                              createdAt: now,
                              updatedAt: now,
                            );
                            await DepartmentService.insert(dept);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Department added successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  void _showEditDepartmentDialog(Department department) async {
    final nameController = TextEditingController(text: department.name);
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
                child: TextField(
                  controller: nameController,
                  autofocus: true,
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Department name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);

                          try {
                            final updated = Department(
                              id: department.id,
                              name: name,
                              createdAt: department.createdAt,
                              updatedAt: DateTime.now(),
                            );
                            await DepartmentService.update(updated);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  Future<void> _deleteDepartment(Department department) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text(
          'Delete ${department.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DepartmentService.delete(department.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddBuildingDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    Department? selectedDepartment;
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
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Department>(
                        initialValue: selectedDepartment,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Department First',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments
                            .map(
                              (d) => DropdownMenuItem<Department>(
                                value: d,
                                child: Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) {
                          return _departments
                              .map(
                                (d) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    d.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList();
                        },
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setDialogState(
                                  () => selectedDepartment = value,
                                );
                              },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: codeController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Building Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Building Name',
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
                          if (selectedDepartment == null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Select a department first.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final code = codeController.text.trim();
                          final name = nameController.text.trim();
                          if (code.isEmpty || name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Building code and name are required',
                                ),
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
                              departmentId: selectedDepartment!.id,
                              createdAt: now,
                              updatedAt: now,
                            );
                            await BuildingService.insert(building);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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
    codeController.dispose();
    nameController.dispose();
  }

  void _showEditBuildingDialog(Building building) async {
    final codeController = TextEditingController(text: building.code);
    final nameController = TextEditingController(text: building.name);
    Department? selectedDepartment = _departments.firstWhere(
      (department) => department.id == building.departmentId,
      orElse: () => _departments.isNotEmpty
          ? _departments.first
          : Department(
              id: '',
              name: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Building'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Department>(
                        initialValue: selectedDepartment?.id.isEmpty == true
                            ? null
                            : selectedDepartment,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Department',
                          border: OutlineInputBorder(),
                        ),
                        items: _departments
                            .map(
                              (department) => DropdownMenuItem<Department>(
                                value: department,
                                child: Text(department.name),
                              ),
                            )
                            .toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setDialogState(
                                  () => selectedDepartment = value,
                                );
                              },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: codeController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Building Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Building Name',
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
                          if (selectedDepartment == null ||
                              selectedDepartment!.id.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Select a department first'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final code = codeController.text.trim();
                          final name = nameController.text.trim();
                          if (code.isEmpty || name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Building code and name are required',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSubmitting = true);

                          try {
                            final updated = Building(
                              id: building.id,
                              name: name,
                              code: code,
                              departmentId: selectedDepartment!.id,
                              createdAt: building.createdAt,
                              updatedAt: DateTime.now(),
                            );
                            await BuildingService.update(updated);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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
    codeController.dispose();
    nameController.dispose();
  }

  Future<void> _deleteBuilding(Building building) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Building'),
        content: Text('Delete ${building.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BuildingService.delete(building.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddRoomTypeDialog() async {
    final nameController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Room Type'),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Room Type',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Room Type is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final exists = _roomTypes.any(
                            (t) => t.name.toLowerCase() == name.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Room Type already exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final now = DateTime.now();

                            final roomType = RoomType(
                              id: const Uuid().v4(),
                              name: name,
                              createdAt: now,
                              updatedAt: now,
                            );

                            await RoomTypeService.insert(roomType);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  void _showEditRoomTypeDialog(RoomType roomType) async {
    final nameController = TextEditingController(text: roomType.name);
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Room Type'),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Room Type',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Room Type is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final exists = _roomTypes.any(
                            (t) =>
                                t.id != roomType.id &&
                                t.name.toLowerCase() == name.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Room Type already exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final updated = roomType.copyWith(
                              name: name,
                              updatedAt: DateTime.now(),
                            );
                            await RoomTypeService.update(updated);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  Future<void> _deleteRoomType(RoomType roomType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Room Type'),
        content: Text('Delete ${roomType.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await RoomTypeService.delete(roomType.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddFloorDialog() async {
    final nameController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Floor'),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Floor',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final exists = _floors.any(
                            (f) => f.name.toLowerCase() == name.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor already exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await FloorService.findOrCreateByName(name);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  void _showEditFloorDialog(Floor floor) async {
    final nameController = TextEditingController(text: floor.name);
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Floor'),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Floor',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final exists = _floors.any(
                            (f) =>
                                f.id != floor.id &&
                                f.name.toLowerCase() == name.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor already exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final updated = floor.copyWith(
                              name: name,
                              updatedAt: DateTime.now(),
                            );
                            await FloorService.update(updated);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  Future<void> _deleteFloor(Floor floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Floor'),
        content: Text('Delete ${floor.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FloorService.delete(floor.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddRequestTypeDialog() async {
    final nameController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Request Type'),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Request Type',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Request Type is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final exists = _requestTypes.any(
                            (r) => r.name.toLowerCase() == name.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Request Type already exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final now = DateTime.now();
                            final requestType = RequestType(
                              id: const Uuid().v4(),
                              name: name,
                              createdAt: now,
                              updatedAt: now,
                            );
                            await RequestTypeService.insert(requestType);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  void _showEditRequestTypeDialog(RequestType requestType) async {
    final nameController = TextEditingController(text: requestType.name);
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Request Type'),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Request Type',
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Request Type is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final exists = _requestTypes.any(
                            (r) =>
                                r.id != requestType.id &&
                                r.name.toLowerCase() == name.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Request Type already exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final updated = requestType.copyWith(
                              name: name,
                              updatedAt: DateTime.now(),
                            );
                            await RequestTypeService.update(updated);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadData();
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isSubmitting = false);
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

  Future<void> _deleteRequestType(RequestType requestType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Request Type'),
        content: Text(
          'Delete ${requestType.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await RequestTypeService.delete(requestType.id);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Facility Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
            child: _buildManagementTabs(),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 14),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _activeView == _ManagementView.departments
                    ? 'Search departments...'
                    : _activeView == _ManagementView.buildings
                    ? 'Search buildings...'
                    : _activeView == _ManagementView.roomTypes
                    ? 'Search room types...'
                    : _activeView == _ManagementView.floors
                    ? 'Search floors...'
                    : 'Search request types...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeView == _ManagementView.departments
                ? _buildDepartmentList()
                : _activeView == _ManagementView.buildings
                ? _buildBuildingList()
                : _activeView == _ManagementView.roomTypes
                ? _buildRoomTypeList()
                : _activeView == _ManagementView.floors
                ? _buildFloorList()
                : _buildRequestTypeList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF4169E1),
        icon: const Icon(Icons.add, size: 22),
        label: Text(
          _activeView == _ManagementView.departments
              ? 'Add Department'
              : _activeView == _ManagementView.buildings
              ? 'Add Building'
              : _activeView == _ManagementView.roomTypes
              ? 'Add Room Type'
              : _activeView == _ManagementView.floors
              ? 'Add Floor'
              : 'Add Request Type',
        ),
        onPressed: _activeView == _ManagementView.departments
            ? _showAddDepartmentDialog
            : _activeView == _ManagementView.buildings
            ? _showAddBuildingDialog
            : _activeView == _ManagementView.roomTypes
            ? _showAddRoomTypeDialog
            : _activeView == _ManagementView.floors
            ? _showAddFloorDialog
            : _showAddRequestTypeDialog,
      ),
    );
  }

  Widget _buildManagementTabs() {
    final tabs = <({String label, _ManagementView view})>[
      (label: 'Department', view: _ManagementView.departments),
      (label: 'Building', view: _ManagementView.buildings),
      (label: 'Room Type', view: _ManagementView.roomTypes),
      (label: 'Floor', view: _ManagementView.floors),
      (label: 'Request Type', view: _ManagementView.requestTypes),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPillTab(
                label: tab.label,
                selected: _activeView == tab.view,
                onTap: () => _setActiveView(tab.view),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPillTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFF4169E1) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF111827),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTypeList() {
    final items = _filteredRequestTypes;
    if (items.isEmpty) {
      return const Center(child: Text('No request types found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final requestType = items[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            title: Text(
              requestType.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditRequestTypeDialog(requestType),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteRequestType(requestType),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setActiveView(_ManagementView view) {
    setState(() {
      _activeView = view;
      _searchController.clear();
    });
  }

  Widget _buildDepartmentList() {
    final items = _filteredDepartments;
    if (items.isEmpty) {
      return const Center(child: Text('No departments found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final department = items[index];
        return Card(
          child: ListTile(
            title: Text(department.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditDepartmentDialog(department),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteDepartment(department),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuildingList() {
    final items = _filteredBuildings;
    if (items.isEmpty) {
      return const Center(child: Text('No buildings found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final building = items[index];
        return Card(
          child: ListTile(
            title: Text(building.name),
            subtitle: Text('Code: ${building.code}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditBuildingDialog(building),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteBuilding(building),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomTypeList() {
    final items = _filteredRoomTypes;
    if (items.isEmpty) {
      return const Center(child: Text('No room types found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final roomType = items[index];
        return Card(
          child: ListTile(
            title: Text(roomType.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditRoomTypeDialog(roomType),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteRoomType(roomType),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloorList() {
    final items = _filteredFloors;
    if (items.isEmpty) {
      return const Center(child: Text('No floors found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final floor = items[index];
        return Card(
          child: ListTile(
            title: Text(floor.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditFloorDialog(floor),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteFloor(floor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
