import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          return status == 'completed' || status == 'cancelled';
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
      filtered = filtered.where((item) => item.status.toLowerCase() == 'cancelled').toList();
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
    final declinedCount = _historyItems.where((item) => item.status.toLowerCase() == 'cancelled').length;

    return Material(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Maintenance History', style: AdminStyles.pageTitleStyle()),
              const SizedBox(height: 6),
              Text(
                'Completed and declined requests from database records',
                style: AdminStyles.pageSubtitleStyle(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TopStat(title: 'Total Records', value: _historyItems.length.toString(), color: AdminStyles.primary),
                  const SizedBox(width: 12),
                  _TopStat(title: 'Completed', value: completedCount.toString(), color: AdminStyles.success),
                  const SizedBox(width: 12),
                  _TopStat(title: 'Declined', value: declinedCount.toString(), color: AdminStyles.error),
                ],
              ),
              const SizedBox(height: 16),
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
                          filled: true,
                          fillColor: Colors.white,
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
                ],
              ),
              const SizedBox(height: 16),
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
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(48),
                            child: Center(
                              child: Text(
                                'No maintenance history found',
                                style: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 1000,
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
                                    separatorBuilder: (_, index) => const Divider(height: 1, color: AdminStyles.border),
                                    itemBuilder: (context, index) {
                                      return _HistoryTableRow(request: filtered[index]);
                                    },
                                  ),
                                ],
                              ),
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
    switch (status.toLowerCase()) {
      case 'completed':
        return AdminStyles.success;
      case 'cancelled':
        return AdminStyles.error;
      default:
        return AdminStyles.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'DECLINED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy');
    final shortId = widget.request.id.length > 8 ? widget.request.id.substring(0, 8) : widget.request.id;
    final sColor = _statusColor(widget.request.status);

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
                child: Tooltip(
                  message: 'View Details',
                  child: InkWell(
                    onTap: () async {
                      final roomId = widget.request.roomId;
                      bool showComparison = false;
                      if (roomId != null && roomId.isNotEmpty) {
                        try {
                          final response = await Supabase.instance.client
                              .from('room_versions')
                              .select('id')
                              .eq('room_id', roomId);
                          if ((response as List).length >= 2) {
                            showComparison = true;
                          }
                        } catch (_) {}
                      }

                      if (!mounted) return;

                      if (showComparison) {
                        showDialog(
                          context: context,
                          builder: (context) => RoomComparisonDialog(roomId: roomId!),
                        );
                      } else {
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
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminStyles.border),
                      ),
                      child: const Icon(Icons.visibility_outlined, size: 18, color: AdminStyles.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _TopStat({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
          children: [
            Text(title, style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
            const SizedBox(height: 8),
            Text(
              value,
              style: AdminStyles.headingStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
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
