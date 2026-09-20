import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../admin/shared/notifications_page.dart';

class LogsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const LogsPage({super.key, this.scaffoldKey});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<void>? _changesSub;
  String _selectedFilter = 'ALL';
  List<LoginActivity> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadLogs();
    _changesSub = LoginActivityService.changes.listen((_) {
      if (mounted) _loadLogs();
    });
  }

  Future<void> _loadLogs() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await LoginActivityService.fetchUserLogs(user.id);
      data.sort((a, b) => b.loggedInAt.compareTo(a.loggedInAt));
      if (mounted) {
        setState(() {
          _logs = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  List<LoginActivity> get _filteredLogs {
    List<LoginActivity> filtered = List<LoginActivity>.from(_logs);

    if (_selectedFilter == 'Login') {
      filtered = filtered.where(_isLogin).toList();
    } else if (_selectedFilter == 'Logout') {
      filtered = filtered.where(_isLogout).toList();
    } else if (_selectedFilter == 'Actions') {
      filtered = filtered.where(_isAction).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((l) =>
        l.title.toLowerCase().contains(query) ||
        (l.details?.toLowerCase().contains(query) ?? false) ||
        l.eventType.toLowerCase().contains(query)
      ).toList();
    }
    return filtered;
  }

  IconData _iconForLog(LoginActivity log) {
    if (_isLogout(log)) return Icons.logout_rounded;
    if (_isLogin(log)) return Icons.login_rounded;
    final title = log.title.toLowerCase();
    if (title.contains('approve')) return Icons.check_circle_rounded;
    if (title.contains('reject') || title.contains('declin')) return Icons.cancel_rounded;
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return Icons.add_circle_outline_rounded;
    if (title.contains('update') || title.contains('edit')) return Icons.edit_note_rounded;
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (_isLogout(log)) return const Color(0xFFEF4444);
    if (_isLogin(log)) return const Color(0xFF4169E1);
    final title = log.title.toLowerCase();
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) return const Color(0xFFDC2626);
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return const Color(0xFF7C3AED);
    return const Color(0xFF00BFA5);
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: '',
        primaryColor: themeProvider.primaryColor,
        onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
        onNotificationPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final searchBar = TextField(
                  controller: _searchController,
                  style: TextStyle(color: themeProvider.textColor, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13.5,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: Colors.grey.shade400,
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: themeProvider.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                );

                final filterGroup = Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: themeProvider.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabChip('ALL', themeProvider),
                      const SizedBox(width: 4),
                      _buildTabChip('Login', themeProvider),
                      const SizedBox(width: 4),
                      _buildTabChip('Logout', themeProvider),
                      const SizedBox(width: 4),
                      _buildTabChip('Actions', themeProvider),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: searchBar),
                      const SizedBox(width: 14),
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
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 20, color: themeProvider.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Activity Logs',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_filteredLogs.length} entries',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    child: _filteredLogs.isEmpty
                        ? ListView(
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.history_toggle_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No activity logs found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: themeProvider.textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _filteredLogs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final log = _filteredLogs[index];
                              final isLogin = _isLogin(log);
                              final isLogout = _isLogout(log);
                              final color = _colorForLog(log);
                              final icon = _iconForLog(log);
                              final timeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(log.loggedInAt);

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
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: themeProvider.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: themeProvider.borderColor),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, size: 20, color: color),
                                    ),
                                    const SizedBox(width: 12),
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
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: themeProvider.textColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badgeBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  badgeLabel,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            log.details ?? log.eventType,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: themeProvider.subtitleColor,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = label),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? themeProvider.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: themeProvider.primaryColor.withValues(alpha: 0.28),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (themeProvider.isDarkMode ? Colors.grey.shade300 : const Color(0xFF64748B)),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
