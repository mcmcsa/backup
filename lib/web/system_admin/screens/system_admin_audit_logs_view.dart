import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/services/login_activity_service.dart';
import '../../admin/shared/admin_styles.dart';

class SystemAdminAuditLogsView extends StatefulWidget {
  const SystemAdminAuditLogsView({super.key});

  @override
  State<SystemAdminAuditLogsView> createState() => _SystemAdminAuditLogsViewState();
}

class _SystemAdminAuditLogsViewState extends State<SystemAdminAuditLogsView> {
  bool _loading = true;
  String? _error;
  List<LoginActivity> _allLogs = [];

  // Filters
  final _searchCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
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
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

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
      if (_endDate != null && log.loggedInAt.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
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
    if (_loading) return const Center(child: CircularProgressIndicator(color: AdminStyles.primary));
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: AdminStyles.error)));

    return LayoutBuilder(builder: (ctx, constraints) {
      final isMobile = constraints.maxWidth < 800;
      return Container(
        color: AdminStyles.bg,
        child: Column(
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
        if (!isMobile) ...[
          Container(
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
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search user, action, or details…',
          hintStyle: AdminStyles.bodyStyle(color: AdminStyles.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AdminStyles.textMuted, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
      ),
    );

    final dateFilter = InkWell(
      onTap: () async {
        final range = await showDialog<DateTimeRange>(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
              child: Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AdminStyles.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AdminStyles.textPrimary,
                  ),
                ),
                child: DateRangePickerDialog(
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _startDate != null && _endDate != null
                      ? DateTimeRange(start: _startDate!, end: _endDate!)
                      : null,
                ),
              ),
            ),
          ),
        );
        if (range != null) {
          setState(() {
            _startDate = range.start;
            _endDate = range.end;
            _page = 0;
          });
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminStyles.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: AdminStyles.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _startDate != null && _endDate != null
                    ? '${DateFormat.MMMd().format(_startDate!)} - ${DateFormat.MMMd().format(_endDate!)}'
                    : 'Any Date',
                style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, color: AdminStyles.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_startDate != null)
              GestureDetector(
                onTap: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                  _page = 0;
                }),
                child: const Icon(Icons.close_rounded, size: 16, color: AdminStyles.textMuted),
              )
          ],
        ),
      ),
    );

    final roleFilter = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _roleFilter,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminStyles.textMuted, size: 18),
          style: AdminStyles.bodyStyle(color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
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

    if (isMobile) {
      return Column(
        children: [
          searchBox,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: dateFilter),
              const SizedBox(width: 8),
              Expanded(child: roleFilter),
            ],
          ),
          const SizedBox(height: 8),
          Container(
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
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchBox),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: dateFilter),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: roleFilter),
      ],
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                children: [
                  _th('Timestamp', flex: 2),
                  _th('User & Role', flex: 3),
                  _th('Action', flex: 2),
                  _th('Affected Record', flex: 3),
                  _th('Device/IP', flex: 2),
                  _th('Status', flex: 1, center: true),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminStyles.border),
            Expanded(
              child: ListView.separated(
                itemCount: _paginated.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AdminStyles.border),
                itemBuilder: (_, i) => _buildTableRow(_paginated[i]),
              ),
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
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminStyles.textMuted, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildTableRow(LoginActivity log) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM d, yyyy').format(log.loggedInAt), style: AdminStyles.bodyStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(DateFormat('h:mm:ss a').format(log.loggedInAt), style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textSecondary)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.userName, style: AdminStyles.bodyStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AdminStyles.textPrimary)),
                Text(_formatRole(log.role), style: AdminStyles.bodyStyle(fontSize: 11, color: _getRoleColor(log.role))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getActionColor(log.eventType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                log.title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _getActionColor(log.eventType)),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              log.details ?? log.workRequestId ?? '-',
              style: AdminStyles.bodyStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Browser', style: AdminStyles.bodyStyle(fontSize: 12)),
                Text('Unknown IP', style: AdminStyles.bodyStyle(fontSize: 11, color: AdminStyles.textMuted)),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: AdminStyles.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('Success', style: TextStyle(fontSize: 10, color: AdminStyles.success, fontWeight: FontWeight.bold)),
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
      child: GestureDetector(
        onTap: onTap,
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
    );
  }
}
