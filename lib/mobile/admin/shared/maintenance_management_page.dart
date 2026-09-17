import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/maintenance_status_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/widgets/availability_status_badge.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  bool _isLoading = true;
  List<MaintenanceAccount> _activeAccounts = const [];
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _workRequestsChannel;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _setupRealtime();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _workRequestsChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('public:mobile_maintenance_users_management')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'maintenance_users',
          callback: (_) {
            if (mounted) _loadAccounts(showLoading: false);
          },
        )
        .subscribe();

    _workRequestsChannel = Supabase.instance.client
        .channel('public:mobile_work_requests_maint_status')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'work_requests',
          callback: (_) {
            if (mounted) _loadAccounts(showLoading: false);
          },
        )
        .subscribe();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadAccounts(showLoading: false);
    });
  }

  Future<void> _loadAccounts({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MaintenanceAccountService.fetchAllActiveMaintenance(),
        WorkRequestService.fetchAll(),
      ]);
      final activeData = results[0] as List<MaintenanceAccount>;
      final allRequests = results[1] as List<WorkRequest>;

      final activeBusyUserIds = <String>{};
      for (final req in allRequests) {
        if (MaintenanceStatusService.isOngoingWorkRequestStatus(req.status)) {
          if (req.assignedToId != null && req.assignedToId!.isNotEmpty) {
            activeBusyUserIds.add(req.assignedToId!);
          }
        }
      }

      final nowUtc = DateTime.now().toUtc();

      final activeAccounts = activeData.map((account) {
        final bool isBusy = activeBusyUserIds.contains(account.userId);
        final String computedStatus = MaintenanceStatusService.computeDynamicStatus(
          hasActiveAssignment: isBusy,
          lastActiveAt: account.lastActiveAt,
          now: nowUtc,
        );

        if (computedStatus != account.availabilityStatus.toLowerCase()) {
          MaintenanceStatusService.updateStatus(account.userId, computedStatus).catchError((_) {});

          return MaintenanceAccount(
            userId: account.userId,
            email: account.email,
            fullName: account.fullName,
            employeeId: account.employeeId,
            specialization: account.specialization,
            contactNo: account.contactNo,
            isActive: account.isActive,
            archivedAt: account.archivedAt,
            createdAt: account.createdAt,
            availabilityStatus: computedStatus,
            currentLocation: account.currentLocation,
            currentAssignmentId: account.currentAssignmentId,
            estimatedCompletionTime: account.estimatedCompletionTime,
            lastActiveAt: account.lastActiveAt,
            workingHoursStart: account.workingHoursStart,
            workingHoursEnd: account.workingHoursEnd,
            statusUpdatedAt: account.statusUpdatedAt,
          );
        }
        return account;
      }).toList();

      if (!mounted) return;
      setState(() {
        _activeAccounts = activeAccounts;
      });
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _showMaintenanceDetails(MaintenanceAccount account) async {
    final createdAt = account.createdAt.toLocal().toString().split('.').first;
    final archivedAt = account.archivedAt
        ?.toLocal()
        .toString()
        .split('.')
        .first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Maintenance Details'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Name', account.fullName),
                _detailRow('Email', account.email),
                _detailRow('Maintenance ID', account.employeeId ?? '-'),
                _detailRow('Specialization', account.specialization ?? '-'),
                _detailRow('Contact Number', account.contactNo ?? '-'),
                _detailRow('Status', account.isActive ? 'Active' : 'Inactive'),
                _detailRow('Created At', createdAt),
                if (archivedAt != null) _detailRow('Archived At', archivedAt),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Management')),
      floatingActionButton: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _activeAccounts.isEmpty
                      ? const Center(
                          child: Text('No maintenance accounts found.'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                            children: [
                              ..._activeAccounts.map((account) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(
                                        color: Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: const Color(
                                              0xFF4169E1,
                                            ).withValues(alpha: 0.12),
                                            child: const Icon(
                                              Icons.engineering,
                                              color: Color(0xFF4169E1),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: SizedBox(
                                              height: 72,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          account.fullName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      AvailabilityStatusBadge(
                                                        status: account.availabilityStatus,
                                                        size: BadgeSize.small,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Specialization: ${account.specialization ?? '-'}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Wrap(
                                            spacing: 0,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              IconButton(
                                                tooltip: 'View details',
                                                iconSize: 22,
                                                visualDensity:
                                                    const VisualDensity(
                                                      horizontal: -3,
                                                      vertical: -3,
                                                    ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 30,
                                                      minHeight: 30,
                                                    ),
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(
                                                  Icons.visibility_outlined,
                                                ),
                                                onPressed: () =>
                                                    _showMaintenanceDetails(
                                                      account,
                                                    ),
                                              ),
                                              Icon(
                                                account.isActive
                                                    ? Icons.verified_user
                                                    : Icons.block,
                                                size: 22,
                                                color: account.isActive
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
