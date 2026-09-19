import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/maintenance_account_service.dart';
import '../../../shared/services/maintenance_status_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/maintenance_schedule_service.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/widgets/chat/chat_messages_panel.dart';
import '../../../shared/providers/theme_provider.dart';
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

  Future<void> _startChatWithMaintenance(MaintenanceAccount account) async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4169E1)),
      ),
    );

    try {
      final room = await ChatService.findOrCreateDirectRoom(
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserRole: currentUser.role.name,
        otherUserId: account.userId,
        otherUserName: account.fullName,
        otherUserRole: 'maintenance',
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: themeProvider.backgroundColor,
            body: SafeArea(
              top: false,
              child: ChatMessagesPanel(
                key: ValueKey(room.id),
                room: room,
                currentUserId: currentUser.id,
                currentUserName: currentUser.name,
                currentUserRole: currentUser.role.name,
                onBack: () => Navigator.pop(context),
                onRoomDeleted: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $e')),
      );
    }
  }

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
  }  Future<void> _showMaintenanceDetails(MaintenanceAccount account) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final createdAt = account.createdAt.toLocal().toString().split('.').first;
    final archivedAt =
        account.archivedAt?.toLocal().toString().split('.').first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: themeProvider.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: themeProvider.borderColor),
        ),
        title: Text(
          'Maintenance Details',
          style: TextStyle(
            color: themeProvider.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Name', account.fullName, themeProvider),
                _detailRow('Email', account.email, themeProvider),
                _detailRow('Maintenance ID', account.employeeId ?? '-', themeProvider),
                _detailRow('Specialization', account.specialization ?? '-', themeProvider),
                _detailRow('Contact Number', account.contactNo ?? '-', themeProvider),
                _detailRow('Status', account.isActive ? 'Active' : 'Inactive', themeProvider),
                _detailRow('Availability', account.availabilityStatus, themeProvider),
                _detailRow('Created At', createdAt, themeProvider),
                if (archivedAt != null) _detailRow('Archived At', archivedAt, themeProvider),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Close', style: TextStyle(color: themeProvider.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: themeProvider.subtitleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: themeProvider.textColor,
              fontWeight: FontWeight.w500,
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
    final themeProvider = Provider.of<ThemeProvider>(context);
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
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Maintenance Staff',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: themeProvider.textColor),
            onPressed: () => _loadAccounts(showLoading: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4169E1)))
          : Column(
              children: [
                // ── Master Schedule Top Action Banner ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  color: themeProvider.cardColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _viewMasterSchedule,
                          icon: const Icon(Icons.calendar_month_rounded, size: 16),
                          label: const Text(
                            'View Schedule',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: themeProvider.isDarkMode ? const Color(0xFF14B8A6) : const Color(0xFF0F766E),
                              width: 1.2,
                            ),
                            backgroundColor: const Color(0xFF0F766E).withValues(
                              alpha: themeProvider.isDarkMode ? 0.15 : 0.06,
                            ),
                            foregroundColor: themeProvider.isDarkMode ? const Color(0xFF14B8A6) : const Color(0xFF0F766E),
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
                // ── Availability Filter Pills (All / Available / Busy) ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: themeProvider.cardColor,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All', _activeAccounts.length, const Color(0xFF4169E1), themeProvider),
                        const SizedBox(width: 8),
                        _buildFilterPill('Available', availableCount, const Color(0xFF10B981), themeProvider),
                        const SizedBox(width: 8),
                        _buildFilterPill('Busy', busyCount, const Color(0xFFF59E0B), themeProvider),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: themeProvider.dividerColor),
                Expanded(
                  child: accounts.isEmpty
                      ? Center(
                          child: Text(
                            'No maintenance accounts found.',
                            style: TextStyle(color: themeProvider.subtitleColor, fontSize: 14),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          color: const Color(0xFF4169E1),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
                            children: [
                              ...accounts.map((account) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: themeProvider.cardColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: themeProvider.borderColor),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: themeProvider.isDarkMode ? 0.2 : 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Row 1: Avatar, Name & Email, Status Badge
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4169E1).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.engineering_rounded,
                                                color: Color(0xFF4169E1),
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    account.fullName,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: themeProvider.textColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    account.email,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: themeProvider.subtitleColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AvailabilityStatusBadge(
                                              status: account.availabilityStatus,
                                              size: BadgeSize.small,
                                              showLabel: true,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Row 2: Specialization tag + Actions (Details & Message)
                                        Row(
                                          children: [
                                            // Specialization Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: themeProvider.inputFillColor,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: themeProvider.borderColor),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.build_circle_outlined,
                                                    size: 13,
                                                    color: themeProvider.subtitleColor,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    account.specialization ?? 'General Maintenance',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: themeProvider.subtitleColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            // View Details Button
                                            InkWell(
                                              onTap: () => _showMaintenanceDetails(account),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: themeProvider.inputFillColor,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: themeProvider.borderColor),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.visibility_outlined,
                                                      size: 14,
                                                      color: themeProvider.subtitleColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Details',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: themeProvider.subtitleColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Message Button
                                            InkWell(
                                              onTap: () => _startChatWithMaintenance(account),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF4169E1).withValues(
                                                    alpha: themeProvider.isDarkMode ? 0.2 : 0.08,
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(0xFF4169E1).withValues(
                                                      alpha: themeProvider.isDarkMode ? 0.4 : 0.25,
                                                    ),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.chat_bubble_outline_rounded,
                                                      size: 13,
                                                      color: Color(0xFF4169E1),
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Message',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF4169E1),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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

  Widget _buildFilterPill(String label, int count, Color color, ThemeProvider themeProvider) {
    final isSelected = _statusFilter == label;
    final unselectedBg = themeProvider.isDarkMode ? themeProvider.cardColor : Colors.white;
    final unselectedBorder = themeProvider.borderColor;
    final unselectedText = themeProvider.subtitleColor;

    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: themeProvider.isDarkMode ? 0.2 : 0.12)
              : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : unselectedBorder,
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
            const SizedBox(width: 6),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : unselectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
