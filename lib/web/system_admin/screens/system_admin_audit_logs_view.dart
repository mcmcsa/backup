import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/services/login_activity_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminAuditLogsView extends StatefulWidget {
  const SystemAdminAuditLogsView({super.key});

  @override
  State<SystemAdminAuditLogsView> createState() => _SystemAdminAuditLogsViewState();
}

enum DateFilterPreset { all, today, thisWeek, thisMonth, thisYear, custom }

class _SystemAdminAuditLogsViewState extends State<SystemAdminAuditLogsView> {
  bool _loading = true;
  String? _error;
  List<LoginActivity> _allLogs = [];
  StreamSubscription<void>? _changesSub;

  // Filters
  final _searchCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  DateFilterPreset _datePreset = DateFilterPreset.all;
  String _roleFilter = 'all';

  // Pagination
  static const _pageSize = 20;
  int _page = 0;

  // View Mode
  bool _isTimelineView = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _page = 0));
    _loadData();
    _changesSub = LoginActivityService.changes.listen((_) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final logs = await LoginActivityService.fetchAllLogs();
      if (mounted) {
        setState(() {
          _allLogs = logs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Derived Data ────────────────────────────────────────────────────────

  List<LoginActivity> get _filteredLogs {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allLogs.where((log) {
      if (q.isNotEmpty) {
        final matchesUser = log.userName.toLowerCase().contains(q);
        final matchesAction = log.title.toLowerCase().contains(q);
        final matchesDetails = (log.details ?? '').toLowerCase().contains(q);
        if (!matchesUser && !matchesAction && !matchesDetails) return false;
      }
      if (_roleFilter != 'all' && log.role.toLowerCase() != _roleFilter.toLowerCase()) return false;
      if (_startDate != null && log.loggedInAt.isBefore(_startDate!)) return false;
      if (_endDate != null && log.loggedInAt.isAfter(_endDate!)) return false;
      return true;
    }).toList();
  }

  List<LoginActivity> get _paginated {
    final f = _filteredLogs;
    final start = _page * _pageSize;
    if (start >= f.length) return [];
    return f.sublist(start, (start + _pageSize).clamp(0, f.length));
  }

  int get _totalPages => (_filteredLogs.isEmpty ? 1 : ((_filteredLogs.length - 1) / _pageSize).ceil());

  // ── Date Preset & Picker Methods ──────────────────────────────────────────

  void _applyPreset(DateFilterPreset preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      _page = 0;
      switch (preset) {
        case DateFilterPreset.all:
          _startDate = null;
          _endDate = null;
          break;
        case DateFilterPreset.today:
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case DateFilterPreset.thisWeek:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final sunday = monday.add(const Duration(days: 6));
          _startDate = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
          _endDate = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
          break;
        case DateFilterPreset.thisMonth:
          _startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
          _endDate = DateTime(lastDayOfMonth.year, lastDayOfMonth.month, lastDayOfMonth.day, 23, 59, 59, 999);
          break;
        case DateFilterPreset.thisYear:
          _startDate = DateTime(now.year, 1, 1, 0, 0, 0);
          _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
          break;
        case DateFilterPreset.custom:
          _startDate ??= DateTime(now.year, now.month, now.day, 0, 0, 0);
          _endDate ??= DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
      }
    });
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final initialDate = _startDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminStyles.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AdminStyles.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        if (_endDate != null && _startDate!.isAfter(_endDate!)) {
          _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
        }
        _datePreset = DateFilterPreset.custom;
        _page = 0;
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final initialDate = _endDate ?? (_startDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminStyles.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AdminStyles.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
        if (_startDate != null && _endDate!.isBefore(_startDate!)) {
          _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        }
        _datePreset = DateFilterPreset.custom;
        _page = 0;
      });
    }
  }

  Widget _buildPresetChip(String label, DateFilterPreset preset) {
    final isSelected = _datePreset == preset;
    return InkWell(
      onTap: () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AdminStyles.primary
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AdminStyles.primary
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AdminStyles.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    final hasDate = selectedDate != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasDate
              ? AdminStyles.primary.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDate
                ? AdminStyles.primary.withValues(alpha: 0.4)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: hasDate ? AdminStyles.primary : AdminStyles.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              hasDate
                  ? '$label: ${DateFormat('MMM d, yyyy').format(selectedDate)}'
                  : '$label Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasDate ? FontWeight.w700 : FontWeight.w600,
                color: hasDate ? AdminStyles.primary : AdminStyles.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exports ─────────────────────────────────────────────────────────────

  void _exportCSV() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Timestamp,User,Role,Action,Affected Record,IP Address,Device,Status');
    for (final log in _filteredLogs) {
      final ts = log.loggedInAt.toIso8601String();
      final user = log.userName.replaceAll(',', ' ');
      final role = log.role;
      final action = log.title.replaceAll(',', ' ');
      final record = (log.details ?? log.workRequestId ?? 'None').replaceAll(',', ' ');
      buffer.writeln('$ts,$user,$role,$action,$record,Unknown IP,Browser,Success');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Data (CSV / Excel format)'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SelectableText(buffer.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  // ── UI Building ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AdminStyles.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 32, isMobile ? 16 : 28, isMobile ? 16 : 32, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile),
                  const SizedBox(height: 20),
                  _buildToolbar(isMobile),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                child: _filteredLogs.isEmpty
                    ? _buildEmpty()
                    : _isTimelineView
                        ? _buildTimeline()
                        : _buildTable(),
              ),
            ),
            if (_filteredLogs.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: 12),
                child: _buildPagination(isMobile),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildLoading() => Container(
        width: double.infinity,
        height: double.infinity,
        color: AdminStyles.bg,
        child: const Center(
          child: CircularProgressIndicator(color: AdminStyles.primary, strokeWidth: 3),
        ),
      );

  Widget _buildError() => Container(
        width: double.infinity,
        height: double.infinity,
        color: AdminStyles.bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: AdminStyles.error),
              const SizedBox(height: 16),
              Text('Failed to load audit logs', style: AdminStyles.headingStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(_error ?? 'Unknown error occurred', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _loadData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminStyles.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audit & Activity Logs', style: AdminStyles.headingStyle(fontSize: isMobile ? 22 : 28)),
              const SizedBox(height: 4),
              Text('Track every action performed inside the system.', style: AdminStyles.bodyStyle(fontSize: 13)),
            ],
          ),
        ),
        if (isMobile) ...[
          IconButton(
            icon: Icon(
              _isTimelineView ? Icons.table_chart_rounded : Icons.timeline_rounded,
              color: AdminStyles.primary,
            ),
            tooltip: _isTimelineView ? 'Switch to Table View' : 'Switch to Timeline View',
            onPressed: () => setState(() => _isTimelineView = !_isTimelineView),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AdminStyles.primary),
            tooltip: 'Export CSV',
            onPressed: _exportCSV,
          ),
        ] else ...[
          Container(
            width: 200,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminStyles.border),
            ),
            child: Row(
              children: [
                _ViewToggleBtn(
                  icon: Icons.table_chart_rounded,
                  label: 'Table',
                  isActive: !_isTimelineView,
                  onTap: () => setState(() => _isTimelineView = false),
                ),
                _ViewToggleBtn(
                  icon: Icons.timeline_rounded,
                  label: 'Timeline',
                  isActive: _isTimelineView,
                  onTap: () => setState(() => _isTimelineView = true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _exportCSV,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildToolbar(bool isMobile) {
    final searchBox = Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(
          color: AdminStyles.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          hintText: 'Search user, action, or details…',
          hintStyle: AdminStyles.bodyStyle(
            color: AdminStyles.textMuted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AdminStyles.textMuted, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        ),
      ),
    );

    final roleFilter = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _roleFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(
            color: AdminStyles.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Roles')),
            DropdownMenuItem(value: 'admin', child: Text('System Admin')),
            DropdownMenuItem(value: 'campadmin', child: Text('Campus Admin')),
            DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
            DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
          ],
          onChanged: (v) => setState(() {
            _roleFilter = v ?? 'all';
            _page = 0;
          }),
        ),
      ),
    );

    final presetButtons = [
      _buildPresetChip('All Time', DateFilterPreset.all),
      _buildPresetChip('Today', DateFilterPreset.today),
      _buildPresetChip('This Week', DateFilterPreset.thisWeek),
      _buildPresetChip('This Month', DateFilterPreset.thisMonth),
      _buildPresetChip('This Year', DateFilterPreset.thisYear),
    ];

    final customDateControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDateButton(
          label: 'From',
          selectedDate: _startDate,
          onTap: _pickFromDate,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded,
              size: 14, color: AdminStyles.textMuted),
        ),
        _buildDateButton(
          label: 'To',
          selectedDate: _endDate,
          onTap: _pickToDate,
        ),
        if (_startDate != null || _endDate != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Clear date filter',
            child: InkWell(
              onTap: () => _applyPreset(DateFilterPreset.all),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminStyles.border),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AdminStyles.textSecondary),
              ),
            ),
          ),
        ],
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBox,
          const SizedBox(height: 8),
          roleFilter,
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminStyles.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined,
                        size: 15, color: AdminStyles.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Date Filter:',
                      style: AdminStyles.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminStyles.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: presetButtons
                        .map((b) =>
                            Padding(padding: const EdgeInsets.only(right: 6), child: b))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AdminStyles.border),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: customDateControls,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1120;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Search & Role Filter
            Row(
              children: [
                Expanded(child: searchBox),
                const SizedBox(width: 12),
                SizedBox(width: 200, child: roleFilter),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Date Filtering Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminStyles.border),
              ),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range_rounded,
                                size: 16, color: AdminStyles.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Date Filter:',
                              style: AdminStyles.bodyStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AdminStyles.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: presetButtons
                                      .map((b) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: b))
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1, color: AdminStyles.border),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: customDateControls,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.date_range_rounded,
                            size: 16, color: AdminStyles.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Date Filter:',
                          style: AdminStyles.bodyStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ...presetButtons.map((b) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: b)),
                        const Spacer(),
                        customDateControls,
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 60, color: AdminStyles.textMuted),
            const SizedBox(height: 16),
            Text('No logs match your filters', style: AdminStyles.headingStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Try adjusting your search or date range.', style: AdminStyles.bodyStyle()),
          ],
        ),
      );

  // ── Table View ──────────────────────────────────────────────────────────

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 1150.0;
            final tableWidth = constraints.maxWidth < minTableWidth
                ? minTableWidth
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          _th('Timestamp', flex: 2),
                          _th('User & Role', flex: 3),
                          _th('Action', flex: 3),
                          _th('Affected Record', flex: 4),
                          _th('Device / IP', flex: 2),
                          _th('Status', flex: 1, center: true),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AdminStyles.border),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _paginated.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AdminStyles.border),
                        itemBuilder: (_, i) => _buildTableRow(_paginated[i]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.only(right: center ? 0 : 14),
        child: Text(
          label.toUpperCase(),
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AdminStyles.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildTableRow(LoginActivity log) {
    final actionColor = _getActionColor(log.eventType);
    final roleColor = _getRoleColor(log.role);
    final roleName = _formatRole(log.role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // 1. Timestamp (flex: 2)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time_rounded,
                        size: 15, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy').format(log.loggedInAt),
                          style: AdminStyles.bodyStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AdminStyles.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('h:mm:ss a').format(log.loggedInAt),
                          style: AdminStyles.bodyStyle(
                            fontSize: 11,
                            color: AdminStyles.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. User & Role (flex: 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        log.userName.isNotEmpty
                            ? log.userName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.userName,
                          style: AdminStyles.bodyStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AdminStyles.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            roleName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: roleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Action (flex: 3)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: log.title,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: actionColor.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getActionIcon(log.eventType),
                            size: 13, color: actionColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            log.title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: actionColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Affected Record (flex: 4)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Tooltip(
                message: log.details ?? log.workRequestId ?? '-',
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined,
                        size: 14, color: AdminStyles.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        log.details ?? log.workRequestId ?? '—',
                        style: AdminStyles.bodyStyle(
                          fontSize: 12,
                          fontWeight: (log.details != null &&
                                  log.details!.isNotEmpty &&
                                  log.details != '-')
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: (log.details != null &&
                                  log.details!.isNotEmpty &&
                                  log.details != '-')
                              ? AdminStyles.textPrimary
                              : AdminStyles.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Device / IP (flex: 2)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.desktop_windows_outlined,
                        size: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Browser',
                          style: AdminStyles.bodyStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Unknown IP',
                          style: AdminStyles.bodyStyle(
                            fontSize: 10,
                            color: AdminStyles.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Status (flex: 1, center: true)
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Success',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline View ───────────────────────────────────────────────────────

  Widget _buildTimeline() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      padding: const EdgeInsets.all(24),
      child: ListView.builder(
        itemCount: _paginated.length,
        itemBuilder: (context, index) {
          final log = _paginated[index];
          final isLast = index == _paginated.length - 1;
          
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(DateFormat('MMM d').format(log.loggedInAt), style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(DateFormat('h:mm a').format(log.loggedInAt), style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: _getActionColor(log.eventType),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: _getActionColor(log.eventType).withValues(alpha: 0.4), blurRadius: 4)],
                      ),
                    ),
                    if (!isLast)
                      Expanded(child: Container(width: 2, color: AdminStyles.border)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getActionColor(log.eventType).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getActionColor(log.eventType).withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(log.title, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AdminStyles.textPrimary)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: _getRoleColor(log.role).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(_formatRole(log.role), style: TextStyle(fontSize: 10, color: _getRoleColor(log.role), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('By ${log.userName}', style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary)),
                          if (log.details != null && log.details!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(log.details!, style: AdminStyles.bodyStyle(fontSize: 13)),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Pagination ──────────────────────────────────────────────────────────

  Widget _buildPagination(bool isMobile) {
    final total = _filteredLogs.length;
    final start = _page * _pageSize + 1;
    final end = ((_page + 1) * _pageSize).clamp(0, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isMobile)
          Text('Showing $start–$end of $total logs', style: AdminStyles.bodyStyle(fontSize: 12)),
        Row(
          children: [
            _PageBtn(icon: Icons.first_page_rounded, onTap: _page > 0 ? () => setState(() => _page = 0) : null),
            _PageBtn(icon: Icons.chevron_left_rounded, onTap: _page > 0 ? () => setState(() => _page--) : null),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: AdminStyles.primary, borderRadius: BorderRadius.circular(8)),
              child: Text('${_page + 1} / ${_totalPages.clamp(1, 99999)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            _PageBtn(icon: Icons.chevron_right_rounded, onTap: _page < _totalPages - 1 ? () => setState(() => _page++) : null),
            _PageBtn(icon: Icons.last_page_rounded, onTap: _page < _totalPages - 1 ? () => setState(() => _page = _totalPages - 1) : null),
          ],
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return 'System Admin';
      case 'campadmin': return 'Campus Admin';
      case 'maintenance': return 'Maintenance';
      case 'teacher': return 'Teacher';
      default: return role.toUpperCase();
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return const Color(0xFF7C3AED);
      case 'campadmin': return const Color(0xFF0284C7);
      case 'maintenance': return const Color(0xFFD97706);
      case 'teacher': return const Color(0xFF059669);
      default: return AdminStyles.textSecondary;
    }
  }

  Color _getActionColor(String eventType) {
    if (eventType.toLowerCase() == 'login') return AdminStyles.info;
    if (eventType.toLowerCase().contains('delete') || eventType.toLowerCase().contains('remove')) return AdminStyles.error;
    if (eventType.toLowerCase().contains('add') || eventType.toLowerCase().contains('create')) return AdminStyles.success;
    if (eventType.toLowerCase().contains('update') || eventType.toLowerCase().contains('edit')) return AdminStyles.warning;
    return AdminStyles.secondary;
  }

  IconData _getActionIcon(String eventType) {
    final lower = eventType.toLowerCase();
    if (lower == 'login') return Icons.login_rounded;
    if (lower.contains('delete') || lower.contains('remove')) {
      return Icons.delete_outline_rounded;
    }
    if (lower.contains('add') ||
        lower.contains('create') ||
        lower.contains('insert')) {
      return Icons.add_circle_outline_rounded;
    }
    if (lower.contains('update') || lower.contains('edit')) {
      return Icons.edit_note_rounded;
    }
    if (lower.contains('qr')) {
      return Icons.qr_code_rounded;
    }
    return Icons.history_rounded;
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
            decoration: BoxDecoration(border: Border.all(color: AdminStyles.border), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: onTap != null ? AdminStyles.textPrimary : AdminStyles.textMuted),
          ),
        ),
      ),
    );
  }
}

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewToggleBtn({required this.icon, required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? AdminStyles.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: isActive ? AdminStyles.primary : AdminStyles.textSecondary),
                  const SizedBox(width: 6),
                  Text(label, style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? AdminStyles.primary : AdminStyles.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
