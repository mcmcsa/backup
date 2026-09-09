import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherLogsWeb extends StatefulWidget {
  const TeacherLogsWeb({super.key});

  @override
  State<TeacherLogsWeb> createState() => _TeacherLogsWebState();
}

class _TeacherLogsWebState extends State<TeacherLogsWeb> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<void>? _changesSub;
  
  List<LoginActivity> _logs = <LoginActivity>[];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';

  // Mapping local colors to AdminStyles
  static const Color _primaryBlue = AdminStyles.primary;
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
    if (title.contains('approve')) return Icons.check_circle_rounded;
    if (title.contains('reject') || title.contains('declin')) {
      return Icons.cancel_rounded;
    }
    if (title.contains('view')) return Icons.visibility_rounded;
    if (title.contains('create') || title.contains('add') || title.contains('submit')) {
      return Icons.add_circle_outline_rounded;
    }
    if (title.contains('update') || title.contains('edit') || title.contains('change')) {
      return Icons.edit_note_rounded;
    }
    if (title.contains('delete') || title.contains('remove')) {
      return Icons.delete_outline_rounded;
    }
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (_isLogout(log)) return const Color(0xFFEF4444);
    if (_isLogin(log)) return const Color(0xFF4169E1);

    final title = log.title.toLowerCase();
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) {
      return const Color(0xFFDC2626);
    }
    if (title.contains('view')) return const Color(0xFF0EA5E9);
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return const Color(0xFF7C3AED);
    if (title.contains('update') || title.contains('edit') || title.contains('change')) {
      return const Color(0xFFF59E0B);
    }
    if (title.contains('delete') || title.contains('remove')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF64748B);
  }

  List<LoginActivity> get _filteredLogs {
    var filtered = List<LoginActivity>.from(_logs);

    if (_selectedFilter == 'Login') {
      filtered = filtered.where(_isLogin).toList();
    } else if (_selectedFilter == 'Logout') {
      filtered = filtered.where(_isLogout).toList();
    } else if (_selectedFilter == 'Actions') {
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
              'Track your recent interactions and system updates.',
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
              hintText: 'Search logs by action, user, or details...',
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

        final filterGroup = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterChip('ALL'),
              const SizedBox(width: 4),
              _buildFilterChip('Login'),
              const SizedBox(width: 4),
              _buildFilterChip('Logout'),
              const SizedBox(width: 4),
              _buildFilterChip('Actions'),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: searchBar),
              const SizedBox(width: 16),
              filterGroup,
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
              child: filterGroup,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = label),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryBlue.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56),
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.history_toggle_off_rounded, size: 44, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No activity logs found',
            style: AdminStyles.bodyStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<LoginActivity> logs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = logs[index];
        final isLogin = _isLogin(log);
        final isLogout = _isLogout(log);
        final color = _colorForLog(log);
        final icon = _iconForLog(log);

        final badgeLabel = isLogin ? 'Login' : (isLogout ? 'Logout' : 'Action');
        final badgeColor = isLogin
            ? const Color(0xFF2563EB)
            : (isLogout ? const Color(0xFFDC2626) : const Color(0xFF475569));
        final badgeBg = isLogin
            ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
            : (isLogout
                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                : const Color(0xFF64748B).withValues(alpha: 0.1));

        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.title,
                      style: AdminStyles.bodyStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            log.userName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (log.details != null && log.details!.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        log.details!,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                      ),
                    ],
                    if (log.workRequestId != null && log.workRequestId!.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Request: ${log.workRequestId}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('MMM dd, yyyy  hh:mm a').format(log.loggedInAt),
                style: AdminStyles.dataStyle(fontSize: 11, color: _subtleText),
              ),
            ],
          ),
        );
      },
    );
  }
}

