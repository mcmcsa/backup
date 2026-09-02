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
  String _selectedTab = 'All';
  List<LoginActivity> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadLogs();
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

  List<LoginActivity> get _filteredLogs {
    List<LoginActivity> filtered = _logs;

    if (_selectedTab == 'Account') {
      filtered = filtered.where((l) => l.eventType == 'login' || l.eventType == 'logout').toList();
    } else if (_selectedTab == 'Reports') {
      filtered = filtered.where((l) => l.title.toLowerCase().contains('request') || l.title.toLowerCase().contains('report')).toList();
    } else if (_selectedTab == 'Settings') {
      filtered = filtered.where((l) => l.title.toLowerCase().contains('setting') || l.title.toLowerCase().contains('profile')).toList();
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
    if (log.eventType == 'login') return Icons.login_rounded;
    final title = log.title.toLowerCase();
    if (title.contains('approve')) return Icons.check_circle_rounded;
    if (title.contains('reject') || title.contains('declin')) return Icons.cancel_rounded;
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return Icons.add_circle_outline_rounded;
    if (title.contains('update') || title.contains('edit')) return Icons.edit_note_rounded;
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (log.eventType == 'login') return const Color(0xFF4169E1);
    final title = log.title.toLowerCase();
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) return const Color(0xFFDC2626);
    if (title.contains('create') || title.contains('add') || title.contains('submit')) return const Color(0xFF7C3AED);
    return const Color(0xFF00BFA5);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: 'Teacher',
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
          // Search Bar
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: 'Search activity logs...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey.shade300),
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
          ),

          // Tab Filters
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip('All', themeProvider),
                  const SizedBox(width: 8),
                  _buildTabChip('Account', themeProvider),
                  const SizedBox(width: 8),
                  _buildTabChip('Reports', themeProvider),
                  const SizedBox(width: 8),
                  _buildTabChip('Settings', themeProvider),
                ],
              ),
            ),
          ),

          // Logs Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 20, color: themeProvider.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
          ),

          // Logs List
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
                                    children: [
                                      Icon(Icons.history, size: 48, color: themeProvider.subtitleColor),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No activity logs yet',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: themeProvider.subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _filteredLogs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final log = _filteredLogs[index];
                              final color = _colorForLog(log);
                              final icon = _iconForLog(log);
                              final timeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(log.loggedInAt);

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
                                          Text(
                                            log.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: themeProvider.textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
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
    final isSelected = _selectedTab == label;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == 'Account') ...[
            Icon(
              Icons.person_outline,
              size: 16,
              color: isSelected ? Colors.white : themeProvider.textColor,
            ),
            const SizedBox(width: 6),
          ] else if (label == 'Reports') ...[
            Icon(
              Icons.description_outlined,
              size: 16,
              color: isSelected ? Colors.white : themeProvider.textColor,
            ),
            const SizedBox(width: 6),
          ] else if (label == 'Settings') ...[
            Icon(
              Icons.settings_outlined,
              size: 16,
              color: isSelected ? Colors.white : themeProvider.textColor,
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTab = label;
        });
      },
      backgroundColor: themeProvider.cardColor,
      selectedColor: themeProvider.primaryColor,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : themeProvider.textColor,
      ),
      side: BorderSide(
        color: isSelected ? themeProvider.primaryColor : themeProvider.borderColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
