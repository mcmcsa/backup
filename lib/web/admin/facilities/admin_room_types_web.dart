import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/room_type_model.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/room_type_service.dart';
import '../shared/admin_styles.dart';
import 'facility_quick_actions_row.dart';

class AdminRoomTypesWeb extends StatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final FacilityQuickActionsConfig quickActionsConfig;

  const AdminRoomTypesWeb({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
    required this.quickActionsConfig,
  });

  @override
  State<AdminRoomTypesWeb> createState() => _AdminRoomTypesWebState();
}

class _AdminRoomTypesWebState extends State<AdminRoomTypesWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _roomTypes = [];
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
    _loadRoomTypes();
  }

  Future<void> _loadRoomTypes() async {
    try {
      final roomTypes = await RoomTypeService.fetchAll();
      final rooms = await RoomService.fetchAll();

      if (!mounted) return;

      final mapped = roomTypes.map((roomType) {
        final typeRooms = rooms
            .where((room) => room.roomTypeId == roomType.id)
            .toList();
        final seats = typeRooms
            .map((room) => room.seats)
            .where((seat) => seat > 0)
            .toList();

        String capacity = '-';
        if (seats.isNotEmpty) {
          final minSeat = seats.reduce((a, b) => a < b ? a : b);
          final maxSeat = seats.reduce((a, b) => a > b ? a : b);
          capacity = minSeat == maxSeat ? '$minSeat' : '$minSeat-$maxSeat';
        }

        return {
          'roomTypeModel': roomType,
          'id': roomType.id,
          'name': roomType.name,
          'capacity': capacity,
          'features': '-',
          'count': typeRooms.length.toString(),
        };
      }).toList();

      setState(() {
        _roomTypes = mapped;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _roomTypes = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddRoomTypeDialog() async {
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
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Room Type Name',
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
                                content: Text('Room type name is required'),
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
                            await _loadRoomTypes();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Room type added successfully.'),
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

  Future<void> _showEditRoomTypeDialog(RoomType roomType) async {
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
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Room Type Name',
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
                                content: Text('Room type name is required'),
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
                            await _loadRoomTypes();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Room type updated successfully.',
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

    nameController.dispose();
  }



  List<Map<String, dynamic>> get _filteredRoomTypes {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _roomTypes;
    return _roomTypes
        .where((r) => r['name'].toLowerCase().contains(query))
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
            Text('Room Types Management', style: AdminStyles.pageTitleStyle()),
            const SizedBox(height: 8),
            Text(
              'Manage room categories and classifications.',
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
              _buildRoomTypesTable(),
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
                    hintText: 'Search room types...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddRoomTypeDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Room Type'),
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
                        hintText: 'Search room types...',
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
                onPressed: _showAddRoomTypeDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Room Type'),
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

  Widget _buildRoomTypesTable() {
    final filtered = _filteredRoomTypes;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No room types found',
          style: TextStyle(color: _subtleText),
        ),
      );
    }

    const typeColWidth = 380.0;
    const actionsColWidth = 120.0;
    const tableMinWidth = typeColWidth + actionsColWidth;

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
                              Expanded(child: _buildTableHeader('Type', alignment: Alignment.centerLeft)),
                              SizedBox(
                                width: actionsColWidth,
                                child: _buildTableHeader('Actions', alignment: Alignment.center),
                              ),
                            ],
                          ),
                        ),
                        ...filtered.asMap().entries.map((entry) {
                          final isLast = entry.key == filtered.length - 1;
                          final roomType = entry.value;
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
                                        '${roomType['name'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _darkText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                              _showEditRoomTypeDialog(
                                                roomType['roomTypeModel']
                                                    as RoomType,
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

  Widget _buildTableHeader(String title, {Alignment alignment = Alignment.centerLeft}) {
    return Align(
      alignment: alignment,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _subtleText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
