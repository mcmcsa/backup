import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../admin/shared/admin_styles.dart';

class MaintenanceLogsWeb extends StatefulWidget {
  const MaintenanceLogsWeb({super.key});

  @override
  State<MaintenanceLogsWeb> createState() => _MaintenanceLogsWebState();
}

class _MaintenanceLogsWebState extends State<MaintenanceLogsWeb> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<void>? _changesSub;
  
  List<LoginActivity> _logs = <LoginActivity>[];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  // Design Tokens
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;
  static const Color _cardBg = AdminStyles.surface;
  static const Color _borderColor = AdminStyles.border;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _changesSub = LoginActivityService.changes.listen((_) {
      if (mounted) _loadLogs();
    });
  }

  Future<void> _loadLogs() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await LoginActivityService.fetchUserLogs(user.id);
      if (!mounted) return;
      data.sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
      setState(() {
        _logs = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _logs = <LoginActivity>[];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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

  IconData _iconForLog(LoginActivity log) {
    if (_isLogout(log)) return Icons.logout_rounded;
    if (_isLogin(log)) return Icons.login_rounded;

    final title = log.title.toLowerCase();
    if (title.contains('accept')) return Icons.task_alt_rounded;
    if (title.contains('inspect') || title.contains('pre-inspection')) return Icons.assignment_outlined;
    if (title.contains('repair') || title.contains('post-repair')) return Icons.build_outlined;
    if (title.contains('approve')) return Icons.check_circle_rounded;
    if (title.contains('reject') || title.contains('declin')) return Icons.cancel_rounded;
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return Icons.add_circle_outline_rounded;
    if (title.contains('update') || title.contains('edit')) return Icons.edit_note_rounded;
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (_isLogout(log)) return const Color(0xFFEF4444);
    if (_isLogin(log)) return _primaryBlue;

    final title = log.title.toLowerCase();
    if (title.contains('accept')) return const Color(0xFF10B981);
    if (title.contains('inspect') || title.contains('pre-inspection')) return const Color(0xFF0EA5E9);
    if (title.contains('repair') || title.contains('post-repair')) return const Color(0xFF6366F1);
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) return const Color(0xFFDC2626);
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return const Color(0xFF7C3AED);
    return const Color(0xFF00BFA5);
  }

  String _filterTagForLog(LoginActivity log) {
    if (_isLogout(log)) return 'LOGOUT';
    if (_isLogin(log)) return 'LOGIN';
    return 'ACTION';
  }

  List<LoginActivity> get _filteredLogs {
    List<LoginActivity> filtered = List<LoginActivity>.from(_logs);

    if (_selectedFilter == 'LOGIN') {
      filtered = filtered.where(_isLogin).toList();
    } else if (_selectedFilter == 'LOGOUT') {
      filtered = filtered.where(_isLogout).toList();
    } else if (_selectedFilter == 'ACTIONS') {
      filtered = filtered.where(_isAction).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((log) {
        return log.title.toLowerCase().contains(query) ||
               log.userName.toLowerCase().contains(query) ||
               (log.details?.toLowerCase().contains(query) ?? false) ||
               (log.workRequestId?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrow = screenWidth < 500;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 14 : 32,
          vertical: isNarrow ? 20 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Logs',
              style: AdminStyles.headingStyle(
                fontSize: isNarrow ? 22 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your recent maintenance actions, inspection submissions, and login events.',
              style: AdminStyles.bodyStyle(
                fontSize: isNarrow ? 13 : 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isNarrow ? 16 : 24),
            _buildSearchAndFilter(),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: _primaryBlue))
            else if (filtered.isEmpty)
              _buildEmptyState()
            else
              _buildLogsList(filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final searchBar = Container(
          height: 46,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: AdminStyles.bodyStyle(fontSize: 14, color: _darkText),
            decoration: InputDecoration(
              hintText: 'Search logs by action, details, or room...',
              hintStyle: AdminStyles.bodyStyle(color: const Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
          ),
        );

        final filterRow = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterChip('ALL'),
              const SizedBox(width: 4),
              _buildFilterChip('LOGIN'),
              const SizedBox(width: 4),
              _buildFilterChip('LOGOUT'),
              const SizedBox(width: 4),
              _buildFilterChip('ACTIONS'),
            ],
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: searchBar),
              const SizedBox(width: 16),
              filterRow,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchBar,
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: filterRow,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : _subtleText,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Activity Logs Found',
            style: AdminStyles.headingStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _searchController.text.isNotEmpty
                ? 'Try adjusting your search criteria.'
                : 'Your actions and session logs will appear here.',
            style: AdminStyles.bodyStyle(fontSize: 13, color: _subtleText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<LoginActivity> logs) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logs.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: _borderColor),
        itemBuilder: (context, index) {
          final log = logs[index];
          final color = _colorForLog(log);
          final icon = _iconForLog(log);
          final tag = _filterTagForLog(log);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.title,
                              style: AdminStyles.bodyStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _darkText,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (log.details != null && log.details!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          log.details!,
                          style: AdminStyles.bodyStyle(
                            fontSize: 13,
                            color: _subtleText,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMMM d, yyyy • h:mm a').format(log.loggedInAt),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
