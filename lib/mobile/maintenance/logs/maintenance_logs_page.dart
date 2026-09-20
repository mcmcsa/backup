import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/login_activity_service.dart';
import '../../admin/shared/notifications_page.dart';

class MaintenanceLogsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const MaintenanceLogsPage({super.key, this.scaffoldKey});

  @override
  State<MaintenanceLogsPage> createState() => _MaintenanceLogsPageState();
}

class _MaintenanceLogsPageState extends State<MaintenanceLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<void>? _changesSub;
  String _selectedFilter = 'ALL';
  List<LoginActivity> _logs = [];
  bool _isLoading = true;

  static const Color _primaryBlue = Color(0xFF2563EB);

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
    if (title.contains('accept')) return Icons.task_alt_rounded;
    if (title.contains('inspect')) return Icons.assignment_outlined;
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (_isLogout(log)) return const Color(0xFFEF4444);
    if (_isLogin(log)) return const Color(0xFF2563EB);
    final title = log.title.toLowerCase();
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) return const Color(0xFFDC2626);
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return const Color(0xFF7C3AED);
    if (title.contains('accept')) return const Color(0xFF10B981);
    return const Color(0xFF0EA5E9);
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
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Activity Logs',
          style: TextStyle(
            color: themeProvider.appBarTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: themeProvider.appBarIconColor),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: themeProvider.appBarIconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsPage()),
              );
            },
          ),
        ],
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
                      borderSide: const BorderSide(color: _primaryBlue),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Activity History',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.subtitleColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_filteredLogs.length} entries',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: _primaryBlue,
                          onRefresh: _loadLogs,
                          child: _filteredLogs.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.4,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.history_toggle_off_rounded,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No activity logs found',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  itemCount: _filteredLogs.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final log = _filteredLogs[index];
                                    final iconColor = _colorForLog(log);
                                    final icon = _iconForLog(log);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: themeProvider.cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: themeProvider.borderColor),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: iconColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(icon, color: iconColor, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  log.title,
                                                  style: TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: themeProvider.textColor,
                                                  ),
                                                ),
                                                if (log.details != null && log.details!.isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    log.details!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: themeProvider.subtitleColor,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time_rounded,
                                                      size: 11,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      DateFormat('MMM d, yyyy • h:mm a').format(log.loggedInAt),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade400,
                                                      ),
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
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryBlue
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : themeProvider.subtitleColor,
          ),
        ),
      ),
    );
  }
}
