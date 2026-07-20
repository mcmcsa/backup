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
  
  List<LoginActivity> _logs = <LoginActivity>[];
  bool _isLoading = true;
  String _selectedFilter = 'All';

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
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconForLog(LoginActivity log) {
    if (log.eventType == 'login') return Icons.login_rounded;

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
    if (log.eventType == 'login') return const Color(0xFF4169E1);

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
      filtered = filtered.where((log) => log.eventType == 'login').toList();
    } else if (_selectedFilter == 'Actions') {
      filtered = filtered.where((log) => log.eventType != 'login').toList();
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

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Logs',
              style: AdminStyles.headingStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your recent interactions and system updates.',
              style: AdminStyles.bodyStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            _buildSearchAndFilter(),
            const SizedBox(height: 24),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: AdminStyles.cardDecoration(hasShadow: false),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search logs...',
              hintStyle: AdminStyles.bodyStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 12),
            _buildFilterChip('Login'),
            const SizedBox(width: 12),
            _buildFilterChip('Actions'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : _cardBg,
          border: Border.all(color: isSelected ? _primaryBlue : _borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _darkText,
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
        final color = _colorForLog(log);
        final icon = _iconForLog(log);

        return Container(
          decoration: AdminStyles.cardDecoration(hasShadow: false),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(log.userName, style: const TextStyle(fontSize: 12, color: _subtleText)),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: _borderColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          log.eventType == 'login' ? 'Login' : 'Action',
                          style: const TextStyle(fontSize: 12, color: _subtleText),
                        ),
                      ],
                    ),
                    if (log.details != null && log.details!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.details!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ],
                    if (log.workRequestId != null && log.workRequestId!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Request: ${log.workRequestId}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy hh:mm a').format(log.loggedInAt),
                style: AdminStyles.dataStyle(fontSize: 11, color: _subtleText),
              ),
            ],
          ),
        );
      },
    );
  }
}

