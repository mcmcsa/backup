import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/services/login_activity_service.dart';

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
  List<LoginActivity> _logs = <LoginActivity>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final data = await LoginActivityService.fetchAdminLogs();
      if (!mounted) return;
      setState(() {
        _logs = List<LoginActivity>.from(data)
          ..sort((left, right) => right.loggedInAt.compareTo(left.loggedInAt));
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
              ..sort((left, right) => left.loggedInAt.compareTo(right.loggedInAt)),
          ),
        )
        .toList();
  }

  IconData _iconForLog(LoginActivity log) {
    if (log.eventType == 'login') {
      return Icons.login_rounded;
    }

    final title = log.title.toLowerCase();
    if (title.contains('approve')) return Icons.check_circle_rounded;
    if (title.contains('reject') || title.contains('declin')) return Icons.cancel_rounded;
    if (title.contains('view')) return Icons.visibility_rounded;
    if (title.contains('create') || title.contains('add')) return Icons.add_circle_outline_rounded;
    if (title.contains('update') || title.contains('edit') || title.contains('change')) {
      return Icons.edit_note_rounded;
    }
    if (title.contains('delete') || title.contains('remove')) return Icons.delete_outline_rounded;
    if (title.contains('pre-inspection')) return Icons.fact_check_rounded;
    if (title.contains('post-repair')) return Icons.assignment_turned_in_rounded;
    return Icons.history_rounded;
  }

  Color _colorForLog(LoginActivity log) {
    if (log.eventType == 'login') {
      return const Color(0xFF4169E1);
    }

    final title = log.title.toLowerCase();
    if (title.contains('approve')) return const Color(0xFF059669);
    if (title.contains('reject') || title.contains('declin')) return const Color(0xFFDC2626);
    if (title.contains('view')) return const Color(0xFF0EA5E9);
    if (title.contains('create') || title.contains('add')) return const Color(0xFF7C3AED);
    if (title.contains('update') || title.contains('edit') || title.contains('change')) {
      return const Color(0xFFF59E0B);
    }
    if (title.contains('delete') || title.contains('remove')) return const Color(0xFFEF4444);
    if (title.contains('pre-inspection')) return const Color(0xFFF59E0B);
    if (title.contains('post-repair')) return const Color(0xFF8B5CF6);
    return const Color(0xFF64748B);
  }

  Widget _buildEntryCard(LoginActivity log) {
    final isLogin = log.eventType == 'login';
    final color = _colorForLog(log);
    final time = DateFormat('hh:mm a').format(log.loggedInAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLogin ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLogin ? color.withValues(alpha: 0.18) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _iconForLog(log),
              color: color,
              size: 19,
            ),
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
                        isLogin ? 'Admin Login' : log.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Admin: ${log.userName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                if (log.details != null && log.details!.trim().isNotEmpty)
                  Text(
                    log.details!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                if (log.workRequestId != null && log.workRequestId!.trim().isNotEmpty)
                  Text(
                    'Request: ${log.workRequestId}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(_AdminLogDayGroup group) {
    final dateLabel = DateFormat('MMMM dd, yyyy').format(group.day);
    final loginCount = group.entries.where((log) => log.eventType == 'login').length;
    final actionCount = group.entries.length - loginCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4169E1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF4169E1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$loginCount login${loginCount == 1 ? '' : 's'} • $actionCount action${actionCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...group.entries.map(_buildEntryCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedLogs = _groupLogsByDay(_logs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Logs',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        color: Colors.grey.shade400,
                        size: 54,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No admin logs yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      ...groupedLogs.map(_buildDayCard),
                    ],
                  ),
                ),
    );
  }
}
