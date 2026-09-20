import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../admin/shared/notifications_page.dart';
import '../task/task_details_page.dart';
import '../maintenance_navigation.dart';
import '../../../shared/services/offline_sync_service.dart';
import '../../../shared/services/connectivity_service.dart';

// Web Parity Design Colors
const Color _blue = Color(0xFF0EA5E9);
const Color _green = Color(0xFF10B981);
const Color _orange = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _indigo = Color(0xFF6366F1);
const Color _purple = Color(0xFF8B5CF6);
const Color _pink = Color(0xFFEC4899);

class MaintenanceDashboardMobile extends StatefulWidget {
  final VoidCallback? openDrawer;
  final Function(int)? onTabSelected;

  const MaintenanceDashboardMobile({
    super.key,
    this.openDrawer,
    this.onTabSelected,
  });

  @override
  State<MaintenanceDashboardMobile> createState() =>
      _MaintenanceDashboardMobileState();
}

class _MaintenanceDashboardMobileState
    extends State<MaintenanceDashboardMobile>
    with WidgetsBindingObserver {
  List<WorkRequest> _requests = [];
  String _currentStatus = 'offline';
  bool _isLoading = true;
  bool _isFetching = false;
  Timer? _autoRefreshTimer;
  StreamSubscription? _changeSubscription;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequests();
    _loadStatus();
    _setupRealtime();

    _changeSubscription = WorkRequestService.onWorkRequestsChanged.listen((_) {
      _loadRequests(silent: true);
      _loadStatus();
    });

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _loadRequests(silent: true);
      _loadStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadRequests(silent: true);
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _changeSubscription?.cancel();
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupRealtime() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    try {
      _realtimeChannel =
          WorkRequestService.listenToMaintenanceRequests(user.id, (data) {
        if (mounted) {
          final maintenanceQueue = data
              .where((r) => r.status != 'Declined/Cancelled')
              .toList();
          setState(() {
            _requests = maintenanceQueue;
            _isLoading = false;
          });
          _syncAvailabilityStatus(maintenanceQueue);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      try {
        final res = await Supabase.instance.client
            .from('maintenance_users')
            .select('availability_status')
            .eq('user_id', user.id)
            .maybeSingle();
        if (res != null && mounted) {
          final status = res['availability_status']?.toString();
          if (status != null && status.isNotEmpty) {
            setState(() => _currentStatus = status);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _syncAvailabilityStatus(List<WorkRequest> requests) async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    // Automatic availability status:
    // If the technician has any active tasks assigned that are not completed, declined, or cancelled -> busy.
    // Otherwise -> available.
    final hasActiveTasks = requests.any((r) {
      final s = r.status.toLowerCase();
      return s != 'completed' &&
          s != 'declined' &&
          s != 'cancelled' &&
          s != 'declined/cancelled';
    });

    final computedStatus = hasActiveTasks ? 'busy' : 'available';
    if (_currentStatus != computedStatus) {
      if (mounted) {
        setState(() => _currentStatus = computedStatus);
      }
      try {
        await Supabase.instance.client
            .from('maintenance_users')
            .update({'availability_status': computedStatus})
            .eq('user_id', user.id);
      } catch (_) {}
    }
  }

  Future<void> _loadRequests({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent && _requests.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _requests = [];
            _isLoading = false;
          });
        }
        return;
      }

      final data = await WorkRequestService.fetchAssignedTo(user.id);
      final maintenanceQueue = data
          .where((r) =>
              r.status != 'Declined/Cancelled' &&
              r.status.toLowerCase() != 'pending' &&
              r.status.toLowerCase() != 'pending assignment')
          .toList();
      if (mounted) {
        setState(() {
          _requests = maintenanceQueue;
          _isLoading = false;
        });
        _syncAvailabilityStatus(maintenanceQueue);
      }
    } catch (_) {
      if (mounted && _requests.isEmpty) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  int _countByWorkflowStatus(String targetStatus) {
    return _requests.where((r) {
      final status = r.status.toLowerCase();
      final hasPreInsp = r.preInspectionId != null;
      final hasPostRepair = r.postRepairId != null;
      final isRework = status == 'rework';
      final isCompleted = status == 'completed';
      final isDeclined = status == 'declined' || status == 'cancelled';

      String computed = 'AWAITING REVIEW';
      if (isCompleted) {
        computed = 'COMPLETED';
      } else if (isDeclined) {
        computed = 'DECLINED';
      } else if (isRework) {
        computed = 'REWORK NEEDED';
      } else if (hasPostRepair) {
        computed = 'UNDER EVALUATION';
      } else if (status == 'confirmed') {
        computed = 'CONFIRMED';
      } else if (hasPreInsp) {
        computed = 'PRE-INSPECTION SUBMITTED';
      } else if (status == 'in progress' ||
          status == 'in_progress' ||
          status == 'assigned' ||
          status == 'accepted by maintenance') {
        if (r.acceptedDate == null) {
          computed = 'APPROVED';
        } else {
          computed = 'ACCEPTED';
        }
      } else {
        computed = 'AWAITING REVIEW';
      }

      return computed.toLowerCase() == targetStatus.toLowerCase();
    }).length;
  }

  int _countByPriority(String p) =>
      _requests.where((r) => r.priority.toLowerCase() == p.toLowerCase()).length;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: themeProvider.backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: _blue, strokeWidth: 3),
        ),
      );
    }

    final pending = _countByWorkflowStatus('APPROVED');
    final inProgress = _countByWorkflowStatus('ACCEPTED') +
        _countByWorkflowStatus('PRE-INSPECTION SUBMITTED') +
        _countByWorkflowStatus('CONFIRMED') +
        _countByWorkflowStatus('UNDER EVALUATION') +
        _countByWorkflowStatus('REWORK NEEDED');
    final completed = _countByWorkflowStatus('COMPLETED');
    final highPriority = _countByPriority('high');

    final activeRequests = _requests
        .where((r) {
          final s = r.status.toLowerCase();
          return s != 'completed' &&
              s != 'declined' &&
              s != 'cancelled' &&
              s != 'declined/cancelled';
        })
        .toList();

    final priorityAgingTickets = _requests
        .where((r) =>
            r.priority.toLowerCase() == 'high' &&
            r.status.toLowerCase() != 'completed' &&
            r.status.toLowerCase() != 'declined/cancelled')
        .toList();

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: '',
        primaryColor: const Color(0xFF4169E1),
        onMenuPressed: widget.openDrawer,
        onNotificationPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsPage()),
          );
          if (mounted) {
            setState(() {});
          }
        },
      ),
      body: RefreshIndicator(
        color: _blue,
        onRefresh: () async {
          await _loadStatus();
          await _loadRequests();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Offline Queue Indicator (Mobile specific) ───────────────────
            ValueListenableBuilder<int>(
              valueListenable: OfflineSyncService().queueCount,
              builder: (context, count, _) {
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Queue: $count items',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Text(
                              'Waiting for internet to sync...',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: ConnectivityService().isConnected,
                        builder: (context, isConnected, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: OfflineSyncService().isSyncing,
                            builder: (context, isSyncing, _) {
                              if (isSyncing) {
                                return const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                );
                              }
                              return IconButton(
                                icon: const Icon(Icons.sync, color: Colors.orange),
                                onPressed: isConnected
                                    ? () => OfflineSyncService().syncNow()
                                    : null,
                                tooltip: 'Sync Now',
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── 1. Stat Cards (Web Parity: 4 Grid Cards) ────────────────────
            _buildStatGrid(
              pending: pending,
              inProgress: inProgress,
              highPriority: highPriority,
              completed: completed,
              themeProvider: themeProvider,
            ),
            const SizedBox(height: 24),

            // ── 2. Ticket Aging (FIFO) — Preserved ───────────────────────────
            _buildTicketAgingSection(
              priorityTickets: priorityAgingTickets,
              themeProvider: themeProvider,
            ),
            const SizedBox(height: 24),

            // ── 3. Recent Work Requests (My Active Tasks) — Placed before Status Overview ──
            _buildRecentTasksSection(
              activeRequests: activeRequests,
              themeProvider: themeProvider,
            ),
            const SizedBox(height: 24),

            // ── 4. Status Overview (Status Breakdown Card) ──────────────────
            _buildStatusBreakdownCard(themeProvider),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }



  // ── Stat Grid (Web Parity: 4 Cards) ─────────────────────────────────────────
  Widget _buildStatGrid({
    required int pending,
    required int inProgress,
    required int highPriority,
    required int completed,
    required ThemeProvider themeProvider,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'Pending',
          subtitle: 'Awaiting Acceptance',
          value: pending,
          icon: Icons.schedule_rounded,
          color: _orange,
          themeProvider: themeProvider,
        ),
        _buildStatCard(
          title: 'In Progress',
          subtitle: 'Active tasks',
          value: inProgress,
          icon: Icons.engineering_rounded,
          color: _blue,
          themeProvider: themeProvider,
        ),
        _buildStatCard(
          title: 'High Priority',
          subtitle: 'Urgent Request',
          value: highPriority,
          icon: Icons.warning_amber_rounded,
          color: _red,
          themeProvider: themeProvider,
        ),
        _buildStatCard(
          title: 'Completed',
          subtitle: 'Resolved',
          value: completed,
          icon: Icons.check_circle_rounded,
          color: _green,
          themeProvider: themeProvider,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required int value,
    required IconData icon,
    required Color color,
    required ThemeProvider themeProvider,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: themeProvider.subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Ticket Aging (FIFO) Section ─────────────────────────────────────────────
  Widget _buildTicketAgingSection({
    required List<WorkRequest> priorityTickets,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 18, color: _orange),
                const SizedBox(width: 6),
                Text(
                  'Ticket Aging (FIFO)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PRIORITY REQUIRED',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: _red,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (priorityTickets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Center(
              child: Text(
                'No overdue or high-priority tickets',
                style: TextStyle(
                  color: themeProvider.subtitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              ...priorityTickets.take(2).map(
                    (r) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TaskDetailsPage(
                                  taskId: r.id,
                                  title: r.title,
                                  location: '${r.buildingName}, ${r.officeRoom}',
                                ),
                              ),
                            );
                          },
                          child: _buildPriorityTicket(
                            r.id.length > 8
                                ? '#${r.id.substring(0, 8).toUpperCase()}'
                                : '#${r.id.toUpperCase()}',
                            r.title,
                            '${r.buildingName}, ${r.officeRoom}',
                            r.statusLabel,
                            r.priority == 'high'
                                ? 'HIGH ATTENTION'
                                : 'JUST ASSIGNED',
                            r.priority == 'high' ? _red : _orange,
                            themeProvider,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
      ],
    );
  }

  Widget _buildPriorityTicket(
    String id,
    String title,
    String location,
    String status,
    String badge,
    Color badgeColor,
    ThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: badgeColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            id,
            style: TextStyle(
              fontSize: 10,
              color: themeProvider.subtitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: themeProvider.subtitleColor),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: _blue,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status Overview Breakdown Card (Web Parity) ─────────────────────────────
  Widget _buildStatusBreakdownCard(ThemeProvider themeProvider) {
    final total = _requests.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: themeProvider.textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressRow('Approved (Assigned)', 'Assigned by admin • Waiting for acceptance', _countByWorkflowStatus('APPROVED'), total, _orange, themeProvider),
          const SizedBox(height: 12),
          _buildProgressRow('Accepted', 'Task accepted • Ready for pre-inspection', _countByWorkflowStatus('ACCEPTED'), total, _blue, themeProvider),
          const SizedBox(height: 12),
          _buildProgressRow('Pre-Inspection Submitted', 'Report submitted • Awaiting Admin review', _countByWorkflowStatus('PRE-INSPECTION SUBMITTED'), total, _indigo, themeProvider),
          const SizedBox(height: 12),
          _buildProgressRow('Confirmed', 'Pre-inspection approved • Ready for repair', _countByWorkflowStatus('CONFIRMED'), total, _purple, themeProvider),
          const SizedBox(height: 12),
          _buildProgressRow('Under Evaluation', 'Post-repair submitted • Admin evaluation pending', _countByWorkflowStatus('UNDER EVALUATION'), total, _pink, themeProvider),
          const SizedBox(height: 12),
          _buildProgressRow('Rework Needed', 'Action required on repair work', _countByWorkflowStatus('REWORK NEEDED'), total, _red, themeProvider),
          const SizedBox(height: 12),
          _buildProgressRow('Completed', 'Work completed & verified', _countByWorkflowStatus('COMPLETED'), total, _green, themeProvider),
        ],
      ),
    );
  }

  Widget _buildProgressRow(
    String label,
    String subtitle,
    int count,
    int total,
    Color color,
    ThemeProvider themeProvider,
  ) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.textColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: themeProvider.subtitleColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: themeProvider.isDarkMode
                ? const Color(0xFF1E293B)
                : const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Recent Tasks Section ───────────────────────────────────────────────────
  Widget _buildRecentTasksSection({
    required List<WorkRequest> activeRequests,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Active Tasks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                if (widget.onTabSelected != null) {
                  widget.onTabSelected!(1);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const MaintenanceNavigation(initialIndex: 1),
                    ),
                  );
                }
              },
              child: const Text(
                'View All →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: themeProvider.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeProvider.borderColor),
            ),
            child: Center(
              child: Text(
                'No active tasks assigned',
                style: TextStyle(
                  color: themeProvider.subtitleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          ...activeRequests.take(5).map((r) {
            final priorityLabel = r.priority.toLowerCase() == 'high'
                ? 'HIGH PRIORITY'
                : r.priority.toLowerCase() == 'medium'
                    ? 'MEDIUM'
                    : 'LOW PRIORITY';
            final priorityColor = r.priority.toLowerCase() == 'high'
                ? _red
                : r.priority.toLowerCase() == 'medium'
                    ? _orange
                    : _blue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsPage(
                        taskId: r.id,
                        title: r.title,
                        location: '${r.buildingName}, ${r.officeRoom}',
                      ),
                    ),
                  );
                },
                child: _buildTaskCard(
                  r.id.length > 8
                      ? '#${r.id.substring(0, 8).toUpperCase()}'
                      : '#${r.id.toUpperCase()}',
                  r.title,
                  '${r.buildingName}, ${r.officeRoom}',
                  r.statusLabel,
                  priorityLabel,
                  priorityColor,
                  themeProvider,
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTaskCard(
    String id,
    String title,
    String location,
    String status,
    String priority,
    Color priorityColor,
    ThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeProvider.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeProvider.borderColor),
        boxShadow: [
          BoxShadow(
            color: themeProvider.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.subtitleColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: themeProvider.subtitleColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: themeProvider.subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 7, color: _blue),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Row(
                children: [
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: _blue,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
