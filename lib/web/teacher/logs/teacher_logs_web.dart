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
    if (title.contains('create') || title.contains('add') || title.contains('submitted')) {
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
    if (log.eventType == 'login') return const Color(0xFF00BFA5); // Teal

    final title = log.title.toLowerCase();
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) {
      return const Color(0xFFDC2626);
    }
    if (title.contains('view')) return const Color(0xFF0EA5E9);
    if (title.contains('create') || title.contains('add') || title.contains('submitted')) return const Color(0xFF7C3AED);
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

    if (_selectedFilter != 'All') {
      if (_selectedFilter == 'Submitted') {
        filtered = filtered.where((log) => log.title.toLowerCase().contains('submit')).toList();
      } else if (_selectedFilter == 'Updated') {
        filtered = filtered.where((log) => log.title.toLowerCase().contains('update') || log.title.toLowerCase().contains('edit')).toList();
      }
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((log) {
        return log.title.toLowerCase().contains(query) ||
               (log.details?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildFilters(),
            const SizedBox(height: 32),
            _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AdminStyles.primary))
                : _buildLogsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity Logs', style: AdminStyles.headingStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Track your recent interactions and system updates.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 16)),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: AdminStyles.searchInputDecoration(
                hintText: 'Search logs...',
                prefixIcon: Icons.search_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _buildTab('All'),
        const SizedBox(width: 12),
        _buildTab('Submitted'),
        const SizedBox(width: 12),
        _buildTab('Updated'),
      ],
    );
  }

  Widget _buildTab(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : AdminStyles.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF0F766E) : AdminStyles.border),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            color: isSelected ? Colors.white : AdminStyles.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsContent() {
    final displayLogs = _filteredLogs;

    return Container(
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent History', style: AdminStyles.headingStyle(fontSize: 18)),
                Text('${displayLogs.length} items', style: AdminStyles.bodyStyle(color: AdminStyles.textMuted)),
              ],
            ),
          ),
          Divider(height: 1, color: AdminStyles.border),
          if (displayLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('No logs found for this filter.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayLogs.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AdminStyles.border),
              itemBuilder: (context, index) {
                final log = displayLogs[index];
                
                String timeAgo = '';
                final diff = DateTime.now().difference(log.loggedInAt);
                if (diff.inMinutes < 1) timeAgo = 'just now';
                else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
                else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
                else if (diff.inDays < 7) timeAgo = '${diff.inDays}d ago';
                else timeAgo = DateFormat('MMM dd, yyyy HH:mm').format(log.loggedInAt);

                return _buildLogItem(
                  log.title, 
                  log.details ?? log.eventType, 
                  timeAgo, 
                  _iconForLog(log), 
                  _colorForLog(log)
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLogItem(String action, String description, String timeAgo, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: AdminStyles.headingStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
              ],
            ),
          ),
          Text(timeAgo, style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

