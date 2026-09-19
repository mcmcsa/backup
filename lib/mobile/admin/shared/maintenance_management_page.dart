import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/maintenance_status_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/maintenance_schedule_service.dart';
import '../../../shared/widgets/maintenance_schedule_dialog.dart';
import '../../../shared/widgets/availability_status_badge.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  bool _isLoading = true;
  String _statusFilter = 'All';
  List<MaintenanceAccount> _activeAccounts = const [];
  String? _masterScheduleUrl;
  bool _isUploadingSchedule = false;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _workRequestsChannel;
  Timer? _autoRefreshTimer;
  StreamSubscription<String>? _scheduleSub;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _setupRealtime();
    _scheduleSub = MaintenanceScheduleService.onScheduleUpdated.listen((_) {
      if (mounted) _loadSchedules();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _scheduleSub?.cancel();
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

  Future<void> _loadSchedules() async {
    try {
      final url = await MaintenanceScheduleService.getMasterScheduleUrl();
      if (mounted) {
        setState(() => _masterScheduleUrl = url);
      }
    } catch (_) {}
  }

  Future<void> _loadAccounts({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MaintenanceAccountService.fetchAllActiveMaintenance(),
        WorkRequestService.fetchAll(),
        MaintenanceScheduleService.getMasterScheduleUrl(),
      ]);
      final activeData = results[0] as List<MaintenanceAccount>;
      final allRequests = results[1] as List<WorkRequest>;
      final masterSched = results[2] as String?;

      final activeBusyUserIds = <String>{};
      for (final req in allRequests) {
        if (MaintenanceStatusService.isOngoingWorkRequestStatus(req.status)) {
          if (req.assignedToId != null && req.assignedToId!.isNotEmpty) {
            activeBusyUserIds.add(req.assignedToId!);
          }
        }
      }

      final activeAccounts = activeData.map((account) {
        final bool isBusy = activeBusyUserIds.contains(account.userId);
        final String computedStatus = isBusy ? 'busy' : 'available';

        if (computedStatus != account.availabilityStatus.toLowerCase()) {
          MaintenanceStatusService.updateStatus(account.userId, computedStatus)
              .catchError((_) {});

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
        _masterScheduleUrl = masterSched;
      });
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewMasterSchedule() async {
    await showMaintenanceScheduleDialog(
      context,
      title: 'Maintenance Schedule',
      subtitle: 'Campus Master Schedule • All Maintenance Staff',
      scheduleUrl: _masterScheduleUrl,
      onScheduleChanged: _loadSchedules,
    );
  }

  Future<void> _attachMasterSchedule() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;

      setState(() => _isUploadingSchedule = true);

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;

      final url = await MaintenanceScheduleService.uploadMasterSchedule(
        bytes: bytes,
        extension: ext,
      );

      if (mounted) {
        setState(() {
          _masterScheduleUrl = url;
          _isUploadingSchedule = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance schedule image attached successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingSchedule = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach schedule image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showMaintenanceDetails(MaintenanceAccount account) async {
    final createdAt = account.createdAt.toLocal().toString().split('.').first;
    final archivedAt =
        account.archivedAt?.toLocal().toString().split('.').first;

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
                _detailRow('Availability', account.availabilityStatus),
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

  List<MaintenanceAccount> get _filteredAccounts {
    if (_statusFilter == 'Available') {
      return _activeAccounts.where((a) {
        final s = a.availabilityStatus.toLowerCase();
        return s != 'busy' && s != 'working';
      }).toList();
    } else if (_statusFilter == 'Busy') {
      return _activeAccounts.where((a) {
        final s = a.availabilityStatus.toLowerCase();
        return s == 'busy' || s == 'working';
      }).toList();
    }
    return _activeAccounts;
  }

  @override
  Widget build(BuildContext context) {
    final busyCount = _activeAccounts.where((a) {
      final s = a.availabilityStatus.toLowerCase();
      return s == 'busy' || s == 'working';
    }).length;

    final availableCount = _activeAccounts.where((a) {
      final s = a.availabilityStatus.toLowerCase();
      return s != 'busy' && s != 'working';
    }).length;

    final accounts = _filteredAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadAccounts(showLoading: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Master Schedule Top Action Banner ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _viewMasterSchedule,
                          icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0F766E)),
                          label: const Text(
                            'View Schedule',
                            style: TextStyle(
                              color: Color(0xFF0F766E),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                            backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.06),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingSchedule ? null : _attachMasterSchedule,
                          icon: _isUploadingSchedule
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: Text(
                            _masterScheduleUrl != null ? 'Update Sched' : 'Attach Sched',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Binary Availability Filter Pills (All / Available / Busy) ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All', _activeAccounts.length, const Color(0xFF4169E1)),
                        const SizedBox(width: 8),
                        _buildFilterPill('Available', availableCount, const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        _buildFilterPill('Busy', busyCount, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: accounts.isEmpty
                      ? const Center(
                          child: Text('No maintenance accounts found.'),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                            children: [
                              ...accounts.map((account) {
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
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                               FontWeight.w700,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    AvailabilityStatusBadge(
                                                      status: account
                                                          .availabilityStatus,
                                                      size: BadgeSize.small,
                                                      showLabel: true,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Spec: ${account.specialization ?? '-'} • ${account.email}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Details Button
                                          IconButton(
                                            tooltip: 'View details',
                                            iconSize: 20,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(
                                              minWidth: 30,
                                              minHeight: 30,
                                            ),
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              color: Color(0xFF64748B),
                                            ),
                                            onPressed: () =>
                                                _showMaintenanceDetails(
                                              account,
                                            ),
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

  Widget _buildFilterPill(String label, int count, Color color) {
    final isSelected = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
