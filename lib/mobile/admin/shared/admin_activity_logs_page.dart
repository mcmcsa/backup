import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/work_request_model.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/app_date_range_dialog.dart';
import '../ticket/request_details_page.dart';

class _AdminLogDayGroup {
  final DateTime day;
  final List<LoginActivity> entries;

  const _AdminLogDayGroup({
    required this.day,
    required this.entries,
  });
}

class AdminLogsPage extends StatefulWidget {
  const AdminLogsPage({super.key});

  @override
  State<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends State<AdminLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<LoginActivity> _logs = <LoginActivity>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  StreamSubscription<void>? _changesSub;

  // Filters matching Web layout
  String _selectedCategory = 'ALL'; // ALL, Actions, Logins, Logouts, Requests
  String _selectedDatePreset = 'All Time'; // All Time, Today, Past 7 Days, Past 30 Days, Custom
  DateTimeRange? _customDateRange;

  // Cached requests for instant ticket lookup
  List<WorkRequest>? _cachedRequests;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadLogs();
    _preloadWorkRequests();
    _changesSub = LoginActivityService.changes.listen((_) {
      if (mounted) _loadLogs(silent: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _changesSub?.cancel();
    super.dispose();
  }

  Future<void> _preloadWorkRequests() async {
    try {
      final requests = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() => _cachedRequests = requests);
      }
    } catch (_) {}
  }

  Future<void> _loadLogs({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final data = await LoginActivityService.fetchAdminLogs();
      if (!mounted) return;
      data.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
      setState(() {
        _logs = data;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _logs = <LoginActivity>[];
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Categorization & Utility Helpers (Identical to Web)
  // ─────────────────────────────────────────────────────────────

  bool _isLogout(LoginActivity log) {
    final eventType = log.eventType.toLowerCase();
    final title = log.title.toLowerCase();
    final details = (log.details ?? '').toLowerCase();
    return eventType == 'logout' ||
        title.contains('logout') ||
        details.contains('logged out');
  }

  bool _isLogin(LoginActivity log) {
    if (_isLogout(log)) return false;
    final eventType = log.eventType.toLowerCase();
    final title = log.title.toLowerCase();
    final details = (log.details ?? '').toLowerCase();
    return eventType == 'login' ||
        (title.contains('login') && !title.contains('logout')) ||
        (details.contains('logged in') && !details.contains('logged out'));
  }

  bool _isAction(LoginActivity log) {
    return !_isLogin(log) && !_isLogout(log);
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  String _shortTicketId(String? id) {
    if (id == null || id.trim().isEmpty) return '';
    final cleaned = id.trim().replaceAll('#', '');
    return '#${cleaned.substring(0, min(8, cleaned.length)).toUpperCase()}';
  }

  IconData _iconForLog(LoginActivity log) {
    if (_isLogout(log)) return Icons.logout_rounded;
    if (_isLogin(log)) return Icons.login_rounded;

    final title = log.title.toLowerCase();
    if (title.contains('approve')) return Icons.check_circle_rounded;
    if (title.contains('reject') || title.contains('declin')) {
      return Icons.cancel_rounded;
    }
    if (title.contains('rework')) return Icons.replay_rounded;
    if (title.contains('view')) return Icons.visibility_rounded;
    if (title.contains('create') || title.contains('add')) {
      return Icons.add_circle_outline_rounded;
    }
    if (title.contains('update') || title.contains('edit') || title.contains('change') || title.contains('status')) {
      return Icons.edit_note_rounded;
    }
    if (title.contains('delete') || title.contains('remove')) {
      return Icons.delete_outline_rounded;
    }
    if (title.contains('repair') || title.contains('maintenance')) {
      return Icons.build_rounded;
    }
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (_isLogout(log)) return const Color(0xFFEF4444);
    if (_isLogin(log)) return const Color(0xFF0284C7);

    final title = log.title.toLowerCase();
    if (title.contains('approve') || title.contains('completed')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) {
      return const Color(0xFFDC2626);
    }
    if (title.contains('rework')) return const Color(0xFFD97706);
    if (title.contains('view')) return const Color(0xFF0EA5E9);
    if (title.contains('create') || title.contains('add')) return const Color(0xFF7C3AED);
    if (title.contains('update') || title.contains('edit') || title.contains('change') || title.contains('status')) {
      return const Color(0xFFF59E0B);
    }
    if (title.contains('delete') || title.contains('remove')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF0F766E);
  }

  String _categoryLabelForLog(LoginActivity log) {
    if (_isLogin(log)) return 'Login';
    if (_isLogout(log)) return 'Logout';
    if (log.workRequestId != null && log.workRequestId!.trim().isNotEmpty) {
      return 'Ticket';
    }
    final title = log.title.toLowerCase();
    if (title.contains('room') || title.contains('building') || title.contains('facility')) {
      return 'Facility';
    }
    return 'Action';
  }

  // ─────────────────────────────────────────────────────────────
  // Filtered Logs
  // ─────────────────────────────────────────────────────────────

  List<LoginActivity> get _filteredLogs {
    var list = List<LoginActivity>.from(_logs);

    // 1. Category filter
    if (_selectedCategory == 'Actions') {
      list = list.where(_isAction).toList();
    } else if (_selectedCategory == 'Logins') {
      list = list.where(_isLogin).toList();
    } else if (_selectedCategory == 'Logouts') {
      list = list.where(_isLogout).toList();
    } else if (_selectedCategory == 'Requests') {
      list = list.where((l) => l.workRequestId != null && l.workRequestId!.trim().isNotEmpty).toList();
    }

    // 2. Date preset filter
    final now = DateTime.now();
    if (_selectedDatePreset == 'Today') {
      list = list.where((l) => _isToday(l.loggedInAt)).toList();
    } else if (_selectedDatePreset == 'Past 7 Days') {
      final cutoff = now.subtract(const Duration(days: 7));
      list = list.where((l) => l.loggedInAt.isAfter(cutoff)).toList();
    } else if (_selectedDatePreset == 'Past 30 Days') {
      final cutoff = now.subtract(const Duration(days: 30));
      list = list.where((l) => l.loggedInAt.isAfter(cutoff)).toList();
    } else if (_selectedDatePreset == 'Custom' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      list = list.where((l) => l.loggedInAt.isAfter(start) && l.loggedInAt.isBefore(end)).toList();
    }

    // 3. Search query filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((l) {
        return l.title.toLowerCase().contains(query) ||
            l.userName.toLowerCase().contains(query) ||
            l.role.toLowerCase().contains(query) ||
            (l.details?.toLowerCase().contains(query) ?? false) ||
            (l.workRequestId?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return list;
  }

  List<_AdminLogDayGroup> _groupLogsByDay(List<LoginActivity> logs) {
    final grouped = <DateTime, List<LoginActivity>>{};

    for (final log in logs) {
      final day = DateUtils.dateOnly(log.loggedInAt);
      grouped.putIfAbsent(day, () => <LoginActivity>[]).add(log);
    }

    return grouped.entries
        .map(
          (entry) => _AdminLogDayGroup(
            day: entry.key,
            entries: List<LoginActivity>.from(entry.value)
              ..sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt)),
          ),
        )
        .toList();
  }

  Future<void> _openRelatedTicket(String workRequestId) async {
    final messenger = ScaffoldMessenger.of(context);
    WorkRequest? targetRequest;

    if (_cachedRequests != null) {
      targetRequest = _cachedRequests!.where((r) {
        return r.id.toLowerCase() == workRequestId.toLowerCase() ||
            r.id.toLowerCase().startsWith(workRequestId.toLowerCase());
      }).firstOrNull;
    }

    if (targetRequest == null) {
      try {
        final fetched = await WorkRequestService.fetchAll();
        if (mounted) setState(() => _cachedRequests = fetched);
        targetRequest = fetched.where((r) {
          return r.id.toLowerCase() == workRequestId.toLowerCase() ||
              r.id.toLowerCase().startsWith(workRequestId.toLowerCase());
        }).firstOrNull;
      } catch (_) {}
    }

    if (!mounted) return;

    if (targetRequest != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequestDetailsPage(request: targetRequest!),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ticket #$workRequestId could not be found or may have been archived.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showCustomDateRangePicker() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => AppDateRangeDialog(
        firstDate: DateTime(2023),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialStartDate: _customDateRange?.start ?? DateTime.now().subtract(const Duration(days: 7)),
        initialEndDate: _customDateRange?.end ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDatePreset = 'Custom';
        _customDateRange = picked;
      });
    }
  }

  void _showLogDetailsDialog(LoginActivity log) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final color = _colorForLog(log);
    final icon = _iconForLog(log);
    final category = _categoryLabelForLog(log);
    final formattedDate = DateFormat('MMMM dd, yyyy').format(log.loggedInAt);
    final formattedTime = DateFormat('hh:mm:ss a').format(log.loggedInAt);
    final relativeTime = _formatRelativeTime(log.loggedInAt);
    final shortId = _shortTicketId(log.workRequestId);

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: themeProvider.cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                icon: Icon(Icons.close_rounded, size: 20, color: themeProvider.subtitleColor),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            log.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: themeProvider.borderColor),
                const SizedBox(height: 16),

                // Metadata Cards Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242424) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeProvider.borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildModalMetaRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Performed By',
                        value: '${log.userName} (${log.role.toUpperCase()})',
                        themeProvider: themeProvider,
                      ),
                      const SizedBox(height: 10),
                      _buildModalMetaRow(
                        icon: Icons.access_time_rounded,
                        label: 'Timestamp (PHT)',
                        value: '$formattedDate at $formattedTime\n($relativeTime)',
                        themeProvider: themeProvider,
                      ),
                      if (log.userId.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildModalMetaRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'User ID',
                          value: log.userId,
                          isMonospace: true,
                          themeProvider: themeProvider,
                          trailing: IconButton(
                            icon: Icon(Icons.copy_rounded, size: 15, color: themeProvider.subtitleColor),
                            tooltip: 'Copy User ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: log.userId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User ID copied to clipboard!')),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Details section
                if (log.details != null && log.details!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'ACTION DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: themeProvider.subtitleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF242424) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: themeProvider.borderColor),
                    ),
                    child: Text(
                      log.details!,
                      style: TextStyle(
                        fontSize: 13,
                        color: themeProvider.textColor,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],

                // Related Ticket Row
                if (log.workRequestId != null && log.workRequestId!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RELATED TICKET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: themeProvider.subtitleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _openRelatedTicket(log.workRequestId!);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4169E1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4169E1).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link_rounded, size: 14, color: Color(0xFF4169E1)),
                              const SizedBox(width: 4),
                              Text(
                                shortId,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4169E1),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF4169E1)),
                            ],
                          ),
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

  Widget _buildModalMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeProvider themeProvider,
    bool isMonospace = false,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: themeProvider.subtitleColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.subtitleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: isMonospace ? 'monospace' : null,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UI Builder
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final filtered = _filteredLogs;
    final groupedLogs = _groupLogsByDay(filtered);

    // Summary counts
    final totalCount = _logs.length;
    final actionCount = _logs.where(_isAction).length;
    final loginCount = _logs.where(_isLogin).length;
    final ticketCount = _logs.where((l) => l.workRequestId != null && l.workRequestId!.isNotEmpty).length;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Logs',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_rounded, size: 20, color: themeProvider.textColor),
            tooltip: 'Filter by Date',
            onPressed: _showCustomDateRangePicker,
          ),
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: themeProvider.textColor,
                    ),
                  )
                : Icon(Icons.refresh_rounded, color: themeProvider.textColor),
            onPressed: () => _loadLogs(silent: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Container (Web-inspired Design)
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Search Bar
                TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 13.5, color: themeProvider.textColor),
                  decoration: InputDecoration(
                    hintText: 'Search logs, users, actions, or ticket IDs...',
                    hintStyle: TextStyle(
                      color: themeProvider.subtitleColor,
                      fontSize: 13,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.search_rounded, color: themeProvider.subtitleColor, size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: themeProvider.subtitleColor),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: themeProvider.inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.borderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0xFF4169E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Category Chips Bar (ALL, Actions, Logins, Logouts, Requests)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('ALL', themeProvider),
                      const SizedBox(width: 6),
                      _buildCategoryChip('Actions', themeProvider),
                      const SizedBox(width: 6),
                      _buildCategoryChip('Logins', themeProvider),
                      const SizedBox(width: 6),
                      _buildCategoryChip('Logouts', themeProvider),
                      const SizedBox(width: 6),
                      _buildCategoryChip('Requests', themeProvider),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Date Preset Chips (All Time, Today, Past 7 Days, Past 30 Days, Custom)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDateChip('All Time', themeProvider),
                      const SizedBox(width: 6),
                      _buildDateChip('Today', themeProvider),
                      const SizedBox(width: 6),
                      _buildDateChip('Past 7 Days', themeProvider),
                      const SizedBox(width: 6),
                      _buildDateChip('Past 30 Days', themeProvider),
                      const SizedBox(width: 6),
                      _buildDateChip(
                        _selectedDatePreset == 'Custom' && _customDateRange != null
                            ? '${DateFormat('MMM d').format(_customDateRange!.start)} - ${DateFormat('MMM d').format(_customDateRange!.end)}'
                            : 'Custom',
                        themeProvider,
                        isCustomPicker: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mini Stats Banner (Web-Style Quick Overview)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: themeProvider.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatPill('Total', '$totalCount', themeProvider),
                _buildStatPill('Actions', '$actionCount', themeProvider),
                _buildStatPill('Logins', '$loginCount', themeProvider),
                _buildStatPill('Tickets', '$ticketCount', themeProvider),
              ],
            ),
          ),

          // Log List Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              color: themeProvider.subtitleColor.withValues(alpha: 0.5),
                              size: 56,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No activity logs found',
                              style: TextStyle(
                                color: themeProvider.textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No logs matching "${_searchController.text}"'
                                  : 'Try adjusting your filters or date range.',
                              style: TextStyle(
                                color: themeProvider.subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          children: [
                            ...groupedLogs.map((group) => _buildDayGroupCard(group, themeProvider)),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String count, ThemeProvider themeProvider) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: themeProvider.subtitleColor,
          ),
        ),
        Text(
          count,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedCategory == label;
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4169E1)
              : (isDark ? const Color(0xFF282828) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4169E1)
                : themeProvider.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : themeProvider.subtitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, ThemeProvider themeProvider, {bool isCustomPicker = false}) {
    final isSelected = isCustomPicker ? _selectedDatePreset == 'Custom' : _selectedDatePreset == label;
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: () {
        if (isCustomPicker) {
          _showCustomDateRangePicker();
        } else {
          setState(() => _selectedDatePreset = label);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1))
                : themeProvider.borderColor.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustomPicker) ...[
              Icon(Icons.date_range_rounded, size: 12, color: themeProvider.subtitleColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? themeProvider.textColor : themeProvider.subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayGroupCard(_AdminLogDayGroup group, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final formattedDay = DateFormat('MMMM dd, yyyy').format(group.day);
    final count = group.entries.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day Group Header (Web Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262626) : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: themeProvider.borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF4169E1), size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formattedDay,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: themeProvider.textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count ${count == 1 ? 'event' : 'events'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Entries List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: group.entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = group.entries[index];
                return _buildLogCard(log, themeProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(LoginActivity log, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    final color = _colorForLog(log);
    final icon = _iconForLog(log);
    final category = _categoryLabelForLog(log);
    final relativeTime = _formatRelativeTime(log.loggedInAt);
    final exactTime = DateFormat('h:mm a').format(log.loggedInAt);
    final shortId = _shortTicketId(log.workRequestId);

    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showLogDetailsDialog(log),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.borderColor.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Icon + Title + Category Pill + Relative Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: themeProvider.textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              relativeTime,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: themeProvider.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Actor & Exact Time
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 13, color: themeProvider.subtitleColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${log.userName} (${log.role.toUpperCase()})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    exactTime,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: themeProvider.subtitleColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),

              // Row 3: Details text (if present)
              if (log.details != null && log.details!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  log.details!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Row 4: Related Ticket (if present)
              if (shortId.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _openRelatedTicket(log.workRequestId!),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF4169E1).withValues(alpha: isDark ? 0.35 : 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link_rounded, size: 13, color: Color(0xFF4169E1)),
                        const SizedBox(width: 4),
                        Text(
                          shortId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4169E1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 11, color: Color(0xFF4169E1)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
