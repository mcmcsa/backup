import 'package:flutter/material.dart';

import '../../../shared/models/building_model.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/models/room_model.dart';
import '../../../shared/models/room_type_model.dart';
import '../../../shared/services/building_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/room_service.dart';
import '../../../shared/services/room_type_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../admin/shared/admin_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────────────────────

class SystemAdminRoomsView extends StatefulWidget {
  const SystemAdminRoomsView({super.key});

  @override
  State<SystemAdminRoomsView> createState() => _SystemAdminRoomsViewState();
}

class _SystemAdminRoomsViewState extends State<SystemAdminRoomsView> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Room> _rooms = [];
  List<Building> _buildings = [];
  List<Department> _departments = [];
  List<RoomType> _roomTypes = [];
  bool _loading = true;
  String? _error;

  // ── Filters ───────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all' | 'available' | 'reserved' | 'maintenance'

  // ── Pagination ────────────────────────────────────────────────────────────
  static const _pageSize = 12;
  int _page = 0;

  // ── Sort ──────────────────────────────────────────────────────────────────
  String _sortField = 'code'; // 'code' | 'name'
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _page = 0));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Data
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        RoomService.fetchAll(),
        BuildingService.fetchAll(),
        DepartmentService.fetchAll(),
        RoomTypeService.fetchAllIncludingInactive(),
      ]);

      if (mounted) {
        setState(() {
          _rooms = results[0] as List<Room>;
          _buildings = results[1] as List<Building>;
          _departments = results[2] as List<Department>;
          _roomTypes = results[3] as List<RoomType>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Derived
  // ─────────────────────────────────────────────────────────────────────────

  List<Room> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    var list = _rooms.where((r) {
      if (q.isNotEmpty) {
        final matchCode = r.code.toLowerCase().contains(q);
        final matchName = r.name.toLowerCase().contains(q);
        if (!matchCode && !matchName) return false;
      }
      if (_statusFilter != 'all' && r.status.toLowerCase() != _statusFilter) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      if (_sortField == 'code') {
        cmp = a.code.toLowerCase().compareTo(b.code.toLowerCase());
      } else {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Room> get _paginated {
    final f = _filtered;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filtered.isEmpty
      ? 1
      : ((_filtered.length - 1) / _pageSize).ceil());

  int get _available => _rooms.where((r) => r.status.toLowerCase() == 'available').length;
  int get _occupied => _rooms.where((r) => r.status.toLowerCase() == 'reserved' || r.status.toLowerCase() == 'occupied').length;
  int get _maintenance => _rooms.where((r) => r.status.toLowerCase() == 'maintenance').length;

  // ─────────────────────────────────────────────────────────────────────────
  //  Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _RoomFormDialog(
        title: 'Add Room',
        existingRooms: _rooms,
        buildings: _buildings,
        departments: _departments,
        roomTypes: _roomTypes,
        onSave: (name, code, bldgId, deptId, typeId, seats, floor, status) async {
          final err = await RoomService.create(
            name: name,
            code: code,
            buildingId: bldgId,
            departmentId: deptId,
            roomTypeId: typeId,
            seats: seats,
            floor: floor,
            status: status,
          );
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _load();
          _toast('Room added successfully.');
        },
      ),
    );
  }

  void _showEditDialog(Room room) async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool hasActive = false;
    try {
      hasActive = await WorkRequestService.hasActiveRequestForRoom(room.id);
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context); // Dismiss loading
    }

    if (hasActive) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Edit Blocked', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('This room cannot be edited while it has an ongoing work request.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => _RoomFormDialog(
        title: 'Edit Room',
        room: room,
        existingRooms: _rooms,
        buildings: _buildings,
        departments: _departments,
        roomTypes: _roomTypes,
        onSave: (name, code, bldgId, deptId, typeId, seats, floor, status) async {
          final err = await RoomService.updateRoom(
            id: room.id,
            name: name,
            code: code,
            buildingId: bldgId,
            departmentId: deptId,
            roomTypeId: typeId,
            seats: seats,
            floor: floor,
            status: status,
            allRooms: _rooms,
          );
          return err;
        },
        onSuccess: () {
          Navigator.pop(context);
          _load();
          _toast('Room updated.');
        },
      ),
    );
  }

  Future<void> _generateQR(Room room) async {
    final qrData = 'ROOM:${room.id}';
    await RoomService.updateQrCode(room.id, qrData);
    _toast('QR Code generated for ${room.code}.');
    _load();
  }

  Future<void> _delete(Room room) async {
    final confirmed = await _confirm(
      title: 'Delete Room',
      message:
          'Permanently delete room "${room.code}"?\n\nThis cannot be undone. All related assets, maintenance requests, and history may be affected.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed) return;

    final err = await RoomService.deleteRoom(room.id, room.code);
    if (err == null) {
      _toast('Room "${room.code}" has been deleted.');
      _load();
    } else {
      _toast('Error: $err', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            danger ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: danger ? AdminStyles.error : AdminStyles.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title, style: AdminStyles.headingStyle(fontSize: 18))),
        ]),
        content: Text(message, style: AdminStyles.bodyStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? AdminStyles.error : AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(msg)),
      ]),
      backgroundColor: isError ? AdminStyles.error : AdminStyles.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _toggleSort(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
      _page = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        color: AdminStyles.bg,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 32,
                isMobile ? 16 : 28,
                isMobile ? 16 : 32,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(isMobile),
                  const SizedBox(height: 20),
                  _buildStatCards(isMobile),
                  const SizedBox(height: 20),
                  _buildToolbar(isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32),
                child: _filtered.isEmpty
                    ? _buildEmpty()
                    : isMobile
                        ? _buildMobileCards()
                        : _buildDesktopTable(),
              ),
            ),
            if (_filtered.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 32, vertical: 12),
                child: _buildPagination(isMobile),
              ),
          ],
        ),
      );
    });
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildLoading() => Container(
        color: AdminStyles.bg,
        child: const Center(
          child: CircularProgressIndicator(
              color: AdminStyles.primary, strokeWidth: 3),
        ),
      );

  Widget _buildError() => Container(
        color: AdminStyles.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AdminStyles.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 36, color: AdminStyles.error),
              ),
              const SizedBox(height: 20),
              Text('Failed to load rooms',
                  style: AdminStyles.headingStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(_error ?? '', style: AdminStyles.bodyStyle(), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.meeting_room_rounded,
                size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'No rooms match your filters'
                  : 'No rooms yet',
              style: AdminStyles.headingStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _searchCtrl.text.isNotEmpty || _statusFilter != 'all'
                  ? 'Try adjusting your search or filters.'
                  : 'Click "Add Room" to get started.',
              style: AdminStyles.bodyStyle(),
            ),
            if (_searchCtrl.text.isEmpty && _statusFilter == 'all') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      );

  // ── Page header ───────────────────────────────────────────────────────────

  Widget _buildPageHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rooms & Offices',
                  style: AdminStyles.headingStyle(
                      fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Manage all rooms, capacities, and statuses.',
                  style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(isMobile ? 'Add' : 'Add Room'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminStyles.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded,
              color: AdminStyles.textSecondary),
        ),
      ],
    );
  }

  // ── Stat Cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards(bool isMobile) {
    final cards = [
      _Stat('Total Rooms', _rooms.length, Icons.meeting_room_rounded, AdminStyles.primary),
      _Stat('Available', _available, Icons.check_circle_rounded, AdminStyles.success),
      _Stat('Occupied', _occupied, Icons.people_rounded, AdminStyles.warning),
      _Stat('Maintenance', _maintenance, Icons.build_rounded, AdminStyles.error),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatTile(cards[0])),
              const SizedBox(width: 10),
              Expanded(child: _buildStatTile(cards[1])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStatTile(cards[2])),
              const SizedBox(width: 10),
              Expanded(child: _buildStatTile(cards[3])),
            ],
          ),
        ],
      );
    }
    return Row(
      children: cards.asMap().entries
          .expand((e) => [
                Expanded(child: _buildStatTile(e.value)),
                if (e.key < cards.length - 1) const SizedBox(width: 14),
              ])
          .toList(),
    );
  }

  Widget _buildStatTile(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(s.icon, color: s.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${s.value}',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: s.color,
                        letterSpacing: -0.5)),
                Text(s.label, style: AdminStyles.bodyStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────

  Widget _buildToolbar(bool isMobile) {
    final searchBox = Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(
            color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search rooms…',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AdminStyles.textMuted, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AdminStyles.textMuted, size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );

    final statusFilter = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(
              color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'available', child: Text('Available')),
            DropdownMenuItem(value: 'reserved', child: Text('Reserved/Occupied')),
            DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
          ],
          onChanged: (v) => setState(() {
            _statusFilter = v ?? 'all';
            _page = 0;
          }),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchBox,
          const SizedBox(height: 8),
          statusFilter,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 4, child: searchBox),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: statusFilter),
      ],
    );
  }

  // ── Desktop Table ─────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    final rows = _paginated;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildTableHeader(),
            const Divider(height: 1, color: AdminStyles.border),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (_, i) => _buildTableRow(rows[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          _sortableHeader('Room Code', 'code', flex: 2),
          _th('Building & Dept', flex: 3),
          _th('QR Assigned', flex: 1, center: true),
          _th('Status', flex: 2),
          _th('Actions', flex: 2, center: true),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, String field, {int flex = 1}) {
    final active = _sortField == field;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _toggleSort(field),
        child: Row(
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: active ? AdminStyles.primary : AdminStyles.textMuted,
                  letterSpacing: 1.0,
                )),
            const SizedBox(width: 4),
            Icon(
              active
                  ? (_sortAsc
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: active ? AdminStyles.primary : AdminStyles.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTableRow(Room room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Room Code
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.meeting_room_rounded, color: AdminStyles.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.code,
                        style: AdminStyles.bodyStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.textPrimary,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (room.name.isNotEmpty && room.name != room.code)
                        Text(
                          room.name,
                          style: AdminStyles.bodyStyle(
                              fontSize: 11, color: AdminStyles.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Building & Dept
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  room.building.isNotEmpty ? room.building : 'No Building',
                  style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminStyles.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  room.department.isNotEmpty ? room.department : 'General Use',
                  style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // QR
          Expanded(
            flex: 1,
            child: Center(
              child: Icon(
                room.qrCodeData != null && room.qrCodeData!.isNotEmpty
                    ? Icons.qr_code_2_rounded
                    : Icons.qr_code_rounded,
                color: room.qrCodeData != null && room.qrCodeData!.isNotEmpty
                    ? AdminStyles.primary
                    : AdminStyles.textMuted.withValues(alpha: 0.3),
                size: 24,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: _StatusChip(status: room.status),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: _buildActions(room),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Room room) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          color: AdminStyles.secondary,
          onTap: () => _showEditDialog(room),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.qr_code_scanner_rounded,
          tooltip: room.qrCodeData != null && room.qrCodeData!.isNotEmpty ? 'Replace QR' : 'Generate QR',
          color: AdminStyles.primary,
          onTap: () => _generateQR(room),
        ),
        const SizedBox(width: 6),
        _IconBtn(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Delete',
          color: AdminStyles.error,
          onTap: () => _delete(room),
        ),
      ],
    );
  }

  // ── Mobile Cards ──────────────────────────────────────────────────────────

  Widget _buildMobileCards() {
    return ListView.separated(
      itemCount: _paginated.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildMobileCard(_paginated[i]),
    );
  }

  Widget _buildMobileCard(Room room) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.meeting_room_rounded, color: AdminStyles.primary, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(room.code,
                          style: AdminStyles.bodyStyle(
                              fontWeight: FontWeight.w700,
                              color: AdminStyles.textPrimary,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    _StatusChip(status: room.status, compact: true),
                  ],
                ),
                if (room.name.isNotEmpty && room.name != room.code) ...[
                  const SizedBox(height: 2),
                  Text(room.name,
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
                ],
                const SizedBox(height: 6),
                Text('${room.building} • ${room.department.isNotEmpty ? room.department : "General"}',
                    style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      room.qrCodeData != null && room.qrCodeData!.isNotEmpty
                          ? Icons.qr_code_2_rounded
                          : Icons.qr_code_rounded,
                      size: 12,
                      color: room.qrCodeData != null && room.qrCodeData!.isNotEmpty
                          ? AdminStyles.primary
                          : AdminStyles.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(room.qrCodeData != null && room.qrCodeData!.isNotEmpty ? 'QR Active' : 'No QR',
                        style: AdminStyles.bodyStyle(
                            fontSize: 11, color: AdminStyles.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AdminStyles.textMuted, size: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _showEditDialog(room);
                  break;
                case 'qr':
                  _generateQR(room);
                  break;
                case 'delete':
                  _delete(room);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              _popItem(Icons.edit_outlined, 'Edit', 'edit'),
              _popItem(Icons.qr_code_scanner_rounded, 'Generate QR', 'qr', color: AdminStyles.primary),
              _popItem(Icons.delete_outline_rounded, 'Delete', 'delete',
                  color: AdminStyles.error),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(IconData icon, String label, String value,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? AdminStyles.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: AdminStyles.bodyStyle(
                color: color ?? AdminStyles.textPrimary, fontSize: 13)),
      ]),
    );
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Widget _buildPagination(bool isMobile) {
    final total = _filtered.length;
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isMobile)
          Text(
            'Showing $start–$end of $total',
            style: AdminStyles.bodyStyle(fontSize: 12),
          ),
        Row(
          children: [
            _PageBtn(
                icon: Icons.first_page_rounded,
                onTap: _page > 0 ? () => setState(() => _page = 0) : null),
            _PageBtn(
                icon: Icons.chevron_left_rounded,
                onTap: _page > 0 ? () => setState(() => _page--) : null),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: AdminStyles.primary,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${_page + 1} / ${_totalPages.clamp(1, 9999)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            _PageBtn(
                icon: Icons.chevron_right_rounded,
                onTap: _page < _totalPages - 1
                    ? () => setState(() => _page++)
                    : null),
            _PageBtn(
                icon: Icons.last_page_rounded,
                onTap: _page < _totalPages - 1
                    ? () => setState(() => _page = _totalPages - 1)
                    : null),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add / Edit Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _RoomFormDialog extends StatefulWidget {
  final String title;
  final Room? room;
  final List<Room> existingRooms;
  final List<Building> buildings;
  final List<Department> departments;
  final List<RoomType> roomTypes;
  final Future<String?> Function(String name, String code, String bldgId, String deptId, String typeId, int seats, String floor, String status) onSave;
  final VoidCallback onSuccess;

  const _RoomFormDialog({
    required this.title,
    this.room,
    required this.existingRooms,
    required this.buildings,
    required this.departments,
    required this.roomTypes,
    required this.onSave,
    required this.onSuccess,
  });

  @override
  State<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<_RoomFormDialog> {
  late final _codeCtrl = TextEditingController(text: widget.room?.code ?? '');
  late final _nameCtrl = TextEditingController(text: widget.room?.name ?? '');
  late final _floorCtrl = TextEditingController(text: widget.room?.floor ?? '1');
  late final _seatsCtrl = TextEditingController(text: widget.room?.seats.toString() ?? '0');
  
  String? _selectedBldgId;
  String? _selectedDeptId;
  String? _selectedTypeId;
  String _status = 'available';

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    if (widget.room != null) {
      if (widget.room!.buildingId.isNotEmpty) _selectedBldgId = widget.room!.buildingId;
      if (widget.room!.departmentId.isNotEmpty) _selectedDeptId = widget.room!.departmentId;
      if (widget.room!.roomTypeId.isNotEmpty) _selectedTypeId = widget.room!.roomTypeId;
      _status = widget.room!.status;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _floorCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _serverError = null; });

    final seats = int.tryParse(_seatsCtrl.text.trim()) ?? 0;

    final err = await widget.onSave(
      _nameCtrl.text.trim(),
      _codeCtrl.text.trim().toUpperCase(),
      _selectedBldgId ?? '',
      _selectedDeptId ?? '',
      _selectedTypeId ?? '',
      seats,
      _floorCtrl.text.trim(),
      _status,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err == null) {
      widget.onSuccess();
    } else {
      setState(() => _serverError = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AdminStyles.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.meeting_room_rounded,
                        color: AdminStyles.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.title,
                          style: AdminStyles.headingStyle(fontSize: 20))),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AdminStyles.textMuted),
                  ),
                ]),
                const SizedBox(height: 24),

                // Code and Name
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Room Number/Code *'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _codeCtrl,
                            autofocus: true,
                            textCapitalization: TextCapitalization.characters,
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.textPrimary,
                                fontWeight: FontWeight.w600),
                            decoration: _inputDecor(Icons.numbers_rounded,
                                hint: 'e.g. 101'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final dup = widget.existingRooms.any((r) =>
                                  r.id != (widget.room?.id ?? '') &&
                                  r.code.trim().toLowerCase() ==
                                      v.trim().toLowerCase());
                              if (dup) return 'Code exists.';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Name (Optional)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameCtrl,
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.textPrimary,
                                fontWeight: FontWeight.w600),
                            decoration: _inputDecor(Icons.label_outline_rounded,
                                hint: 'e.g. Physics Lab'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Building and Department
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Building'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBldgId,
                            decoration: _inputDecor(Icons.domain_rounded),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('None')),
                              ...widget.buildings.map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedBldgId = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Department'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDeptId,
                            decoration: _inputDecor(Icons.business_center_outlined),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('General Use')),
                              ...widget.departments.map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedDeptId = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Floor, Seats, Type
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Type'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTypeId,
                            decoration: _inputDecor(Icons.category_outlined),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('General')),
                              ...widget.roomTypes.map((t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text(t.name),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedTypeId = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Floor *'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _floorCtrl,
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.textPrimary,
                                fontWeight: FontWeight.w600),
                            decoration: _inputDecor(Icons.layers_rounded),
                            validator: (v) => v == null || v.isEmpty ? 'Req' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Seats'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _seatsCtrl,
                            keyboardType: TextInputType.number,
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.textPrimary,
                                fontWeight: FontWeight.w600),
                            decoration: _inputDecor(Icons.chair_alt_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status
                _label('Status'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: _inputDecor(Icons.info_outline_rounded),
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Available')),
                    DropdownMenuItem(value: 'reserved', child: Text('Reserved / Occupied')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'available'),
                ),

                // Server error
                if (_serverError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminStyles.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminStyles.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AdminStyles.error, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(_serverError!,
                            style: AdminStyles.bodyStyle(
                                color: AdminStyles.error,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.textSecondary,
                        side: const BorderSide(color: AdminStyles.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              widget.room == null ? 'Add Room' : 'Save Changes',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminStyles.textSecondary));
  }

  InputDecoration _inputDecor(IconData icon, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: AdminStyles.textSecondary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminStyles.error, width: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final bool compact;

  const _StatusChip({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'available':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Available';
        break;
      case 'reserved':
      case 'occupied':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFCA8A04);
        label = 'Occupied';
        break;
      case 'maintenance':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Maintenance';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = status.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon,
      required this.tooltip,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PageBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: onTap != null ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                border: Border.all(color: AdminStyles.border),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon,
                size: 18,
                color: onTap != null
                    ? AdminStyles.textPrimary
                    : AdminStyles.textMuted),
          ),
        ),
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _Stat(this.label, this.value, this.icon, this.color);
}
