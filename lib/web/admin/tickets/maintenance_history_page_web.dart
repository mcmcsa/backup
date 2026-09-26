import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../shared/admin_styles.dart';
import 'admin_work_process_web.dart';
import '../admin_nav_controller.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

class MaintenanceHistoryPageWeb extends StatefulWidget {
  const MaintenanceHistoryPageWeb({super.key});

  @override
  State<MaintenanceHistoryPageWeb> createState() => _MaintenanceHistoryPageWebState();
}

class _MaintenanceHistoryPageWebState extends State<MaintenanceHistoryPageWeb> {
  final TextEditingController _searchController = TextEditingController();

  List<WorkRequest> _historyItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (!mounted) return;
      setState(() {
        _historyItems = data.where((item) {
          final status = item.status.toLowerCase();
          return status == 'completed' ||
              status == 'cancelled' ||
              status == 'canceled' ||
              status == 'declined' ||
              status == 'declined/cancelled';
        }).toList()
          ..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyItems = [];
        _isLoading = false;
      });
    }
  }

  List<WorkRequest> get _filteredItems {
    var filtered = List<WorkRequest>.from(_historyItems);

    if (_selectedFilter == 'Completed') {
      filtered = filtered.where((item) => item.status.toLowerCase() == 'completed').toList();
    } else if (_selectedFilter == 'Declined') {
      filtered = filtered.where((item) {
        if (item.isCancelled) return false;
        final s = item.status.toLowerCase();
        return s == 'declined';
      }).toList();
    } else if (_selectedFilter == 'Canceled') {
      filtered = filtered.where((item) {
        if (item.isCancelled) return true;
        final s = item.status.toLowerCase();
        return s == 'canceled' || s == 'cancelled' || s == 'declined/cancelled';
      }).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final buildingName = (item.buildingName ?? '').toLowerCase();
        final officeRoom = (item.officeRoom ?? '').toLowerCase();
        return item.id.toLowerCase().contains(query) ||
            item.title.toLowerCase().contains(query) ||
            item.requestorName.toLowerCase().contains(query) ||
            buildingName.contains(query) ||
            officeRoom.contains(query);
      }).toList();
    }

    return filtered;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final completedCount = _historyItems.where((item) => item.status.toLowerCase() == 'completed').length;
    final declinedCount = _historyItems.where((item) {
      if (item.isCancelled) return false;
      final s = item.status.toLowerCase();
      return s == 'declined';
    }).length;
    final canceledCount = _historyItems.where((item) {
      if (item.isCancelled) return true;
      final s = item.status.toLowerCase();
      return s == 'canceled' || s == 'cancelled' || s == 'declined/cancelled';
    }).length;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final isTablet = screenWidth >= 700 && screenWidth < 900;
    final paddingVal = isMobile ? 16.0 : (isTablet ? 20.0 : 28.0);

    return Material(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(paddingVal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: AdminStyles.pageTitleStyle()),
            const SizedBox(height: 16),
            // Responsive Metric Cards
            Row(
              children: [
                Expanded(
                  child: _TopStat(
                    title: isMobile ? 'Total' : 'Total Records',
                    value: _historyItems.length.toString(),
                    color: AdminStyles.primary,
                    isCompact: isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _TopStat(
                    title: 'Completed',
                    value: completedCount.toString(),
                    color: AdminStyles.success,
                    isCompact: isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _TopStat(
                    title: 'Declined',
                    value: declinedCount.toString(),
                    color: AdminStyles.error,
                    isCompact: isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _TopStat(
                    title: 'Canceled',
                    value: canceledCount.toString(),
                    color: const Color(0xFFE11D48),
                    isCompact: isMobile,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search and Filters
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminStyles.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: AdminStyles.bodyStyle(
                        fontSize: 13,
                        color: AdminStyles.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search history...',
                        hintStyle: AdminStyles.bodyStyle(
                          fontSize: 13,
                          color: AdminStyles.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: AdminStyles.textMuted, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedFilter == 'All',
                          onTap: () => setState(() => _selectedFilter = 'All'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Completed',
                          isSelected: _selectedFilter == 'Completed',
                          onTap: () => setState(() => _selectedFilter = 'Completed'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Declined',
                          isSelected: _selectedFilter == 'Declined',
                          onTap: () => setState(() => _selectedFilter = 'Declined'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Canceled',
                          isSelected: _selectedFilter == 'Canceled',
                          onTap: () => setState(() => _selectedFilter = 'Canceled'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminStyles.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: AdminStyles.bodyStyle(
                          fontSize: 13,
                          color: AdminStyles.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by ID, title, requestor, or location...',
                          hintStyle: AdminStyles.bodyStyle(
                            fontSize: 13,
                            color: AdminStyles.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 8),
                            child: Icon(Icons.search_rounded, color: AdminStyles.textMuted, size: 20),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completed',
                    isSelected: _selectedFilter == 'Completed',
                    onTap: () => setState(() => _selectedFilter = 'Completed'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Declined',
                    isSelected: _selectedFilter == 'Declined',
                    onTap: () => setState(() => _selectedFilter = 'Declined'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Canceled',
                    isSelected: _selectedFilter == 'Canceled',
                    onTap: () => setState(() => _selectedFilter = 'Canceled'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            // History Records Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminStyles.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator(color: AdminStyles.primary)),
                    )
                  : filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded, size: 48, color: AdminStyles.textMuted.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No maintenance history found',
                                  style: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : screenWidth < 900
                          // Mobile & Tablet Responsive Card View
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: AdminStyles.border),
                              itemBuilder: (context, index) {
                                return _buildMobileCard(filtered[index]);
                              },
                            )
                          // Desktop Table View
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = constraints.maxWidth > 900 ? constraints.maxWidth : 900.0;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                          decoration: const BoxDecoration(
                                            border: Border(bottom: BorderSide(color: AdminStyles.border)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 1, child: _buildTableHeader('Ticket ID')),
                                              Expanded(flex: 2, child: _buildTableHeader('Requestor')),
                                              Expanded(flex: 2, child: _buildTableHeader('Title / Issue')),
                                              Expanded(flex: 2, child: _buildTableHeader('Date & Location')),
                                              Expanded(flex: 1, child: _buildTableHeader('Status')),
                                              Expanded(flex: 1, child: _buildTableHeader('Action')),
                                            ],
                                          ),
                                        ),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: filtered.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminStyles.border),
                                          itemBuilder: (context, index) {
                                            return _HistoryTableRow(request: filtered[index]);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCard(WorkRequest request) {
    final formatter = DateFormat('MMM d, yyyy');
    final shortId = request.id.length > 8 ? request.id.substring(0, 8) : request.id;
    final isCompleted = request.status.toLowerCase() == 'completed';
    final isCancelled = request.isCancelled ||
        request.status.toLowerCase() == 'cancelled' ||
        request.status.toLowerCase() == 'canceled' ||
        request.status.toLowerCase() == 'declined/cancelled';
    final isDeclined = !isCancelled && request.status.toLowerCase() == 'declined';
    final sColor = isCompleted
        ? AdminStyles.success
        : (isCancelled
            ? const Color(0xFF64748B)
            : (isDeclined ? AdminStyles.error : AdminStyles.warning));
    final sLabel = isCompleted
        ? 'COMPLETED'
        : (isCancelled
            ? 'CANCELED'
            : (isDeclined ? 'DECLINED' : request.status.toUpperCase()));

    void openDetails() {
      final controller = AdminNavController.of(context);
      if (controller != null) {
        controller.openWorkProcess(request);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminWorkProcessWeb(request: request),
          ),
        );
      }
    }

    void openRoomComparison() {
      final roomId = request.roomId;
      if (roomId == null || roomId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No room associated with this request.')),
        );
        return;
      }
      showDialog(
        context: context,
        builder: (context) => RoomComparisonDialog(roomId: roomId),
      );
    }

    return InkWell(
      onTap: openDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: ID badge + Date + Status pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminStyles.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${shortId.toUpperCase()}',
                        style: AdminStyles.headingStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AdminStyles.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatter.format(request.dateSubmitted),
                      style: AdminStyles.bodyStyle(
                        fontSize: 12,
                        color: AdminStyles.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: AdminStyles.pillDecoration(color: sColor, isSecondary: true),
                  child: Text(
                    sLabel,
                    style: AdminStyles.headingStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: sColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Title / Issue
            Text(
              request.title.trim().isNotEmpty ? request.title : 'No Title Provided',
              style: AdminStyles.headingStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AdminStyles.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Requestor info
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: AdminStyles.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.requestorName.trim().isNotEmpty ? request.requestorName : 'Unknown Requestor',
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Location info
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${request.officeRoom ?? '-'}, ${request.buildingName ?? '-'}',
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: openDetails,
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text('View Details', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminStyles.primary,
                    side: const BorderSide(color: AdminStyles.border),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (request.roomId != null && request.roomId!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Compare Room',
                    icon: const Icon(Icons.difference_outlined, size: 18, color: Color(0xFF16A34A)),
                    onPressed: openRoomComparison,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0FDF4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF86EFAC)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTableRow extends StatefulWidget {
  final WorkRequest request;

  const _HistoryTableRow({required this.request});

  @override
  State<_HistoryTableRow> createState() => _HistoryTableRowState();
}

class _HistoryTableRowState extends State<_HistoryTableRow> {
  bool _isHovered = false;

  String _text(String? value, {String fallback = '-'}) {
    final text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  Color _statusColor(String status) {
    if (widget.request.isCancelled) return const Color(0xFF64748B);
    switch (status.toLowerCase()) {
      case 'completed':
        return AdminStyles.success;
      case 'cancelled':
      case 'canceled':
      case 'declined/cancelled':
        return const Color(0xFF64748B);
      case 'declined':
        return AdminStyles.error;
      default:
        return AdminStyles.textSecondary;
    }
  }

  String _statusLabel(String status) {
    if (widget.request.isCancelled) return 'CANCELED';
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
      case 'canceled':
      case 'declined/cancelled':
        return 'CANCELED';
      case 'declined':
        return 'DECLINED';
      default:
        return status.toUpperCase();
    }
  }

  void _openDetails() {
    final controller = AdminNavController.of(context);
    if (controller != null) {
      controller.openWorkProcess(widget.request);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminWorkProcessWeb(request: widget.request),
        ),
      );
    }
  }

  void _openRoomComparison() {
    final roomId = widget.request.roomId;
    if (roomId == null || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No room associated with this request.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => RoomComparisonDialog(roomId: roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');
    final shortId = widget.request.id.length > 8 ? widget.request.id.substring(0, 8) : widget.request.id;
    final sColor = _statusColor(widget.request.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _openDetails,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _isHovered ? AdminStyles.primary.withValues(alpha: 0.03) : Colors.transparent,
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
                      '#${shortId.toUpperCase()}',
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
                child: Center(
                  child: Text(
                    _text(widget.request.requestorName, fallback: 'Unknown User'),
                    textAlign: TextAlign.center,
                    style: AdminStyles.headingStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _text(widget.request.title, fallback: 'No Title'),
                      textAlign: TextAlign.center,
                      style: AdminStyles.bodyStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminStyles.textPrimary,
                      ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _text(widget.request.typeDisplay),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatter.format(widget.request.dateSubmitted),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_text(widget.request.officeRoom)}, ${_text(widget.request.buildingName)}',
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: AdminStyles.pillDecoration(color: sColor, isSecondary: true),
                  child: Text(
                    _statusLabel(widget.request.status),
                    style: AdminStyles.headingStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: sColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'View Details',
                      child: InkWell(
                        onTap: _openDetails,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AdminStyles.border),
                          ),
                          child: const Icon(Icons.visibility_outlined, size: 16, color: AdminStyles.textSecondary),
                        ),
                      ),
                    ),
                    if (widget.request.roomId != null && widget.request.roomId!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Compare Room Versions',
                        child: InkWell(
                          onTap: _openRoomComparison,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: const Icon(Icons.difference_outlined, size: 16, color: Color(0xFF16A34A)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: 'More Actions',
                      offset: const Offset(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (val) {
                        if (val == 'view') _openDetails();
                        if (val == 'compare') _openRoomComparison();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 16, color: AdminStyles.primary),
                              const SizedBox(width: 8),
                              Text('View Details', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        if (widget.request.roomId != null && widget.request.roomId!.isNotEmpty)
                          PopupMenuItem(
                            value: 'compare',
                            child: Row(
                              children: [
                                const Icon(Icons.difference_outlined, size: 16, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Text('Compare Room', style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminStyles.border),
                        ),
                        child: const Icon(Icons.more_vert_rounded, size: 16, color: AdminStyles.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _TopStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isCompact;

  const _TopStat({
    required this.title,
    required this.value,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdminStyles.bodyStyle(
              fontSize: isCompact ? 11 : 12,
              color: AdminStyles.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            value,
            style: AdminStyles.headingStyle(
              fontSize: isCompact ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AdminStyles.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AdminStyles.primary : AdminStyles.border,
          ),
        ),
        child: Text(
          label,
          style: AdminStyles.headingStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AdminStyles.textSecondary,
          ),
        ),
      ),
    );
  }
}
