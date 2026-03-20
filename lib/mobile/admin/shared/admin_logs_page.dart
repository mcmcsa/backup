import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/login_activity_service.dart';

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
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _logs = <LoginActivity>[];
            _isLoading = false;
          });
        }
        return;
      }

      final data = await LoginActivityService.fetchAdminLogs(userId: user.id);
      if (mounted) {
        setState(() {
          _logs = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _logs = <LoginActivity>[];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Admin Logs',
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final date = DateFormat('MMMM dd, yyyy').format(log.loggedInAt);
                      final time = DateFormat('hh:mm a').format(log.loggedInAt);
                      final isLogin = log.eventType == 'login';

                      IconData leadingIcon;
                      Color leadingColor;
                      if (isLogin) {
                        leadingIcon = Icons.login_rounded;
                        leadingColor = const Color(0xFF4169E1);
                      } else if ((log.title).toLowerCase().contains('approve')) {
                        leadingIcon = Icons.check_circle_rounded;
                        leadingColor = const Color(0xFF059669);
                      } else if ((log.title).toLowerCase().contains('view')) {
                        leadingIcon = Icons.visibility_rounded;
                        leadingColor = const Color(0xFF0EA5E9);
                      } else if ((log.title).toLowerCase().contains('pre-inspection')) {
                        leadingIcon = Icons.fact_check_rounded;
                        leadingColor = const Color(0xFFF59E0B);
                      } else if ((log.title).toLowerCase().contains('post-repair')) {
                        leadingIcon = Icons.assignment_turned_in_rounded;
                        leadingColor = const Color(0xFF8B5CF6);
                      } else {
                        leadingIcon = Icons.history_rounded;
                        leadingColor = const Color(0xFF64748B);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: leadingColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                leadingIcon,
                                color: leadingColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isLogin
                                        ? 'PRIMARY: ${log.title}'
                                        : 'SECONDARY: ${log.title}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isLogin
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: $date',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    'Time: $time',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  if (log.details != null && log.details!.trim().isNotEmpty)
                                    Text(
                                      log.details!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  if (log.workRequestId != null &&
                                      log.workRequestId!.trim().isNotEmpty)
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
                    },
                  ),
                ),
    );
  }
}
