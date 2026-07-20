import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/floor_model.dart';
import '../../../shared/services/floor_service.dart';
import '../shared/admin_styles.dart';
import 'facility_quick_actions_row.dart';

class AdminFloorsWeb extends StatefulWidget {
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final FacilityQuickActionsConfig quickActionsConfig;

  const AdminFloorsWeb({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
    required this.quickActionsConfig,
  });

  @override
  State<AdminFloorsWeb> createState() => _AdminFloorsWebState();
}

class _AdminFloorsWebState extends State<AdminFloorsWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _floors = [];
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
    _loadFloors();
  }

  Future<void> _loadFloors() async {
    try {
      final floors = await FloorService.fetchAll();

      if (!mounted) return;

      final mapped = floors.map((floor) {
        return {'floorModel': floor, 'id': floor.id, 'name': floor.name};
      }).toList();

      setState(() {
        _floors = mapped;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _floors = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddFloorDialog() async {
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
                    labelText: 'Floor Name',
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
                                content: Text('Floor name is required'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final now = DateTime.now();
                            final floor = Floor(
                              id: const Uuid().v4(),
                              name: name,
                              createdAt: now,
                              updatedAt: now,
                            );
                            await FloorService.insert(floor);
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadFloors();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor added successfully.'),
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

  Future<void> _showEditFloorDialog(Floor floor) async {
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
                    labelText: 'Floor Name',
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
                                content: Text('Floor name is required'),
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
                            await _loadFloors();
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Floor updated successfully.'),
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

  List<Map<String, dynamic>> get _filteredFloors {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _floors;
    return _floors
        .where((f) => f['name'].toLowerCase().contains(query))
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
            Text('Floors Management', style: AdminStyles.pageTitleStyle()),
            const SizedBox(height: 8),
            Text(
              'Manage facility floors and levels.',
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
              _buildFloorsTable(),
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
                    hintText: 'Search floors...',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddFloorDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Floor'),
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
                        hintText: 'Search floors...',
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
                onPressed: _showAddFloorDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Floor'),
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

  Widget _buildFloorsTable() {
    final filtered = _filteredFloors;
    if (filtered.isEmpty) {
      return Center(
        child: Text('No floors found', style: TextStyle(color: _subtleText)),
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
                              Expanded(child: _buildTableHeader('Floor Name')),
                              SizedBox(
                                width: actionsColWidth,
                                child: _buildTableHeader('Actions'),
                              ),
                            ],
                          ),
                        ),
                        ...filtered.asMap().entries.map((entry) {
                          final isLast = entry.key == filtered.length - 1;
                          final floor = entry.value;
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
                                        '${floor['name'] ?? '-'}',
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
                                          onPressed: () => _showEditFloorDialog(
                                            floor['floorModel'] as Floor,
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
