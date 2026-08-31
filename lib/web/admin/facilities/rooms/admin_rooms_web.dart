import 'package:flutter/material.dart';

import '../../../../shared/models/room_model.dart';
import '../../../../shared/services/room_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isGridView = false;
  RealtimeChannel? _roomsSubscription;

  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _successGreen = AdminStyles.success;
  static const Color _maintenanceRed = AdminStyles.error;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = AdminStyles.border;

  String _lower(dynamic value) => (value ?? '').toString().toLowerCase();

  String _text(dynamic value, {String fallback = '-'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _roomsSubscription = RoomService.listenToAllRooms((_) {
      _loadRooms();
    });
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
            : rawStatus == 'maintenance' || rawStatus == 'under maintenance' || rawStatus == 'under_maintenance'
                ? 'Unavailable'
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
      filtered = filtered.where((r) => _lower(r['status']) == 'unavailable').toList();
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
        return _rooms.where((room) => _lower(room['status']) == 'unavailable').length;
      default:
        return 0;
    }
  }

  String get _selectedFilterLabel {
    switch (_selectedFilter) {
      case 1:
        return 'Available Rooms';
      case 2:
        return 'Unavailable Rooms';
      default:
        return 'All Rooms';
    }
  }

  @override
  void dispose() {
    _roomsSubscription?.unsubscribe();
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
                      const SizedBox(height: 20),
                      _buildMainCard(isMobile: isMobile, isTablet: isTablet),
                    ],
                  ),
                );
              },
            ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSearchBar(width: double.infinity),
                          ),
                          const SizedBox(width: 10),
                          _buildRefreshButton(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    'Rooms List',
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
                          _buildViewToggle(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusFilterButton('All Rooms', 0),
                            const SizedBox(width: 8),
                            _buildStatusFilterButton('Available', 1),
                            const SizedBox(width: 8),
                            _buildStatusFilterButton('Unavailable', 2),
                          ],
                        ),
                      ),
                    ],
                  )
                else
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rooms List',
                            style: AdminStyles.headingStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _darkText,
                            ),
                          ),
                          Text(
                            '${filteredRooms.length} rooms',
                            style: AdminStyles.bodyStyle(fontSize: 12, color: _subtleText),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      _buildStatusFilterButton('All Rooms', 0),
                      const SizedBox(width: 8),
                      _buildStatusFilterButton('Available', 1),
                      const SizedBox(width: 8),
                      _buildStatusFilterButton('Unavailable', 2),
                      const Spacer(),
                      SizedBox(
                        width: 240,
                        child: _buildSearchBar(width: 240),
                      ),
                      const SizedBox(width: 12),
                      _buildViewToggle(),
                      const SizedBox(width: 10),
                      _buildRefreshButton(),
                    ],
                  ),
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
              : _isGridView
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 0, isMobile ? 14 : 24, 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 1400
                              ? 3
                              : constraints.maxWidth > 600
                                  ? 2
                                  : 1;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              mainAxisExtent: constraints.maxWidth < 600 ? 174 : (isMobile ? 196 : 174),
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
                    )
                  : isMobile
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredRooms.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return SizedBox(
                                height: 174,
                                child: _RoomCard(
                                  room: filteredRooms[index],
                                  onViewRoom: widget.onViewRoom,
                                  onEditRoom: widget.onEditRoom,
                                ),
                              );
                            },
                          ),
                        )
                      : _buildRoomsTable(filteredRooms),
        ],
      ),
    );
  }

  Widget _buildRoomsTable(List<Map<String, dynamic>> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = constraints.maxWidth > 800.0 ? constraints.maxWidth : 800.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minWidth,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: AdminStyles.bg.withValues(alpha: 0.5),
                    border: Border(
                      top: BorderSide(color: _borderColor),
                      bottom: BorderSide(color: _borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: _buildTableHeader('Code')),
                      Expanded(flex: 2, child: _buildTableHeader('Name')),
                      Expanded(flex: 2, child: _buildTableHeader('Department')),
                      Expanded(flex: 2, child: _buildTableHeader('Building')),
                      Expanded(flex: 1, child: _buildTableHeader('Status')),
                      Expanded(flex: 1, child: _buildTableHeader('Action')),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor.withValues(alpha: 0.5)),
                  itemBuilder: (context, index) {
                    return _RoomTableRow(
                      room: filtered[index],
                      onViewRoom: widget.onViewRoom,
                      onEditRoom: widget.onEditRoom,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildTableHeader(String title) {
    return Center(
      child: Text(
        title.toUpperCase(),
        textAlign: TextAlign.center,
        style: AdminStyles.bodyStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusFilterButton(String label, int index) {
    final isSelected = _selectedFilter == index;
    final themeColor = index == 0 
        ? AdminStyles.primary 
        : index == 1 
            ? AdminStyles.success 
            : AdminStyles.error;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? themeColor : AdminStyles.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AdminStyles.textSecondary,
          ),
        ),
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
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminStyles.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminStyles.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminStyles.primaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _isLoading = true);
          _loadRooms();
        },
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

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isGridView = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isGridView
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: _isGridView ? _primaryBlue : _subtleText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Grid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isGridView ? _primaryBlue : _subtleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => setState(() => _isGridView = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: !_isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !_isGridView
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.list_rounded,
                    size: 16,
                    color: !_isGridView ? _primaryBlue : _subtleText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'List',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: !_isGridView ? _primaryBlue : _subtleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final statusColor = isAvailable ? AdminStyles.success : AdminStyles.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      decoration: AdminStyles.cardDecoration(
        borderRadius: 24,
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
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final isNarrow = cardConstraints.maxWidth < 300;

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(widget.room['name'], fallback: 'Unnamed Room'),
                        style: AdminStyles.headingStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.apartment_outlined, size: 12, color: AdminStyles.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _text(widget.room['building']),
                              style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
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
                        ],
                      ),
                    ],
                  );
                }

                return Row(
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
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
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

class _RoomTableRow extends StatefulWidget {
  final Map<String, dynamic> room;
  final ValueChanged<Room>? onViewRoom;
  final ValueChanged<Room>? onEditRoom;

  const _RoomTableRow({
    required this.room,
    this.onViewRoom,
    this.onEditRoom,
  });

  @override
  State<_RoomTableRow> createState() => _RoomTableRowState();
}

class _RoomTableRowState extends State<_RoomTableRow> {
  bool _isHovered = false;

  String _lower(dynamic value) => (value ?? '').toString().toLowerCase();

  String _text(dynamic value, {String fallback = '-'}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final status = _lower(widget.room['status']);
    final isAvailable = status == 'available';
    final isUnavailable = status == 'unavailable' || status == 'maintenance';
    final statusColor = isAvailable 
        ? AdminStyles.success 
        : isUnavailable 
            ? AdminStyles.error 
            : const Color(0xFFF59E0B);
    final selectedRoom = widget.room['room'] as Room;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _isHovered ? AdminStyles.primary.withValues(alpha: 0.02) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
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
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _text(widget.room['name'], fallback: 'Unnamed Room'),
                textAlign: TextAlign.center,
                style: AdminStyles.headingStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _text(widget.room['department']),
                textAlign: TextAlign.center,
                style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _text(widget.room['building']),
                textAlign: TextAlign.center,
                style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: AdminStyles.pillDecoration(color: statusColor, isSecondary: true),
                  child: Text(
                    _text(widget.room['status'], fallback: 'Unknown').toUpperCase(),
                    style: AdminStyles.headingStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIconButton(
                    tooltip: 'View room',
                    icon: Icons.visibility_outlined,
                    onTap: () {
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
