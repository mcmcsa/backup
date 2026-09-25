import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_date_range_dialog.dart';

import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../admin_nav_controller.dart';
import '../shared/admin_styles.dart';
import '../tickets/admin_work_process_web.dart';

class AdminLogsWeb extends StatefulWidget {
  const AdminLogsWeb({super.key});

  @override
  State<AdminLogsWeb> createState() => _AdminLogsWebState();
}

class _AdminLogsWebState extends State<AdminLogsWeb> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<void>? _changesSub;

  List<LoginActivity> _logs = <LoginActivity>[];
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Filters
  String _selectedCategory = 'ALL'; // ALL, Actions, Logins, Logouts, Requests
  String _selectedDatePreset = 'All Time'; // All Time, Today, Past 7 Days, Past 30 Days, Custom
  DateTimeRange? _customDateRange;

  // View Mode: 'auto', 'table', 'timeline', 'cards'
  String _viewMode = 'auto';

  // Pagination
  int _currentPage = 0;
  int _pageSize = 15;

  // Cache for work requests to allow instant ticket lookup
  List<WorkRequest>? _cachedRequests;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _preloadWorkRequests();
    _changesSub = LoginActivityService.changes.listen((_) {
      if (mounted) _loadLogs(silent: true);
    });
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

  @override
  void dispose() {
    _changesSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Categorization & Utility Helpers
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
  // Filtered & Paginated Logs
  // ─────────────────────────────────────────────────────────────

  List<LoginActivity> get _filteredLogs {
    var list = List<LoginActivity>.from(_logs);

    // Category filter
    if (_selectedCategory == 'Actions') {
      list = list.where(_isAction).toList();
    } else if (_selectedCategory == 'Logins') {
      list = list.where(_isLogin).toList();
    } else if (_selectedCategory == 'Logouts') {
      list = list.where(_isLogout).toList();
    } else if (_selectedCategory == 'Requests') {
      list = list.where((l) => l.workRequestId != null && l.workRequestId!.trim().isNotEmpty).toList();
    }

    // Date filter
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
      final start = _customDateRange!.start;
      final end = _customDateRange!.end.add(const Duration(days: 1));
      list = list.where((l) => l.loggedInAt.isAfter(start) && l.loggedInAt.isBefore(end)).toList();
    }

    // Search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((log) {
        final title = log.title.toLowerCase();
        final user = log.userName.toLowerCase();
        final role = log.role.toLowerCase();
        final details = (log.details ?? '').toLowerCase();
        final reqId = (log.workRequestId ?? '').toLowerCase();
        final shortId = _shortTicketId(log.workRequestId).toLowerCase();
        return title.contains(query) ||
            user.contains(query) ||
            role.contains(query) ||
            details.contains(query) ||
            reqId.contains(query) ||
            shortId.contains(query);
      }).toList();
    }

    return list;
  }

  List<LoginActivity> get _paginatedLogs {
    final filtered = _filteredLogs;
    final startIndex = _currentPage * _pageSize;
    if (startIndex >= filtered.length) return [];
    final endIndex = min(startIndex + _pageSize, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    final total = _filteredLogs.length;
    if (total == 0) return 1;
    return (total / _pageSize).ceil();
  }

  // ─────────────────────────────────────────────────────────────
  // Ticket Navigation, Dialog & Export
  // ─────────────────────────────────────────────────────────────

  Future<void> _openRelatedTicket(String workRequestId) async {
    final messenger = ScaffoldMessenger.of(context);

    WorkRequest? targetRequest;
    if (_cachedRequests != null) {
      targetRequest = _cachedRequests!.where((r) {
        return r.id.toLowerCase() == workRequestId.toLowerCase();
      }).firstOrNull;
    }

    if (targetRequest == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Loading work request details...'),
          duration: Duration(seconds: 1),
        ),
      );
      try {
        final fetched = await WorkRequestService.fetchAll();
        if (mounted) {
          setState(() => _cachedRequests = fetched);
        }
        targetRequest = fetched.where((r) {
          return r.id.toLowerCase() == workRequestId.toLowerCase();
        }).firstOrNull;
      } catch (_) {}
    }

    if (!mounted) return;

    if (targetRequest != null) {
      final controller = AdminNavController.of(context);
      if (controller != null) {
        controller.openWorkProcess(targetRequest);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminWorkProcessWeb(request: targetRequest!),
          ),
        );
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ticket #$workRequestId could not be found or may have been archived.'),
          backgroundColor: AdminStyles.warning,
        ),
      );
    }
  }

  void _showLogDetailsDialog(LoginActivity log) {
    final color = _colorForLog(log);
    final icon = _iconForLog(log);
    final category = _categoryLabelForLog(log);
    final formattedDate = DateFormat('MMMM dd, yyyy').format(log.loggedInAt);
    final formattedTime = DateFormat('hh:mm:ss a').format(log.loggedInAt);
    final relativeTime = _formatRelativeTime(log.loggedInAt);

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;
    final dialogWidth = isSmall ? screenWidth - 28 : 560.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          padding: EdgeInsets.all(isSmall ? 18 : 26),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
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
                                  color: color.withValues(alpha: 0.12),
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
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            log.title,
                            style: AdminStyles.headingStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AdminStyles.border),
                const SizedBox(height: 16),

                // Metadata Cards Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminStyles.border),
                  ),
                  child: Column(
                    children: [
                      _buildModalMetaRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Performed By',
                        value: '${log.userName} (${log.role.toUpperCase()})',
                      ),
                      const SizedBox(height: 10),
                      _buildModalMetaRow(
                        icon: Icons.access_time_rounded,
                        label: 'Timestamp (PHT)',
                        value: '$formattedDate at $formattedTime ($relativeTime)',
                      ),
                      if (log.userId.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildModalMetaRow(
                          icon: Icons.fingerprint_rounded,
                          label: 'User ID',
                          value: log.userId,
                          isMonospace: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
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
                    style: AdminStyles.bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminStyles.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminStyles.border),
                    ),
                    child: Text(
                      log.details!,
                      style: AdminStyles.bodyStyle(
                        fontSize: 13,
                        color: AdminStyles.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],

                // Related Work Request
                if (log.workRequestId != null && log.workRequestId!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'RELATED WORK REQUEST',
                    style: AdminStyles.bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminStyles.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminStyles.primaryLight.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_num_rounded, size: 18, color: AdminStyles.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.workRequestId!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AdminStyles.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 15, color: AdminStyles.primary),
                          tooltip: 'Copy Request UUID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: log.workRequestId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Request ID copied!')),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _openRelatedTicket(log.workRequestId!);
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 13),
                          label: const Text('View Ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminStyles.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Bottom Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final summary = '''
Log: ${log.title}
Category: $category
User: ${log.userName} (${log.role})
Time: $formattedDate $formattedTime
Details: ${log.details ?? 'N/A'}
Ticket ID: ${log.workRequestId ?? 'N/A'}
''';
                        Clipboard.setData(ClipboardData(text: summary.trim()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Full log summary copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_all_rounded, size: 15),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminStyles.textSecondary,
                        side: const BorderSide(color: AdminStyles.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
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
    bool isMonospace = false,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
              color: AdminStyles.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ],
    );
  }

  void _exportCSV() {
    final filtered = _filteredLogs;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to export with current filters.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Timestamp,Event,Category,User Name,Role,Details,Work Request ID');
    for (final log in filtered) {
      final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.loggedInAt);
      final title = '"${log.title.replaceAll('"', '""')}"';
      final category = _categoryLabelForLog(log);
      final user = '"${log.userName.replaceAll('"', '""')}"';
      final role = log.role;
      final details = '"${(log.details ?? '').replaceAll('"', '""')}"';
      final reqId = log.workRequestId ?? '';
      buffer.writeln('$ts,$title,$category,$user,$role,$details,$reqId');
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 650;
    final dialogWidth = isSmall ? screenWidth - 28 : 600.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.file_download_outlined, color: AdminStyles.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Export Activity Logs (${filtered.length})',
                style: AdminStyles.headingStyle(fontSize: isSmall ? 16 : 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          height: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CSV format ready. Click "Copy to Clipboard" to paste into Excel or Google Sheets:',
                style: AdminStyles.bodyStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminStyles.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      buffer.toString(),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV content copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminStyles.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build Methods: 100% Fit & True Device Responsiveness
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminStyles.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;
          final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1000;

          return SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : (isTablet ? 18 : 28),
              isMobile ? 16 : 24,
              isMobile ? 12 : (isTablet ? 18 : 28),
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Header Row (Adaptive)
                _buildHeader(isMobile, isTablet, constraints.maxWidth),
                SizedBox(height: isMobile ? 14 : 20),

                // 2. Summary Metric Stat Cards (Adaptive Grid)
                _buildStatCards(constraints.maxWidth, isMobile, isTablet),
                SizedBox(height: isMobile ? 14 : 20),

                // 3. Search, Category, and Date Filters (Adaptive)
                _buildToolbar(isMobile, isTablet, constraints.maxWidth),
                SizedBox(height: isMobile ? 14 : 18),

                // 4. Main Logs Content (Mobile Cards, Fit Table, or Timeline)
                if (_isLoading)
                  _buildLoadingState()
                else if (_filteredLogs.isEmpty)
                  _buildEmptyState()
                else
                  _buildLogsContent(constraints.maxWidth, isMobile),

                // 5. Pagination
                if (!_isLoading && _filteredLogs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPaginationControls(isMobile),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header (Fully Adaptive) ─────────────────────────────────

  Widget _buildHeader(bool isMobile, bool isTablet, double maxWidth) {
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Activity Logs',
          style: AdminStyles.headingStyle(
            fontSize: isMobile ? 20 : 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        // Real-time live status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'LIVE FEED',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF047857),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final subtitleWidget = Text(
      'Live admin activity from logins, room updates, and work request processing.',
      style: AdminStyles.bodyStyle(
        fontSize: isMobile ? 12.5 : 13.5,
        fontWeight: FontWeight.w500,
      ),
    );

    final currentEffectiveMode = _getEffectiveViewMode(isMobile);

    final actionControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Mode Switcher
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminStyles.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewToggleBtn(
                icon: isMobile ? Icons.view_agenda_rounded : Icons.table_chart_rounded,
                label: isMobile ? 'Cards' : 'Table',
                isActive: currentEffectiveMode == (isMobile ? 'cards' : 'table'),
                onTap: () => setState(() => _viewMode = isMobile ? 'cards' : 'table'),
              ),
              _buildViewToggleBtn(
                icon: Icons.timeline_rounded,
                label: 'Timeline',
                isActive: currentEffectiveMode == 'timeline',
                onTap: () => setState(() => _viewMode = 'timeline'),
              ),
              if (isMobile)
                _buildViewToggleBtn(
                  icon: Icons.table_chart_rounded,
                  label: 'Table',
                  isActive: currentEffectiveMode == 'table',
                  onTap: () => setState(() => _viewMode = 'table'),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Export CSV
        ElevatedButton.icon(
          onPressed: _exportCSV,
          icon: const Icon(Icons.download_rounded, size: 15),
          label: Text(isMobile ? 'CSV' : 'Export'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AdminStyles.textPrimary,
            elevation: 0,
            side: const BorderSide(color: AdminStyles.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        // Refresh Button
        IconButton(
          onPressed: _isRefreshing ? null : () => _loadLogs(silent: true),
          icon: _isRefreshing
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AdminStyles.primary),
                )
              : const Icon(Icons.refresh_rounded, size: 18, color: AdminStyles.textSecondary),
          tooltip: 'Refresh Logs',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AdminStyles.border),
            ),
          ),
        ),
      ],
    );

    // On mobile or narrow widths, stack controls below title
    if (maxWidth < 850) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 4),
          subtitleWidget,
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: actionControls,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 4),
              subtitleWidget,
            ],
          ),
        ),
        const SizedBox(width: 12),
        actionControls,
      ],
    );
  }

  String _getEffectiveViewMode(bool isMobile) {
    if (_viewMode == 'auto') {
      return isMobile ? 'cards' : 'table';
    }
    return _viewMode;
  }

  Widget _buildViewToggleBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AdminStyles.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : AdminStyles.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? Colors.white : AdminStyles.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat Summary Cards (Responsive Auto-Fit) ────────────────

  Widget _buildStatCards(double maxWidth, bool isMobile, bool isTablet) {
    final totalCount = _logs.length;
    final todayCount = _logs.where((l) => _isToday(l.loggedInAt)).length;
    final actionsCount = _logs.where(_isAction).length;
    final sessionCount = _logs.where((l) => _isLogin(l) || _isLogout(l)).length;

    final cards = [
      _StatCardItem(
        title: 'Total Records',
        value: totalCount.toString(),
        icon: Icons.receipt_long_rounded,
        accentColor: AdminStyles.primary,
        isCompact: isMobile || maxWidth < 1000,
        isSelected: _selectedCategory == 'ALL' && _selectedDatePreset == 'All Time',
        onTap: () {
          setState(() {
            _selectedCategory = 'ALL';
            _selectedDatePreset = 'All Time';
            _currentPage = 0;
          });
        },
      ),
      _StatCardItem(
        title: "Today's Activity",
        value: todayCount.toString(),
        icon: Icons.today_rounded,
        accentColor: const Color(0xFF0284C7),
        isCompact: isMobile || maxWidth < 1000,
        isSelected: _selectedDatePreset == 'Today',
        onTap: () {
          setState(() {
            _selectedDatePreset = 'Today';
            _currentPage = 0;
          });
        },
      ),
      _StatCardItem(
        title: 'Admin Actions',
        value: actionsCount.toString(),
        icon: Icons.bolt_rounded,
        accentColor: const Color(0xFFD97706),
        isCompact: isMobile || maxWidth < 1000,
        isSelected: _selectedCategory == 'Actions',
        onTap: () {
          setState(() {
            _selectedCategory = 'Actions';
            _currentPage = 0;
          });
        },
      ),
      _StatCardItem(
        title: 'Login Sessions',
        value: sessionCount.toString(),
        icon: Icons.login_rounded,
        accentColor: const Color(0xFF10B981),
        isCompact: isMobile || maxWidth < 1000,
        isSelected: _selectedCategory == 'Logins',
        onTap: () {
          setState(() {
            _selectedCategory = 'Logins';
            _currentPage = 0;
          });
        },
      ),
    ];

    // If screen width is below 920px, use 2x2 grid so cards never get squashed or cut off
    if (maxWidth < 920) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 8),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    // Wide screen: 4 cards in one row, each expanded proportionally
    return Row(
      children: cards
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Toolbar (Search, Categories, Date Range) ────────────────

  Widget _buildToolbar(bool isMobile, bool isTablet, double maxWidth) {
    final searchBar = Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() => _currentPage = 0),
        style: AdminStyles.bodyStyle(
          fontSize: 13,
          color: AdminStyles.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search logs by action, user, details, or ticket ID...',
          hintStyle: AdminStyles.bodyStyle(
            color: AdminStyles.textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AdminStyles.textMuted,
            size: 18,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AdminStyles.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _currentPage = 0);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
      ),
    );

    // Category chips
    final categoryChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('ALL', 'All'),
          const SizedBox(width: 5),
          _buildFilterChip('Actions', 'Actions'),
          const SizedBox(width: 5),
          _buildFilterChip('Logins', 'Logins'),
          const SizedBox(width: 5),
          _buildFilterChip('Logouts', 'Logouts'),
          const SizedBox(width: 5),
          _buildFilterChip('Requests', 'Tickets'),
        ],
      ),
    );

    // Date range dropdown
    final dateSelector = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDatePreset,
          icon: const Icon(Icons.calendar_today_rounded, size: 15, color: AdminStyles.textSecondary),
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AdminStyles.textPrimary,
          ),
          items: const [
            DropdownMenuItem(value: 'All Time', child: Text('All Time')),
            DropdownMenuItem(value: 'Today', child: Text('Today')),
            DropdownMenuItem(value: 'Past 7 Days', child: Text('Past 7 Days')),
            DropdownMenuItem(value: 'Past 30 Days', child: Text('Past 30 Days')),
            DropdownMenuItem(value: 'Custom', child: Text('Custom Range...')),
          ],
          onChanged: (val) async {
            if (val == null) return;
            if (val == 'Custom') {
              final range = await showAppDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialStartDate: _customDateRange?.start ?? DateTime.now().subtract(const Duration(days: 7)),
                initialEndDate: _customDateRange?.end ?? DateTime.now(),
              );
              if (range != null) {
                setState(() {
                  _selectedDatePreset = 'Custom';
                  _customDateRange = range;
                  _currentPage = 0;
                });
              }
            } else {
              setState(() {
                _selectedDatePreset = val;
                _customDateRange = null;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );

    if (maxWidth < 700) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchBar,
          const SizedBox(height: 8),
          categoryChips,
          const SizedBox(height: 8),
          dateSelector,
        ],
      );
    }

    if (maxWidth < 1050) {
      return Column(
        children: [
          searchBar,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: categoryChips),
              const SizedBox(width: 8),
              dateSelector,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchBar),
        const SizedBox(width: 10),
        categoryChips,
        const SizedBox(width: 10),
        dateSelector,
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = key;
            _currentPage = 0;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected ? AdminStyles.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AdminStyles.primary : AdminStyles.border,
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
      ),
    );
  }

  // ── Presentation Router ─────────────────────────────────────

  Widget _buildLogsContent(double maxWidth, bool isMobile) {
    final mode = _getEffectiveViewMode(isMobile);

    if (mode == 'timeline') {
      return _buildTimelineView(isMobile);
    } else if (mode == 'cards') {
      return _buildMobileCardsView();
    } else {
      return _buildTableView(maxWidth);
    }
  }

  // ── 100% Fit Table View (Proportional Flexes, No Slicing) ──

  Widget _buildTableView(double maxWidth) {
    final items = _paginatedLogs;

    // Table container fits 100% of the screen card width
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Table Header Bar: Total flex = 3 + 4 + 3 + 5 + 2 + 1 = 18
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _th('TIMESTAMP')),
                  Expanded(flex: 4, child: _th('ACTION / EVENT')),
                  Expanded(flex: 3, child: _th('PERFORMED BY')),
                  Expanded(flex: 5, child: _th('DETAILS / REMARKS')),
                  Expanded(flex: 2, child: _th('RELATED TICKET', alignment: Alignment.center)),
                  Expanded(flex: 1, child: _th('ACTION', alignment: Alignment.center)),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminStyles.border),

            // Table Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final log = items[index];
                return _buildTableRow(log, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String title, {Alignment alignment = Alignment.centerLeft}) {
    return Align(
      alignment: alignment,
      child: Text(
        title,
        style: AdminStyles.bodyStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableRow(LoginActivity log, int index) {
    final color = _colorForLog(log);
    final icon = _iconForLog(log);
    final category = _categoryLabelForLog(log);
    final relativeTime = _formatRelativeTime(log.loggedInAt);
    final exactTime = DateFormat('MMM d, yyyy  h:mm a').format(log.loggedInAt);
    final shortId = _shortTicketId(log.workRequestId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLogDetailsDialog(log),
        hoverColor: const Color(0xFFF0FDFA).withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // 1. Timestamp: flex 3
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exactTime,
                      style: AdminStyles.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AdminStyles.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        relativeTime,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Action / Event Title with Icon & Category Badge: flex 4
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.title,
                            style: AdminStyles.bodyStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AdminStyles.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Performed by: flex 3
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.userName,
                      style: AdminStyles.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.role.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Details / Remarks: flex 5 with 12px right padding to prevent collision
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    log.details ?? '—',
                    style: TextStyle(
                      fontSize: 12,
                      color: log.details != null ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 5. Related Ticket: flex 2, compact chip centered
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.center,
                  child: shortId.isNotEmpty
                      ? InkWell(
                          onTap: () => _openRelatedTicket(log.workRequestId!),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AdminStyles.primaryLight.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link_rounded, size: 12, color: AdminStyles.primary),
                                const SizedBox(width: 3),
                                Text(
                                  shortId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AdminStyles.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const Text(
                          '—',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                ),
              ),

              // 6. Action Button: flex 1, centered eye icon
              Expanded(
                flex: 1,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminStyles.primary),
                    tooltip: 'Inspect Log Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _showLogDetailsDialog(log),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile-Optimized Activity Cards (Native Mobile UX) ──────

  Widget _buildMobileCardsView() {
    final items = _paginatedLogs;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = items[index];
        final color = _colorForLog(log);
        final icon = _iconForLog(log);
        final category = _categoryLabelForLog(log);
        final relativeTime = _formatRelativeTime(log.loggedInAt);
        final exactTime = DateFormat('MMM d, yyyy • h:mm a').format(log.loggedInAt);
        final shortId = _shortTicketId(log.workRequestId);

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 0,
          child: InkWell(
            onTap: () => _showLogDetailsDialog(log),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminStyles.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x050F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Icon + Title + Category + Relative Time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.title,
                              style: AdminStyles.bodyStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AdminStyles.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        relativeTime,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Actor & Timestamp line
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${log.userName} (${log.role.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        exactTime,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),

                  // Details text
                  if (log.details != null && log.details!.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminStyles.border),
                      ),
                      child: Text(
                        log.details!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],

                  // Footer: Ticket button + Inspect button
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (shortId.isNotEmpty)
                        InkWell(
                          onTap: () => _openRelatedTicket(log.workRequestId!),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AdminStyles.primaryLight.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link_rounded, size: 12, color: AdminStyles.primary),
                                const SizedBox(width: 3),
                                Text(
                                  shortId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AdminStyles.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showLogDetailsDialog(log),
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('Inspect'),
                        style: TextButton.styleFrom(
                          foregroundColor: AdminStyles.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
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
  }

  // ── Timeline View ───────────────────────────────────────────

  Widget _buildTimelineView(bool isMobile) {
    final items = _paginatedLogs;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final log = items[index];
        final color = _colorForLog(log);
        final icon = _iconForLog(log);
        final category = _categoryLabelForLog(log);
        final relativeTime = _formatRelativeTime(log.loggedInAt);
        final exactTime = DateFormat('MMM dd, yyyy • hh:mm a').format(log.loggedInAt);
        final shortId = _shortTicketId(log.workRequestId);
        final isLast = index == items.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Node & Line
              SizedBox(
                width: isMobile ? 32 : 44,
                child: Column(
                  children: [
                    Container(
                      width: isMobile ? 24 : 30,
                      height: isMobile ? 24 : 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Icon(icon, color: color, size: isMobile ? 12 : 15),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: isMobile ? 6 : 10),

              // Timeline Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: EdgeInsets.all(isMobile ? 11 : 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AdminStyles.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x050F172A),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    log.title,
                                    style: AdminStyles.bodyStyle(
                                      fontSize: isMobile ? 12.5 : 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AdminStyles.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            relativeTime,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // User and Exact Time
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${log.userName} • ${log.role.toUpperCase()} • $exactTime',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Details
                      if (log.details != null && log.details!.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AdminStyles.border),
                          ),
                          child: Text(
                            log.details!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],

                      // Footer with Ticket chip and inspect button
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (shortId.isNotEmpty)
                            InkWell(
                              onTap: () => _openRelatedTicket(log.workRequestId!),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDFA),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AdminStyles.primaryLight.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link_rounded, size: 12, color: AdminStyles.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      shortId,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AdminStyles.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _showLogDetailsDialog(log),
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('Inspect'),
                            style: TextButton.styleFrom(
                              foregroundColor: AdminStyles.primary,
                              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Pagination Controls (Adaptive) ──────────────────────────

  Widget _buildPaginationControls(bool isMobile) {
    final filtered = _filteredLogs;
    final total = filtered.length;
    final startIndex = _currentPage * _pageSize + 1;
    final endIndex = min((_currentPage + 1) * _pageSize, total);

    if (isMobile) {
      return Column(
        children: [
          Text(
            'Showing $startIndex–$endIndex of $total records',
            style: AdminStyles.bodyStyle(
              fontSize: 12,
              color: AdminStyles.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AdminStyles.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: AdminStyles.bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminStyles.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: _currentPage < _totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AdminStyles.border),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $startIndex–$endIndex of $total records',
          style: AdminStyles.bodyStyle(
            fontSize: 12.5,
            color: AdminStyles.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            // Page size selector
            Text(
              'Per page: ',
              style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _pageSize,
                style: AdminStyles.bodyStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminStyles.textPrimary),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 15, child: Text('15')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _pageSize = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            // Prev page
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AdminStyles.border),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Page ${_currentPage + 1} of $_totalPages',
              style: AdminStyles.bodyStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AdminStyles.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            // Next page
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              onPressed: _currentPage < _totalPages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AdminStyles.border),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── States ──────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AdminStyles.primary),
          SizedBox(height: 16),
          Text(
            'Loading activity logs...',
            style: TextStyle(color: AdminStyles.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminStyles.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              size: 28,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No activity logs found',
            style: AdminStyles.headingStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try clearing your search query or adjusting the date and category filters.',
            style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedCategory = 'ALL';
                _selectedDatePreset = 'All Time';
                _customDateRange = null;
                _currentPage = 0;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminStyles.primary,
              side: const BorderSide(color: AdminStyles.primaryLight),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset All Filters'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stat Card Helper Widget (Adaptive Compact Mode)
// ─────────────────────────────────────────────────────────────

class _StatCardItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _StatCardItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    this.isCompact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 11 : 16,
            vertical: isCompact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor : AdminStyles.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : const Color(0x050F172A),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isCompact ? 32 : 38,
                height: isCompact ? 32 : 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
                ),
                child: Icon(icon, color: accentColor, size: isCompact ? 16 : 19),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AdminStyles.bodyStyle(
                        fontSize: isCompact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                        color: AdminStyles.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AdminStyles.headingStyle(
                        fontSize: isCompact ? 17 : 20,
                        fontWeight: FontWeight.w800,
                        color: AdminStyles.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
