import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/work_request_model.dart';
import '../../../../shared/services/maintenance_account_service.dart';
import '../../../../shared/services/maintenance_status_service.dart';
import '../../../../shared/services/work_request_service.dart';
import '../../shared/admin_styles.dart';
import '../../../../shared/widgets/availability_status_badge.dart';
import '../../admin_nav_controller.dart';
import 'package:provider/provider.dart';
import '../../../../authentication/services/auth_service.dart';
import '../../../../shared/services/chat_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceManagementPageWeb extends StatefulWidget {
  const MaintenanceManagementPageWeb({super.key});

  @override
  State<MaintenanceManagementPageWeb> createState() =>
      _MaintenanceManagementPageWebState();
}

class _MaintenanceManagementPageWebState
    extends State<MaintenanceManagementPageWeb> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String _statusFilter = 'All';

  List<MaintenanceAccount> _activeAccounts = [];
  List<MaintenanceAccount> _archivedAccounts = [];
  String? _startingChatUserId;
  RealtimeChannel? _maintUsersChannel;
  RealtimeChannel? _workRequestsChannel;
  RealtimeChannel? _usersChannel;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  void _setupRealtime() {
    try {
      _maintUsersChannel = Supabase.instance.client
          .channel('public:maintenance_users_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'maintenance_users',
            callback: (_) {
              if (mounted) _loadData(showLoading: false);
            },
          )
          .subscribe();
    } catch (_) {}

    try {
      _workRequestsChannel = Supabase.instance.client
          .channel('public:work_requests_maint_status')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'work_requests',
            callback: (_) {
              if (mounted) _loadData(showLoading: false);
            },
          )
          .subscribe();
    } catch (_) {}

    try {
      _usersChannel = Supabase.instance.client
          .channel('public:users_maint_status')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (_) {
              if (mounted) _loadData(showLoading: false);
            },
          )
          .subscribe();
    } catch (_) {}

    // Auto-refresh timer to ensure real-time status consistency even if websocket reconnects
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  Future<void> _startChat(MaintenanceAccount account) async {
    setState(() => _startingChatUserId = account.userId);
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final room = await ChatService.findOrCreateDirectRoom(
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserRole: currentUser.role.name,
        otherUserId: account.userId,
        otherUserName: account.fullName,
        otherUserRole: 'maintenance',
      );

      if (mounted) {
        AdminNavController.of(context)?.navigateTo(20, chatRoom: room);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e'), backgroundColor: AdminStyles.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _startingChatUserId = null);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    if (_maintUsersChannel != null) {
      Supabase.instance.client.removeChannel(_maintUsersChannel!);
    }
    if (_workRequestsChannel != null) {
      Supabase.instance.client.removeChannel(_workRequestsChannel!);
    }
    if (_usersChannel != null) {
      Supabase.instance.client.removeChannel(_usersChannel!);
    }
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        // Show ALL maintenance accounts, not just admin-created ones
        MaintenanceAccountService.fetchAllActiveMaintenance(),
        MaintenanceAccountService.fetchAllArchivedMaintenance(),
        WorkRequestService.fetchAll(),
      ]);

      final rawActive = results[0] as List<MaintenanceAccount>;
      final archivedAccounts = results[1] as List<MaintenanceAccount>;
      final allRequests = results[2] as List<WorkRequest>;

      // Track active assignments to accurately detect busy technicians
      final activeBusyUserIds = <String>{};
      for (final req in allRequests) {
        if (MaintenanceStatusService.isOngoingWorkRequestStatus(req.status)) {
          if (req.assignedToId != null && req.assignedToId!.isNotEmpty) {
            activeBusyUserIds.add(req.assignedToId!);
          }
        }
      }

      final nowUtc = DateTime.now().toUtc();

      // Re-map active accounts with accurate dynamic status
      final activeAccounts = rawActive.map((account) {
        final bool isBusy = activeBusyUserIds.contains(account.userId);
        final String computedStatus = MaintenanceStatusService.computeDynamicStatus(
          hasActiveAssignment: isBusy,
          lastActiveAt: account.lastActiveAt,
          now: nowUtc,
        );

        if (computedStatus != account.availabilityStatus.toLowerCase()) {
          // Sync database in background if status changed
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
        _archivedAccounts = archivedAccounts;
      });
    } catch (_) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _activeAccounts = [];
          _archivedAccounts = [];
        });
      }
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  List<MaintenanceAccount> get _filteredAccounts {
    var source = _statusFilter == 'Archived' ? _archivedAccounts : _activeAccounts;

    if (_statusFilter == 'Online') {
      source = source.where((a) {
        final s = a.availabilityStatus.toLowerCase();
        return s == 'online' || s == 'available';
      }).toList();
    } else if (_statusFilter == 'Busy') {
      source = source.where((a) {
        final s = a.availabilityStatus.toLowerCase();
        return s == 'busy' || s == 'working';
      }).toList();
    } else if (_statusFilter == 'Offline') {
      source = source.where((a) {
        final s = a.availabilityStatus.toLowerCase();
        return s == 'offline' || s == 'break' || s == 'on_leave';
      }).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((account) {
      final haystack =
          '${account.fullName} ${account.email} ${account.employeeId ?? ''} ${account.specialization ?? ''} ${account.contactNo ?? ''} ${account.availabilityStatus}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _filteredAccounts;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final paddingVal = isCompact ? 16.0 : 28.0;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(paddingVal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance User',
              style: AdminStyles.pageTitleStyle(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminStyles.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: AdminStyles.searchInputDecoration(
                        hintText: 'Search maintenance accounts...',
                        prefixIcon: Icons.search_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _HeaderActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  onTap: _loadData,
                  hideLabel: isCompact,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AdminStyles.primary),
                ),
              )
            else
              Column(
                children: [
                  _buildAccountsSection(accounts),
                  const SizedBox(height: 20),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusPills() {
    final onlineCount = _activeAccounts.where((a) {
      final s = a.availabilityStatus.toLowerCase();
      return s == 'online' || s == 'available';
    }).length;

    final busyCount = _activeAccounts.where((a) {
      final s = a.availabilityStatus.toLowerCase();
      return s == 'busy' || s == 'working';
    }).length;

    final offlineCount = _activeAccounts.where((a) {
      final s = a.availabilityStatus.toLowerCase();
      return s == 'offline' || s == 'break' || s == 'on_leave';
    }).length;

    Widget pill(String label, int count, Color color) {
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
              color: isSelected ? color : AdminStyles.border,
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
                  color: isSelected ? color : AdminStyles.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill('All', _activeAccounts.length, AdminStyles.primary),
          const SizedBox(width: 8),
          pill('Online', onlineCount, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          pill('Busy', busyCount, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          pill('Offline', offlineCount, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(List<MaintenanceAccount> accounts) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 760;
    const sectionTitle = 'Active Accounts';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionTitle,
                    style: AdminStyles.headingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLiveStatusPills(),
                ],
              )
            : Row(
                children: [
                  Text(
                    sectionTitle,
                    style: AdminStyles.headingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildLiveStatusPills()),
                ],
              ),
        const SizedBox(height: 14),
        Container(
          decoration: AdminStyles.cardDecoration(borderRadius: 18),
          child: accounts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No maintenance accounts found.',
                      style: AdminStyles.bodyStyle(
                        color: AdminStyles.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accounts.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AdminStyles.border.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    return _buildAccountItem(accounts[index], isCompact);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAccountItem(MaintenanceAccount account, bool isCompact) {
    final isArchived = account.archivedAt != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AdminStyles.primary.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.engineering_rounded,
                        color: AdminStyles.primary,
                        size: 22,
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
                                  account.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AdminStyles.bodyStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AdminStyles.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AvailabilityStatusBadge(
                                status: account.availabilityStatus,
                                size: BadgeSize.small,
                                isInteractive: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Specialization: ${account.specialization ?? '-'}',
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              color: AdminStyles.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'ID: ${account.employeeId ?? '-'}  |  ${account.email}',
                  style: AdminStyles.bodyStyle(
                    fontSize: 12,
                    color: AdminStyles.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildActionButtons(account, isArchived),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AdminStyles.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: AdminStyles.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        account.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminStyles.bodyStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminStyles.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminStyles.border.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'ID: ${account.employeeId ?? '-'}',
                              style: AdminStyles.bodyStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AdminStyles.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Specialization: ${account.specialization ?? '-'}',
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              color: AdminStyles.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '•',
                            style: TextStyle(color: AdminStyles.border),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            account.email,
                            style: AdminStyles.bodyStyle(
                              fontSize: 12,
                              color: AdminStyles.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Live Status Badge cleanly vertically centered
                AvailabilityStatusBadge(
                  status: account.availabilityStatus,
                  size: BadgeSize.medium,
                  isInteractive: false,
                ),
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 28,
                  color: AdminStyles.border.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 12),
                // Clean Action buttons row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildActionButtons(account, isArchived),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildActionButtons(MaintenanceAccount account, bool isArchived) {
    return [
      _ActionButton(
        tooltip: 'Send Message',
        icon: Icons.chat_bubble_outline_rounded,
        color: AdminStyles.primary,
        hoverBg: AdminStyles.primary.withValues(alpha: 0.1),
        onTap: () => _startChat(account),
        isLoading: _startingChatUserId == account.userId,
      ),
      const SizedBox(width: 8),
      _ActionButton(
        tooltip: 'View Details',
        icon: Icons.visibility_outlined,
        color: const Color(0xFF64748B),
        hoverBg: const Color(0xFFF1F5F9),
        onTap: () => _showMaintenanceDetails(account),
      ),
    ];
  }

  Future<void> _showMaintenanceDetails(MaintenanceAccount account) async {
    final createdAt = account.createdAt.toLocal();
    final archivedAt = account.archivedAt?.toLocal();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Maintenance Account Details'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 460 ? 420 : MediaQuery.of(context).size.width * 0.85,
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
                _detailRow(
                  'Created At',
                  DateFormat('MMM dd, yyyy hh:mm a').format(createdAt),
                ),
                if (archivedAt != null)
                  _detailRow(
                    'Archived At',
                    DateFormat('MMM dd, yyyy hh:mm a').format(archivedAt),
                  ),
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
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool hideLabel;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hideLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (hideLabel) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminStyles.textPrimary,
          side: const BorderSide(color: AdminStyles.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 18),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminStyles.textPrimary,
        side: const BorderSide(color: AdminStyles.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final Color hoverBg;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.hoverBg,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverBg,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminStyles.border.withValues(alpha: 0.8)),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
