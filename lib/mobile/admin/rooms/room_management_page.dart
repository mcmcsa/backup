import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/room_provider.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/services/room_service.dart';
import 'room_details_page.dart';
import 'qr_code_history_page.dart';
import '../shared/admin_app_bar.dart';
import '../../../shared/utils/dropdown_data_helper.dart';
import '../../../shared/utils/app_route_observer.dart';

class RoomManagementPage extends StatefulWidget {
  final VoidCallback openDrawer;

  const RoomManagementPage({super.key, required this.openDrawer});

  @override
  State<RoomManagementPage> createState() => _RoomManagementPageState();
}

class _RoomManagementPageState extends State<RoomManagementPage> with RouteAware {
  static const String _allDepartmentsOption = 'Department';
  static const String _allBuildingsOption = 'Buildings';
  static const String _allRoomTypesOption = 'Room Type';

  final _dropdownHelper = DropdownDataHelper();
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = ['All Rooms', 'Available', 'Unavailable'];
  final List<IconData> _filterIcons = [
    Icons.grid_view_rounded,
    Icons.check_circle_outline,
    Icons.cancel_outlined,
  ];
  List<Room> _rooms = [];
  List<String> _departmentOptions = [_allDepartmentsOption];
  List<String> _buildingOptions = [_allBuildingsOption];
  List<String> _roomTypeOptions = [_allRoomTypesOption];
  String _selectedDepartment = _allDepartmentsOption;
  String _selectedBuilding = _allBuildingsOption;
  String _selectedRoomType = _allRoomTypesOption;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _loadFilterOptions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _dropdownHelper.clearCache();
    _loadRooms();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final departments = await _dropdownHelper.getDepartmentNames();
      final buildings = await _dropdownHelper.getBuildingNames();
      final roomTypes = await _dropdownHelper.getRoomTypes();

      if (!mounted) return;
      setState(() {
        // Normalize legacy labels from previous UI versions.
        if (_selectedDepartment == 'All Departments' ||
            _selectedDepartment == 'Departments') {
          _selectedDepartment = _allDepartmentsOption;
        }
        if (_selectedBuilding == 'All Buildings') {
          _selectedBuilding = _allBuildingsOption;
        }
        if (_selectedRoomType == 'All Room Types' ||
            _selectedRoomType == 'All Room Type' ||
            _selectedRoomType == 'Room Types') {
          _selectedRoomType = _allRoomTypesOption;
        }

        _departmentOptions = [_allDepartmentsOption, ...departments];
        _buildingOptions = [_allBuildingsOption, ...buildings];
        _roomTypeOptions = [_allRoomTypesOption, ...roomTypes];
      });
    } catch (_) {}
  }

  Future<void> _loadRooms() async {
    try {
      List<Room> rooms = [];
      try {
        rooms = await RoomService.fetchAll();
      } catch (e) {
        debugPrint('RoomManagementPage: RoomService.fetchAll error: $e');
      }

      if (rooms.isEmpty && mounted) {
        final provRooms = context.read<RoomProvider>().rooms;
        if (provRooms.isNotEmpty) {
          rooms = List<Room>.from(provRooms);
        }
      }

      final activeRoomIds = <String>{};
      final activeRoomNames = <String>{};

      try {
        final rawRequests = await Supabase.instance.client
            .from('work_requests')
            .select('id, room_id, status');

        for (final req in rawRequests) {
          final status = (req['status'] ?? '').toString().toLowerCase();
          final isClosed = status == 'completed' ||
              status == 'declined' ||
              status == 'cancelled' ||
              status == 'declined/cancelled';
          if (isClosed) continue;

          final roomId = (req['room_id'] ?? '').toString().trim().toLowerCase();
          if (roomId.isNotEmpty) activeRoomIds.add(roomId);
        }
      } catch (e) {
        debugPrint('RoomManagementPage: fetch work_requests error: $e');
      }

      final mapped = rooms.map((room) {
        final roomIdLower = room.id.trim().toLowerCase();
        final roomCodeLower = room.code.trim().toLowerCase();
        final roomNameLower = room.name.trim().toLowerCase();

        final isReported = activeRoomIds.contains(roomIdLower) ||
            (roomCodeLower.isNotEmpty && activeRoomIds.contains(roomCodeLower)) ||
            (roomCodeLower.isNotEmpty && activeRoomNames.contains(roomCodeLower)) ||
            (roomNameLower.isNotEmpty && activeRoomNames.contains(roomNameLower));

        final effectiveStatus = (isReported || room.status.toLowerCase() != 'available')
            ? 'unavailable'
            : 'available';

        return room.copyWith(status: effectiveStatus);
      }).toList();

      if (mounted) {
        setState(() {
          _rooms = mapped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('RoomManagementPage: _loadRooms unhandled error: $e');
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  List<Room> get _filteredRooms {
    final query = _searchController.text.toLowerCase();
    var rooms = _rooms;

    // Apply filter
    if (_selectedFilter == 1) {
      rooms = rooms.where((r) => r.status.toLowerCase() == 'available').toList();
    } else if (_selectedFilter == 2) {
      rooms = rooms.where((r) => r.status.toLowerCase() != 'available').toList();
    }

    // Apply search
    if (query.isNotEmpty) {
      rooms = rooms
          .where(
            (r) =>
                r.code.toLowerCase().contains(query) ||
                r.id.toLowerCase().contains(query) ||
                r.name.toLowerCase().contains(query) ||
                r.building.toLowerCase().contains(query) ||
                r.department.toLowerCase().contains(query) ||
                r.roomType.toLowerCase().contains(query),
          )
          .toList();
    }

    if (_selectedDepartment != _allDepartmentsOption) {
      rooms = rooms
          .where(
            (r) =>
                r.department.toLowerCase() ==
                _selectedDepartment.toLowerCase(),
          )
          .toList();
    }

    if (_selectedBuilding != _allBuildingsOption) {
      rooms = rooms
          .where(
            (r) => r.building.toLowerCase() == _selectedBuilding.toLowerCase(),
          )
          .toList();
    }

    if (_selectedRoomType != _allRoomTypesOption) {
      rooms = rooms
          .where(
            (r) => r.roomType.toLowerCase() == _selectedRoomType.toLowerCase(),
          )
          .toList();
    }

    return rooms;
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AdminAppBar(
        openDrawer: widget.openDrawer,
      ),
      body: Column(
        children: [
          // Search & Filters Section
          Container(
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              boxShadow: [
                BoxShadow(
                  color: themeProvider.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: themeProvider.inputFillColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 15,
                      color: themeProvider.textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search Room Code',
                      hintStyle: TextStyle(
                        color: themeProvider.subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: themeProvider.inputFillColor,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Icon(
                          Icons.search_rounded,
                          color: themeProvider.subtitleColor,
                          size: 20,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: themeProvider.subtitleColor,
                                size: 20,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: themeProvider.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: themeProvider.borderColor),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        borderSide: BorderSide(
                          color: Color(0xFF4169E1),
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Compact 3-column dropdown filters
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 4.0;
                    final controlWidth = (constraints.maxWidth - (gap * 2)) / 3;
                    return Row(
                      children: [
                        _buildFilterDropdown(
                          label: 'Department',
                          value: _selectedDepartment,
                          items: _departmentOptions,
                          compact: true,
                          width: controlWidth,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedDepartment = value);
                          },
                        ),
                        const SizedBox(width: gap),
                        _buildFilterDropdown(
                          label: 'Building',
                          value: _selectedBuilding,
                          items: _buildingOptions,
                          compact: true,
                          width: controlWidth,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedBuilding = value);
                          },
                        ),
                        const SizedBox(width: gap),
                        _buildFilterDropdown(
                          label: 'Room Type',
                          value: _selectedRoomType,
                          items: _roomTypeOptions,
                          compact: true,
                          width: controlWidth,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedRoomType = value);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                // Filter Chips + QR History Action
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildStatusFilterChip(0),
                    _buildStatusFilterChip(1),
                    _buildStatusFilterChip(2),
                    _buildQrHistoryButton(),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // Stats Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth <= 430;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredRooms.length} rooms found',
                      style: TextStyle(
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? const Color(0xFF14381C)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_rooms.where((r) => r.status == 'available').length} Available',
                                style: TextStyle(
                                  fontSize: isCompact ? 10.5 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF22C55E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? const Color(0xFF451A1A)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_rooms.where((r) => r.status.toLowerCase() != 'available').length} Unavailable',
                                style: TextStyle(
                                  fontSize: isCompact ? 10.5 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Room List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4169E1)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading rooms...',
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredRooms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: themeProvider.chipColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.meeting_room_outlined,
                                size: 40,
                                color: themeProvider.subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No rooms found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adjusting your search or filter',
                              style: TextStyle(
                                fontSize: 13,
                                color: themeProvider.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRooms,
                        color: const Color(0xFF4169E1),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 100),
                          itemCount: _filteredRooms.length,
                          itemBuilder: (context, index) {
                            return _buildRoomCard(_filteredRooms[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isCompact = MediaQuery.of(context).size.width <= 430;
    final isAvailable = room.status.toLowerCase() == 'available';
    final statusColor = isAvailable ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final statusText = isAvailable ? 'Available' : 'Unavailable';
    final statusBgColor = isAvailable
        ? (isDark ? const Color(0xFF14381C) : const Color(0xFFDCFCE7))
        : (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2));
    final iconBgGradient = isAvailable
        ? (isDark
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)])
        : (isDark
            ? [const Color(0xFF451A1A), const Color(0xFF2D1212)]
            : [const Color(0xFFFEE2E2), const Color(0xFFFFEDD5)]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RoomDetailsPage(room: room)),
        ).then((_) => _loadRooms());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: themeProvider.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: themeProvider.borderColor),
          boxShadow: [
            BoxShadow(
              color: themeProvider.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 14),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: iconBgGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.meeting_room_rounded,
                            color: isAvailable
                                ? const Color(0xFF4169E1)
                                : const Color(0xFFEF4444),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: themeProvider.textColor,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room.code,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3B82F6),
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: themeProvider.subtitleColor,
                        ),
                        Text(
                          room.building,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: themeProvider.subtitleColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.event_seat_outlined,
                          size: 13,
                          color: themeProvider.subtitleColor,
                        ),
                        Text(
                          '${room.seats} seats',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RoomDetailsPage(room: room),
                              ),
                            ).then((_) => _loadRooms());
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: themeProvider.chipColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: themeProvider.borderColor),
                            ),
                            child: const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: Color(0xFF4169E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Room Icon with gradient
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: iconBgGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.meeting_room_rounded,
                        color: isAvailable ? const Color(0xFF4169E1) : const Color(0xFFEF4444),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Room Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: themeProvider.textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            room.code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3B82F6),
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: themeProvider.subtitleColor,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  room.building,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: themeProvider.subtitleColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: themeProvider.subtitleColor.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Icon(
                                Icons.event_seat_outlined,
                                size: 14,
                                color: themeProvider.subtitleColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${room.seats} seats',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: themeProvider.subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // View Details Icon Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomDetailsPage(room: room),
                          ),
                        ).then((_) => _loadRooms());
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: themeProvider.chipColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: themeProvider.borderColor),
                        ),
                        child: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: Color(0xFF4169E1),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool compact = false,
    double? width,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final controlWidth = width ?? (compact ? 110.0 : double.infinity);
    final labelSize = compact ? 11.0 : 12.0;
    final itemTextSize = compact ? 10.5 : 14.0;

    return SizedBox(
      width: controlWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w600,
                color: themeProvider.subtitleColor,
              ),
            ),
          SizedBox(height: compact ? 0 : 6),
          Container(
            height: compact ? 40 : 48,
            padding: EdgeInsets.only(
              left: compact ? 6 : 12,
              right: compact ? 4 : 12,
            ),
            decoration: BoxDecoration(
              color: themeProvider.inputFillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: themeProvider.cardColor,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: themeProvider.subtitleColor),
                style: TextStyle(
                  fontSize: itemTextSize,
                  color: themeProvider.textColor,
                  fontWeight: FontWeight.w500,
                ),
                isDense: true,
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: themeProvider.textColor),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF4169E1), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : themeProvider.cardColor,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: isSelected ? Colors.transparent : themeProvider.borderColor,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4169E1).withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _filterIcons[index],
              size: 14,
              color: isSelected ? Colors.white : themeProvider.subtitleColor,
            ),
            const SizedBox(width: 6),
            Text(
              _filters[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : themeProvider.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrHistoryButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const QRCodeHistoryPage(),
          ),
        );
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4169E1).withValues(alpha: 0.1),
              const Color(0xFF6366F1).withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: const Color(0xFF4169E1).withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: const Icon(
          Icons.qr_code_scanner_rounded,
          size: 18,
          color: Color(0xFF4169E1),
        ),
      ),
    );
  }
}
