import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/work_request_model.dart';
import '../../../../shared/services/maintenance_account_service.dart';
import '../../../../shared/services/maintenance_status_service.dart';
import '../../../../shared/services/work_request_service.dart';
import '../../shared/admin_styles.dart';
import '../../../../shared/widgets/availability_status_badge.dart';
import '../admin_work_process_web.dart';
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
  bool _showArchivedAccounts = false;
  String _historyFilter = 'All';
  String _statusFilter = 'All';

  List<MaintenanceAccount> _activeAccounts = [];
  List<MaintenanceAccount> _archivedAccounts = [];
  List<WorkRequest> _historyItems = [];
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
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
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
        final s = req.status.toLowerCase();
        final isOngoing = s == 'in progress' ||
            s == 'in_progress' ||
            s == 'accepted' ||
            s == 'accepted by maintenance' ||
            s == 'confirmed' ||
            s == 'pre-inspection approved' ||
            s == 'post-repair submitted' ||
            s == 'rework' ||
            s == 'for rework' ||
            s == 'rework needed' ||
            s == 'pre-inspection submitted' ||
            s == 'under evaluation';
        if (isOngoing && req.assignedToId != null && req.assignedToId!.isNotEmpty) {
          activeBusyUserIds.add(req.assignedToId!);
        }
      }

      final nowUtc = DateTime.now().toUtc();

      // Re-map active accounts with accurate dynamic status
      final activeAccounts = rawActive.map((account) {
        final lastActive = account.lastActiveAt;
        final statusUpdated = account.statusUpdatedAt;

        // Account is actively open if a heartbeat was received within the last 35 seconds,
        // or if status was explicitly updated within the last 45 seconds.
        final int? lastActiveDiff = lastActive != null ? nowUtc.difference(lastActive.toUtc()).inSeconds : null;
        final int? statusUpdatedDiff = statusUpdated != null ? nowUtc.difference(statusUpdated.toUtc()).inSeconds : null;

        final bool isHeartbeatActive = lastActiveDiff != null && lastActiveDiff >= -15 && lastActiveDiff <= 35;
        final bool isRecentlyUpdated = statusUpdatedDiff != null && statusUpdatedDiff >= -15 && statusUpdatedDiff <= 45;
        final bool isAccountOpen = isHeartbeatActive || isRecentlyUpdated;

        String computedStatus;

        final currentRaw = account.availabilityStatus.toLowerCase().trim();
        if (currentRaw == 'offline') {
          computedStatus = 'offline';
        } else if (isAccountOpen) {
          // Account is actively open: detect if currently has ongoing work or manual busy
          if (activeBusyUserIds.contains(account.userId) || currentRaw == 'busy' || currentRaw == 'working') {
            computedStatus = 'busy';
          } else {
            computedStatus = 'online';
          }
        } else {
          // Account is not currently open (browser closed / app killed / no heartbeat)
          computedStatus = 'offline';

          // Sync database if it was stale
          if (currentRaw != 'offline') {
            MaintenanceStatusService.updateStatus(account.userId, 'offline').catchError((_) {});
          }
        }

        if (computedStatus != account.availabilityStatus.toLowerCase()) {
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

      final history = allRequests.where((item) {
        final status = item.status.toLowerCase();
        return status == 'completed' || status == 'declined';
      }).toList()..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));

      if (!mounted) return;
      setState(() {
        _activeAccounts = activeAccounts;
        _archivedAccounts = archivedAccounts;
        _historyItems = history;
      });
    } catch (_) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _activeAccounts = [];
          _archivedAccounts = [];
          _historyItems = [];
        });
      }
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _showChangeStatusDialog(MaintenanceAccount account) async {
    final current = account.availabilityStatus.toLowerCase();
    final options = [
      {'key': 'online', 'label': 'Online', 'desc': 'Available for task assignment', 'color': const Color(0xFF10B981)},
      {'key': 'busy', 'label': 'Busy', 'desc': 'Occupied with maintenance tasks', 'color': const Color(0xFFF59E0B)},
      {'key': 'offline', 'label': 'Offline', 'desc': 'Off-duty / not active', 'color': const Color(0xFF64748B)},
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AdminStyles.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set Status: ${account.fullName}',
                style: AdminStyles.headingStyle(fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final key = opt['key'] as String;
            final isSelected = current == key || (key == 'online' && current == 'available');
            final color = opt['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : AdminStyles.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                title: Text(
                  opt['label'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? color : AdminStyles.textPrimary,
                  ),
                ),
                subtitle: Text(
                  opt['desc'] as String,
                  style: const TextStyle(fontSize: 12, color: AdminStyles.textMuted),
                ),
                trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color, size: 20) : null,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await MaintenanceStatusService.updateStatus(account.userId, key);
                    if (mounted) {
                      _loadData(showLoading: false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Status of ${account.fullName} updated to ${opt['label']}'),
                          backgroundColor: color,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AdminStyles.error),
                      );
                    }
                  }
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  List<MaintenanceAccount> get _filteredAccounts {
    var source = _activeAccounts;

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

  List<WorkRequest> get _filteredHistory {
    var items = List<WorkRequest>.from(_historyItems);

    if (_historyFilter == 'Completed') {
      items = items
          .where((item) => item.status.toLowerCase() == 'completed')
          .toList();
    } else if (_historyFilter == 'Declined') {
      items = items
          .where((item) => item.status.toLowerCase() == 'declined')
          .toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((item) {
        final haystack =
            '${item.id} ${item.title} ${item.requestorName} ${item.officeRoom ?? ''} ${item.buildingName ?? ''}'
                .toLowerCase();
        return haystack.contains(query);
      }).toList();
    }

    return items;
  }

  Future<void> _showAddMaintenanceDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final employeeIdController = TextEditingController();
    final fullNameController = TextEditingController();
    final specializationController = TextEditingController();
    final contactController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSubmitting = false;
    bool obscurePassword = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Maintenance Account'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width > 500 ? 460 : MediaQuery.of(context).size.width * 0.85,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) return 'Email is required';
                            if (!input.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: employeeIdController,
                          decoration: const InputDecoration(
                            labelText: 'Maintenance ID',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Maintenance ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: specializationController,
                          decoration: const InputDecoration(
                            labelText: 'Specialization',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Specialization is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Number (Optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () => setDialogState(
                                () => obscurePassword = !obscurePassword,
                              ),
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final input = value ?? '';
                            if (input.isEmpty) return 'Password is required';
                            if (input.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: confirmController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            suffixIcon: IconButton(
                              onPressed: () => setDialogState(
                                () => obscureConfirm = !obscureConfirm,
                              ),
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Confirm password is required';
                            }
                            if (value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final error =
                              await MaintenanceAccountService.createMaintenanceAccount(
                                email: emailController.text,
                                fullName: fullNameController.text,
                                employeeId: employeeIdController.text,
                                specialization: specializationController.text,
                                contactNo: contactController.text,
                                password: passwordController.text,
                              );

                          if (!dialogContext.mounted) return;

                          if (error != null) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Maintenance account created successfully.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    employeeIdController.dispose();
    fullNameController.dispose();
    specializationController.dispose();
    contactController.dispose();
    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _showEditMaintenanceDialog(MaintenanceAccount account) async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: account.email);
    final employeeIdController = TextEditingController(
      text: account.employeeId ?? '',
    );
    final fullNameController = TextEditingController(text: account.fullName);
    final specializationController = TextEditingController(
      text: account.specialization ?? '',
    );
    final contactController = TextEditingController(
      text: account.contactNo ?? '',
    );
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Maintenance Account'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width > 500 ? 460 : MediaQuery.of(context).size.width * 0.85,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) return 'Email is required';
                            if (!input.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: employeeIdController,
                          decoration: const InputDecoration(
                            labelText: 'Maintenance ID',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Maintenance ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: specializationController,
                          decoration: const InputDecoration(
                            labelText: 'Specialization',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Specialization is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Number (Optional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final error =
                              await MaintenanceAccountService.updateMaintenanceAccount(
                                userId: account.userId,
                                email: emailController.text,
                                fullName: fullNameController.text,
                                employeeId: employeeIdController.text,
                                specialization: specializationController.text,
                                contactNo: contactController.text,
                              );

                          if (!dialogContext.mounted) return;

                          if (error != null) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          await _loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Maintenance account updated successfully.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    employeeIdController.dispose();
    fullNameController.dispose();
    specializationController.dispose();
    contactController.dispose();
  }

  Future<void> _archiveMaintenanceAccount(MaintenanceAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Account'),
        content: Text('Archive ${account.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final error = await MaintenanceAccountService.archiveMaintenanceAccount(
      account.userId,
    );
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maintenance account archived.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _restoreMaintenanceAccount(MaintenanceAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Account'),
        content: Text('Restore ${account.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final error = await MaintenanceAccountService.restoreMaintenanceAccount(
      account.userId,
    );
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maintenance account restored.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _openWorkRequest(WorkRequest request) {
    final controller = AdminNavController.of(context);
    if (controller != null) {
      controller.openWorkProcess(request);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminWorkProcessWeb(request: request),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _filteredAccounts;
    final history = _filteredHistory;
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maintenance User',
                        style: AdminStyles.pageTitleStyle(),
                      ),
                    ],
                  ),
                ),
              ],
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
    final isCompact = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Accounts',
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
                    'Active Accounts',
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
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AdminStyles.border.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AdminStyles.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: const Icon(
                          Icons.engineering_rounded,
                          color: AdminStyles.primary,
                        ),
                      ),
                      title: Row(
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
                          const SizedBox(width: 12),
                          AvailabilityStatusBadge(
                            status: account.availabilityStatus,
                            size: BadgeSize.small,
                            isInteractive: true,
                            onTap: () => _showChangeStatusDialog(account),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID: ${account.employeeId ?? '-'}',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 13,
                                      color: AdminStyles.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Specialization: ${account.specialization ?? '-'}',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 13,
                                      color: AdminStyles.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    account.email,
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 13,
                                      color: AdminStyles.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'ID: ${account.employeeId ?? '-'}  |  Specialization: ${account.specialization ?? '-'}  |  ${account.email}',
                                style: AdminStyles.bodyStyle(
                                  fontSize: 13,
                                  color: AdminStyles.textSecondary,
                                ),
                              ),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          _startingChatUserId == account.userId
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AdminStyles.primary),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Send message',
                                  onPressed: () => _startChat(account),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: AdminStyles.primary),
                                ),
                          IconButton(
                            tooltip: 'View details',
                            onPressed: () => _showMaintenanceDetails(account),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(List<WorkRequest> history) {
    final completed = history
        .where((item) => item.status.toLowerCase() == 'completed')
        .length;
    final declined = history
        .where((item) => item.status.toLowerCase() == 'declined')
        .length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maintenance Records',
                    style: AdminStyles.headingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MiniPill(
                        label: 'Completed: $completed',
                        color: AdminStyles.success,
                      ),
                      const SizedBox(width: 8),
                      _MiniPill(
                        label: 'Declined: $declined',
                        color: AdminStyles.error,
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Text(
                    'Maintenance Records',
                    style: AdminStyles.headingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _MiniPill(
                    label: 'Completed: $completed',
                    color: AdminStyles.success,
                  ),
                  const SizedBox(width: 8),
                  _MiniPill(
                    label: 'Declined: $declined',
                    color: AdminStyles.error,
                  ),
                ],
              ),
        const SizedBox(height: 14),
        Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: _historyFilter == 'All',
              onTap: () => setState(() => _historyFilter = 'All'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Completed',
              isSelected: _historyFilter == 'Completed',
              onTap: () => setState(() => _historyFilter = 'Completed'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Declined',
              isSelected: _historyFilter == 'Declined',
              onTap: () => setState(() => _historyFilter = 'Declined'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: AdminStyles.cardDecoration(borderRadius: 18),
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No maintenance records found.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AdminStyles.border.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final isCompleted =
                        item.status.toLowerCase() == 'completed';
                    final statusColor = isCompleted
                        ? AdminStyles.success
                        : AdminStyles.error;
                    return InkWell(
                      onTap: () => _openWorkRequest(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.formattedId,
                                        style: AdminStyles.dataStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: AdminStyles.pillDecoration(
                                          color: statusColor,
                                          isSecondary: true,
                                        ),
                                        child: Text(
                                          isCompleted
                                              ? 'COMPLETED'
                                              : 'DECLINED',
                                          style: AdminStyles.headingStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AdminStyles.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Requestor: ${item.requestorName}',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 12,
                                      color: AdminStyles.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Location: ${item.officeRoom ?? '-'}, ${item.buildingName ?? '-'}',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 12,
                                      color: AdminStyles.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Submitted: ${DateFormat('MMM dd, yyyy').format(item.dateSubmitted)}',
                                    style: AdminStyles.bodyStyle(
                                      fontSize: 12,
                                      color: AdminStyles.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  SizedBox(
                                    width: 130,
                                    child: Text(
                                      item.formattedId,
                                      style: AdminStyles.dataStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AdminStyles.bodyStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AdminStyles.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.requestorName,
                                          style: AdminStyles.bodyStyle(
                                            fontSize: 12,
                                            color: AdminStyles.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${item.officeRoom ?? '-'}, ${item.buildingName ?? '-'}',
                                      style: AdminStyles.bodyStyle(
                                        fontSize: 13,
                                        color: AdminStyles.textSecondary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(item.dateSubmitted),
                                      style: AdminStyles.bodyStyle(
                                        fontSize: 12,
                                        color: AdminStyles.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: AdminStyles.pillDecoration(
                                      color: statusColor,
                                      isSecondary: true,
                                    ),
                                    child: Text(
                                      isCompleted ? 'COMPLETED' : 'DECLINED',
                                      style: AdminStyles.headingStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AdminStyles.cardDecoration(borderRadius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.circle, color: color, size: 18),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: AdminStyles.headingStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title.toUpperCase(),
              style: AdminStyles.bodyStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AdminStyles.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
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

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AdminStyles.pillDecoration(color: color, isSecondary: true),
      child: Text(
        label,
        style: AdminStyles.headingStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AdminStyles.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AdminStyles.primary : AdminStyles.border,
          ),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AdminStyles.textPrimary,
          ),
        ),
      ),
    );
  }
}
