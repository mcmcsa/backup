import 'package:flutter/material.dart';

import '../../../../shared/models/room_model.dart';
import '../../../../shared/services/room_service.dart';
import '../../shared/admin_styles.dart';
import 'add_room_page.dart';
import 'admin_room_details_page_web.dart';
import 'admin_edit_room_page_web.dart';

class AdminRoomsWeb extends StatefulWidget {
  final VoidCallback? onAddRoom;
  final ValueChanged<Room>? onEditRoom;
  final ValueChanged<Room>? onViewRoom;

  const AdminRoomsWeb({
    super.key,
    this.onAddRoom,
    this.onEditRoom,
    this.onViewRoom,
  });

  @override
  State<AdminRoomsWeb> createState() => _AdminRoomsWebState();
}

class _AdminRoomsWebState extends State<AdminRoomsWeb> {
  static const String _allDepartmentsOption = 'Department';
  static const String _allBuildingsOption = 'Building';
  static const String _allRoomTypesOption = 'Room Type';

  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0;
  String _selectedDepartment = _allDepartmentsOption;
  String _selectedBuilding = _allBuildingsOption;
  String _selectedRoomType = _allRoomTypesOption;
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _maintenanceRed = Color.fromRGBO(249, 26, 22, 1);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  String _lower(dynamic value) => (value ?? '').toString().toLowerCase();

  String _text(dynamic value, {String fallback = '-'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _openAddRoomPage() async {
    if (widget.onAddRoom != null) {
      widget.onAddRoom!();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddRoomPage()),
    );
    if (!mounted) return;
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await RoomService.fetchAll();

      if (!mounted) return;

      final mapped = rooms.map((room) {
        final rawStatus = _lower(room.status);
        final statusLabel = rawStatus == 'available'
            ? 'Available'
            : rawStatus == 'maintenance' || rawStatus == 'under maintenance'
                ? 'Under Maintenance'
                : _text(room.status, fallback: 'Unknown');

        return {
          'room': room,
          'code': _text(room.code.isNotEmpty ? room.code : room.id, fallback: 'N/A'),
          'name': _text(room.name, fallback: 'Unnamed Room'),
          'department': _text(room.department),
          'building': _text(room.building),
          'roomType': _text(room.roomType),
          'status': statusLabel,
        };
      }).toList();

      setState(() {
        _rooms = mapped;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rooms = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    final query = _searchController.text.toLowerCase();
    var filtered = List<Map<String, dynamic>>.from(_rooms);

    if (_selectedFilter == 1) {
      filtered = filtered.where((r) => _lower(r['status']) == 'available').toList();
    } else if (_selectedFilter == 2) {
      filtered = filtered.where((r) => _lower(r['status']) == 'under maintenance').toList();
    }

    if (_selectedDepartment != _allDepartmentsOption) {
      filtered = filtered
          .where((r) => _lower(r['department']) == _selectedDepartment.toLowerCase())
          .toList();
    }

    if (_selectedBuilding != _allBuildingsOption) {
      filtered = filtered
          .where((r) => _lower(r['building']) == _selectedBuilding.toLowerCase())
          .toList();
    }

    if (_selectedRoomType != _allRoomTypesOption) {
      filtered = filtered
          .where((r) => _lower(r['roomType']) == _selectedRoomType.toLowerCase())
          .toList();
    }

    if (query.isEmpty) return filtered;

    return filtered.where((r) {
      return _lower(r['code']).contains(query) ||
          _lower(r['name']).contains(query) ||
          _lower(r['department']).contains(query) ||
          _lower(r['building']).contains(query) ||
          _lower(r['roomType']).contains(query) ||
          _lower(r['status']).contains(query);
    }).toList();
  }

  List<String> _collectDistinct(String key) {
    final values = _rooms
        .map((room) => _text(room[key], fallback: ''))
        .where((value) => value.isNotEmpty && value != '-')
        .toSet()
        .toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _departmentOptions => [_allDepartmentsOption, ..._collectDistinct('department')];
  List<String> get _buildingOptions => [_allBuildingsOption, ..._collectDistinct('building')];
  List<String> get _roomTypeOptions => [_allRoomTypesOption, ..._collectDistinct('roomType')];

  int _countByFilter(int filter) {
    switch (filter) {
      case 0:
        return _rooms.length;
      case 1:
        return _rooms.where((room) => _lower(room['status']) == 'available').length;
      case 2:
        return _rooms.where((room) => _lower(room['status']) == 'under maintenance').length;
      default:
        return 0;
    }
  }

  String get _selectedFilterLabel {
    switch (_selectedFilter) {
      case 1:
        return 'Available Rooms';
      case 2:
        return 'Under Maintenance Rooms';
      default:
        return 'All Rooms';
    }
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
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 780;
                final isTablet = constraints.maxWidth >= 780 && constraints.maxWidth < 1200;

                return SingleChildScrollView(
                  primary: true,
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildStatsRow(isMobile: isMobile, isTablet: isTablet),
                      const SizedBox(height: 20),
                      _buildMainCard(isMobile: isMobile, isTablet: isTablet),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatsRow({required bool isMobile, required bool isTablet}) {
    final cards = [
      _StatCard(
        title: 'All Rooms',
        value: _countByFilter(0),
        icon: Icons.meeting_room_rounded,
        iconColor: _primaryBlue,
        isSelected: _selectedFilter == 0,
        onTap: () => setState(() => _selectedFilter = 0),
      ),
      _StatCard(
        title: 'Available',
        value: _countByFilter(1),
        icon: Icons.check_circle_rounded,
        iconColor: _successGreen,
        isSelected: _selectedFilter == 1,
        onTap: () => setState(() => _selectedFilter = 1),
      ),
      _StatCard(
        title: 'Under Maintenance',
        value: _countByFilter(2),
        icon: Icons.build_rounded,
        iconColor: _maintenanceRed,
        isSelected: _selectedFilter == 2,
        onTap: () => setState(() => _selectedFilter = 2),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    if (isTablet) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(width: 320, child: cards[0]),
          SizedBox(width: 320, child: cards[1]),
          SizedBox(width: 320, child: cards[2]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildMainCard({required bool isMobile, required bool isTablet}) {
    final filteredRooms = _filteredRooms;
    final shouldStackHeaderActions = isMobile || isTablet;
    final dropdownWidth = isMobile
      ? double.infinity
      : isTablet
        ? 180.0
        : 120.0;
    const desktopSearchWidth = 280.0;
    const desktopAddButtonWidth = 132.0;
    const desktopRefreshButtonWidth = 40.0;

    return Container(
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 14 : 18, isMobile ? 14 : 16, isMobile ? 14 : 18, isMobile ? 10 : 8),
            child: Column(
              children: [
                if (shouldStackHeaderActions)
                  Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.meeting_room_rounded,
                              color: _primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFilterLabel,
                                style: AdminStyles.headingStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _darkText,
                                ),
                              ),
                              Text(
                                '${filteredRooms.length} rooms',
                                style: AdminStyles.bodyStyle(fontSize: 13, color: _subtleText),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: _buildSearchBar(width: double.infinity)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _openAddRoomPage,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add Room'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildRefreshButton(),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.meeting_room_rounded,
                              color: _primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFilterLabel,
                                style: AdminStyles.headingStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _darkText,
                                ),
                              ),
                              Text(
                                '${filteredRooms.length} rooms',
                                style: AdminStyles.bodyStyle(fontSize: 13, color: _subtleText),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: dropdownWidth,
                                  child: _buildFilterDropdown(
                                    value: _selectedDepartment,
                                    items: _departmentOptions,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedDepartment = value);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: dropdownWidth,
                                  child: _buildFilterDropdown(
                                    value: _selectedBuilding,
                                    items: _buildingOptions,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedBuilding = value);
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: dropdownWidth,
                                  child: _buildFilterDropdown(
                                    value: _selectedRoomType,
                                    items: _roomTypeOptions,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _selectedRoomType = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: desktopSearchWidth + desktopAddButtonWidth + desktopRefreshButtonWidth + 22,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: desktopSearchWidth, child: _buildSearchBar(width: desktopSearchWidth)),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: desktopAddButtonWidth,
                                  height: 42,
                                  child: ElevatedButton.icon(
                                    onPressed: _openAddRoomPage,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Add Room'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: desktopRefreshButtonWidth,
                                  child: _buildRefreshButton(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 14 : 18, 0, isMobile ? 14 : 18, isMobile ? 14 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shouldStackHeaderActions) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: null,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: dropdownWidth,
                            child: _buildFilterDropdown(
                              value: _selectedDepartment,
                              items: _departmentOptions,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedDepartment = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: dropdownWidth,
                            child: _buildFilterDropdown(
                              value: _selectedBuilding,
                              items: _buildingOptions,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedBuilding = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: dropdownWidth,
                            child: _buildFilterDropdown(
                              value: _selectedRoomType,
                              items: _roomTypeOptions,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedRoomType = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // Legacy quick-status chips intentionally removed from UI as requested.
              ],
            ),
          ),
          filteredRooms.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No rooms found',
                          style: AdminStyles.headingStyle(
                            fontSize: 18,
                            color: _subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 0, isMobile ? 14 : 24, 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 1400
                          ? 3
                          : constraints.maxWidth > 900
                              ? 2
                              : 1;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          mainAxisExtent: 174,
                        ),
                        itemCount: filteredRooms.length,
                        itemBuilder: (context, index) {
                          return _RoomCard(
                            room: filteredRooms[index],
                            onViewRoom: widget.onViewRoom,
                            onEditRoom: widget.onEditRoom,
                          );
                        },
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({required double width}) {
    return SizedBox(
      width: width,
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: AdminStyles.bodyStyle(
          fontSize: 13,
          color: AdminStyles.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search rooms, type, building...',
          hintStyle: AdminStyles.bodyStyle(
            fontSize: 13,
            color: AdminStyles.textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminStyles.primary),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: const Color(0xFFFCFEFF),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCFE0F5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCFE0F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF93C5FD)),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loadRooms,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.refresh_rounded, color: _primaryBlue, size: 20),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rooms Management',
          style: AdminStyles.pageTitleStyle(),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage facilities and room information.',
          style: AdminStyles.pageSubtitleStyle(),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: _subtleText),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? _primaryBlue : _borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : _subtleText,
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final isAvailable = _lower(room['status']) == 'available';
    final statusColor = isAvailable ? _successGreen : _maintenanceRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 92,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Icon(
              Icons.meeting_room_rounded,
              color: isAvailable ? _successGreen : _maintenanceRed,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(room['name'], fallback: 'Unnamed Room'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _darkText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _text(room['code'], fallback: 'N/A'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoChip(label: 'Department', value: _text(room['department'])),
                    _InfoChip(label: 'Building', value: _text(room['building'])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _text(room['status'], fallback: 'Unknown'),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIconButton(
                    tooltip: 'View room',
                    icon: Icons.visibility_outlined,
                    onTap: () {
                      final selectedRoom = room['room'] as Room;
                      if (widget.onViewRoom != null) {
                        widget.onViewRoom!(selectedRoom);
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminRoomDetailsPageWeb(room: selectedRoom),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _ActionIconButton(
                    tooltip: 'Edit room',
                    icon: Icons.edit_outlined,
                    onTap: () {
                      final selectedRoom = room['room'] as Room;
                      if (widget.onEditRoom != null) {
                        widget.onEditRoom!(selectedRoom);
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminEditRoomPageWeb(room: selectedRoom),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: widget.isSelected
              ? AdminStyles.glassDecoration(
                  color: widget.iconColor,
                  opacity: 0.1,
                  borderRadius: 20,
                )
              : AdminStyles.cardDecoration(
                  borderRadius: 20,
                  borderColor: _isHovered ? widget.iconColor.withValues(alpha: 0.3) : null,
                ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value.toString(),
                    style: AdminStyles.headingStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AdminStyles.textPrimary,
                    ),
                  ),
                  Text(
                    widget.title.toUpperCase(),
                    style: AdminStyles.bodyStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AdminStyles.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (widget.isSelected) ...[
                const Spacer(),
                const Icon(Icons.check_circle_rounded, color: AdminStyles.primary, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatefulWidget {
  final Map<String, dynamic> room;
  final ValueChanged<Room>? onViewRoom;
  final ValueChanged<Room>? onEditRoom;

  const _RoomCard({
    required this.room,
    this.onViewRoom,
    this.onEditRoom,
  });

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _isHovered = false;

  String _lower(dynamic value) => (value ?? '').toString().toLowerCase();

  String _text(dynamic value, {String fallback = '-'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = _lower(widget.room['status']) == 'available';
    final statusColor = isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        decoration: AdminStyles.cardDecoration(
          borderRadius: 24,
          borderColor: _isHovered ? AdminStyles.primary : null,
        ).copyWith(
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _text(widget.room['code'], fallback: 'N/A'),
                    style: AdminStyles.headingStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminStyles.primary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: AdminStyles.pillDecoration(color: statusColor, isSecondary: true),
                  child: Text(
                    _text(widget.room['status'], fallback: 'Unknown').toUpperCase(),
                    style: AdminStyles.headingStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _text(widget.room['name'], fallback: 'Unnamed Room'),
                        style: AdminStyles.headingStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.apartment_outlined, size: 14, color: AdminStyles.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _text(widget.room['building']),
                              style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: AdminStyles.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _text(widget.room['department']),
                              style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionIconButton(
                      tooltip: 'View room',
                      icon: Icons.visibility_outlined,
                      onTap: () {
                        final selectedRoom = widget.room['room'] as Room;
                        if (widget.onViewRoom != null) {
                          widget.onViewRoom!(selectedRoom);
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminRoomDetailsPageWeb(room: selectedRoom),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _ActionIconButton(
                      tooltip: 'Edit room',
                      icon: Icons.edit_outlined,
                      onTap: () {
                        final selectedRoom = widget.room['room'] as Room;
                        if (widget.onEditRoom != null) {
                          widget.onEditRoom!(selectedRoom);
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminEditRoomPageWeb(room: selectedRoom),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                // Previous layout kept for reference: action icons were bottom-centered in this card.
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIconButton({required this.tooltip, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}
