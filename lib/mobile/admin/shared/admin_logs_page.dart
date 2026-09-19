import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/workflow_status_badge.dart';
import '../../../shared/providers/theme_provider.dart';
import '../ticket/request_details_page.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';

class _HistoryDayGroup {
  final DateTime day;
  final List<WorkRequest> entries;

  const _HistoryDayGroup({
    required this.day,
    required this.entries,
  });
}

class AdminHistoryPage extends StatefulWidget {
  const AdminHistoryPage({super.key});

  @override
  State<AdminHistoryPage> createState() => _AdminHistoryPageState();
}

class _AdminHistoryPageState extends State<AdminHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = <WorkRequest>[];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (!mounted) return;
      setState(() {
        _requests = data
            .where(
              (request) =>
                  ['completed', 'declined', 'cancelled'].contains(request.status.toLowerCase()),
            )
            .toList()
          ..sort((left, right) => right.dateSubmitted.compareTo(left.dateSubmitted));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requests = <WorkRequest>[];
        _isLoading = false;
      });
    }
  }

  List<WorkRequest> get _filteredRequests {
    var filtered = _requests;

    if (_selectedFilter == 'Completed') {
      filtered = filtered.where((request) => request.status.toLowerCase() == 'completed').toList();
    } else if (_selectedFilter == 'Declined') {
      filtered = filtered.where((request) => request.status.toLowerCase() == 'cancelled' || request.status.toLowerCase() == 'declined').toList();
    }

    if (_startDate != null && _endDate != null) {
      final start = DateUtils.dateOnly(_startDate!);
      final end = DateUtils.dateOnly(_endDate!).add(const Duration(days: 1));
      filtered = filtered.where((request) {
        return !request.dateSubmitted.isBefore(start) && request.dateSubmitted.isBefore(end);
      }).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((request) {
        final haystack =
            '${request.id} ${request.title} ${request.requestorName} '
            '${request.buildingName} ${request.officeRoom} ${request.department}'
                .toLowerCase();
        return haystack.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _showDateRangePicker() async {
    DateTime tempStart = _startDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime tempEnd = _endDate ?? DateTime.now();
    bool selectingStart = true;

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final dialogWidth = (screenWidth - 24).clamp(300.0, 520.0);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeDate = selectingStart ? tempStart : tempEnd;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: dialogWidth),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Date Range',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() => selectingStart = true);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: selectingStart ? const Color(0xFF14B8A6) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'From: ${_formatDate(tempStart)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selectingStart ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() => selectingStart = false);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: !selectingStart ? const Color(0xFF14B8A6) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'To: ${_formatDate(tempEnd)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: !selectingStart ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox(
                          height: 320,
                          child: CalendarDatePicker(
                            initialDate: activeDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            onDateChanged: (selectedDate) {
                              setDialogState(() {
                                if (selectingStart) {
                                  tempStart = selectedDate;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                } else {
                                  tempEnd = selectedDate;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempStart = tempEnd;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4169E1),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                DateTimeRange(start: tempStart, end: tempEnd),
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  List<_HistoryDayGroup> _groupRequestsByDay(List<WorkRequest> requests) {
    final grouped = <DateTime, List<WorkRequest>>{};

    for (final request in requests) {
      final day = DateUtils.dateOnly(request.dateSubmitted);
      grouped.putIfAbsent(day, () => <WorkRequest>[]).add(request);
    }

    return grouped.entries
        .map(
          (entry) => _HistoryDayGroup(
            day: entry.key,
            entries: List<WorkRequest>.from(entry.value)
              ..sort((left, right) => right.dateSubmitted.compareTo(left.dateSubmitted)),
          ),
        )
        .toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _openRequestDetails(WorkRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestDetailsPage(request: request),
      ),
    );
  }

  void _showRoomComparison(String roomId) {
    showDialog(
      context: context,
      builder: (context) => RoomComparisonDialog(roomId: roomId),
    );
  }

  Widget _buildSummaryCard(List<_HistoryDayGroup> groups) {
    final completedCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.entries.where((request) => request.status.toLowerCase() == 'completed').length,
    );
    final declinedCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.entries.where((request) => request.status.toLowerCase() == 'cancelled' || request.status.toLowerCase() == 'declined').length,
    );
    final totalCount = completedCount + declinedCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4169E1), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4169E1).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildSummaryItem('Total Records', totalCount.toString())),
          Container(width: 1, height: 38, color: Colors.white.withValues(alpha: 0.2)),
          Expanded(child: _buildSummaryItem('Completed', completedCount.toString())),
          Container(width: 1, height: 38, color: Colors.white.withValues(alpha: 0.2)),
          Expanded(child: _buildSummaryItem('Declined', declinedCount.toString())),
        ],
      ),
    );
  }

  String _formatRangeLabel() {
    if (_startDate == null || _endDate == null) {
      return 'Set Date Range';
    }

    return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(WorkRequest request, ThemeProvider themeProvider) {
    final isCompleted = request.status.toLowerCase() == 'completed';
    final statusColor = isCompleted ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final time = DateFormat('hh:mm a').format(request.dateSubmitted);
    final shortId = request.id.length > 8 ? request.id.substring(0, 8) : request.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? themeProvider.cardColor
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: themeProvider.isDarkMode ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openRequestDetails(request),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4169E1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$shortId',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4169E1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isCompleted ? 'Completed Request' : 'Declined Request',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: themeProvider.textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.subtitleColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Requestor: ${request.requestorName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.subtitleColor,
                            ),
                          ),
                          Text(
                            'Location: ${request.buildingName ?? "-"} • ${request.officeRoom ?? "-"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.subtitleColor,
                            ),
                          ),
                          if ((request.department?.isNotEmpty) ?? false)
                            Text(
                              'Department: ${request.department}',
                              style: TextStyle(
                                fontSize: 12,
                                color: themeProvider.subtitleColor,
                              ),
                            ),
                          if (isCompleted && request.dateCompleted != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Completed: ${_formatDate(request.dateCompleted!)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (!isCompleted)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'Declined / Cancelled',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        WorkflowStatusBadge(status: request.status),
                        const SizedBox(height: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: themeProvider.subtitleColor,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
                if (request.roomId != null && request.roomId!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: themeProvider.borderColor),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showRoomComparison(request.roomId!),
                        icon: const Icon(Icons.compare_rounded, size: 14),
                        label: const Text(
                          'Room Comparison',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          side: BorderSide(color: const Color(0xFF4169E1).withValues(alpha: 0.4)),
                          foregroundColor: const Color(0xFF4169E1),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _openRequestDetails(request),
                        icon: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: const Text(
                          'View Ticket',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          foregroundColor: const Color(0xFF0F766E),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(_HistoryDayGroup group, ThemeProvider themeProvider) {
    final dateLabel = DateFormat('MMMM dd, yyyy').format(group.day);
    final completedCount = group.entries.where((request) => request.status.toLowerCase() == 'completed').length;
    final declinedCount = group.entries.where((request) => request.status.toLowerCase() == 'cancelled' || request.status.toLowerCase() == 'declined').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: themeProvider.isDarkMode ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF4169E1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedCount completed • $declinedCount declined',
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.entries.map((entry) => _buildRequestCard(entry, themeProvider)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final filteredRequests = _filteredRequests;
    final groupedRequests = _groupRequestsByDay(filteredRequests);
    final isNarrow = MediaQuery.of(context).size.width < 420;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'History',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : RefreshIndicator(
              onRefresh: _loadRequests,
              color: const Color(0xFF4169E1),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Container(
                    color: themeProvider.cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            color: themeProvider.textColor,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search completed or declined requests...',
                            hintStyle: TextStyle(
                              color: themeProvider.subtitleColor,
                              fontSize: 14,
                            ),
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
                            filled: true,
                            fillColor: themeProvider.inputFillColor,
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
                              borderSide: BorderSide(color: Color(0xFF4169E1)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All', themeProvider),
                              const SizedBox(width: 8),
                              _buildFilterChip('Completed', themeProvider),
                              const SizedBox(width: 8),
                              _buildFilterChip('Declined', themeProvider),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date Range Selector
                        if (_startDate == null || _endDate == null)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showDateRangePicker,
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(
                                _formatRangeLabel(),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: themeProvider.textColor,
                                side: BorderSide(color: themeProvider.borderColor),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Date Range:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isNarrow)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4169E1).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFF4169E1),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Text(
                                          '${DateFormat('MMM dd').format(_startDate!)} -> ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: themeProvider.textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip: 'Change date range',
                                      onPressed: _showDateRangePicker,
                                      icon: const Icon(Icons.edit_rounded, size: 18),
                                      style: IconButton.styleFrom(
                                        backgroundColor: themeProvider.inputFillColor,
                                        foregroundColor: const Color(0xFF4169E1),
                                        minimumSize: const Size(32, 32),
                                        padding: const EdgeInsets.all(6),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    IconButton(
                                      tooltip: 'Clear date range',
                                      onPressed: _clearDateRange,
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      style: IconButton.styleFrom(
                                        backgroundColor: themeProvider.inputFillColor,
                                        foregroundColor: const Color(0xFFDC2626),
                                        minimumSize: const Size(32, 32),
                                        padding: const EdgeInsets.all(6),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4169E1).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF4169E1),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'From',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: themeProvider.subtitleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('MMM dd, yyyy').format(_startDate!),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: themeProvider.textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: themeProvider.subtitleColor,
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4169E1).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF4169E1),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'To',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: themeProvider.subtitleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('MMM dd, yyyy').format(_endDate!),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: themeProvider.textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Change date range',
                                      onPressed: _showDateRangePicker,
                                      icon: const Icon(Icons.edit_rounded),
                                      style: IconButton.styleFrom(
                                        backgroundColor: themeProvider.inputFillColor,
                                        foregroundColor: const Color(0xFF4169E1),
                                        minimumSize: const Size(36, 36),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: 'Clear date range',
                                      onPressed: _clearDateRange,
                                      icon: const Icon(Icons.close_rounded),
                                      style: IconButton.styleFrom(
                                        backgroundColor: themeProvider.inputFillColor,
                                        foregroundColor: const Color(0xFFDC2626),
                                        minimumSize: const Size(36, 36),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (filteredRequests.isNotEmpty) _buildSummaryCard(groupedRequests),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${filteredRequests.length} requests found',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (groupedRequests.isEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: themeProvider.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeProvider.borderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, size: 48, color: themeProvider.subtitleColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'No completed or declined requests found',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: themeProvider.subtitleColor),
                          ),
                        ],
                      ),
                    )
                  else
                    ...groupedRequests.map((group) => _buildDayCard(group, themeProvider)),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == label;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: const Color(0xFF4169E1),
      backgroundColor: themeProvider.inputFillColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : themeProvider.textColor,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF4169E1) : themeProvider.borderColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
