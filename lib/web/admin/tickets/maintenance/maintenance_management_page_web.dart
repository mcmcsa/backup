import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/models/work_request_model.dart';
import '../../../../shared/services/maintenance_account_service.dart';
import '../../../../shared/services/work_request_service.dart';
import '../../shared/admin_styles.dart';
import '../../../../authentication/models/user_model.dart';
import '../../../../shared/widgets/availability_status_badge.dart';
import '../admin_work_process_web.dart';

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

  List<MaintenanceAccount> _activeAccounts = [];
  List<MaintenanceAccount> _archivedAccounts = [];
  List<WorkRequest> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        // Show ALL maintenance accounts, not just admin-created ones
        MaintenanceAccountService.fetchAllActiveMaintenance(),
        MaintenanceAccountService.fetchAllArchivedMaintenance(),
        WorkRequestService.fetchAll(),
      ]);

      final activeAccounts = results[0] as List<MaintenanceAccount>;
      final archivedAccounts = results[1] as List<MaintenanceAccount>;
      final history = (results[2] as List<WorkRequest>).where((item) {
        final status = item.status.toLowerCase();
        return status == 'completed' || status == 'cancelled';
      }).toList()..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));

      if (!mounted) return;
      setState(() {
        _activeAccounts = activeAccounts;
        _archivedAccounts = archivedAccounts;
        _historyItems = history;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeAccounts = [];
        _archivedAccounts = [];
        _historyItems = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<MaintenanceAccount> get _filteredAccounts {
    final source = _showArchivedAccounts ? _archivedAccounts : _activeAccounts;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((account) {
      final haystack =
          '${account.fullName} ${account.email} ${account.employeeId ?? ''} ${account.specialization ?? ''} ${account.contactNo ?? ''}'
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
          .where((item) => item.status.toLowerCase() == 'cancelled')
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
                width: 460,
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
                            if (!input.contains('@'))
                              return 'Enter a valid email';
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
                            if (input.length < 8)
                              return 'Password must be at least 8 characters';
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
                            if ((value ?? '').isEmpty)
                              return 'Confirm password is required';
                            if (value != passwordController.text)
                              return 'Passwords do not match';
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
                width: 460,
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
                            if (!input.contains('@'))
                              return 'Enter a valid email';
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminWorkProcessWeb(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _filteredAccounts;
    final history = _filteredHistory;

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance User Management',
                      style: AdminStyles.pageTitleStyle(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create maintenance accounts and review completed maintenance records.',
                      style: AdminStyles.pageSubtitleStyle(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: AdminStyles.searchInputDecoration(
                      hintText: 'Search maintenance accounts...',
                      prefixIcon: Icons.search_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _HeaderActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh',
                  onTap: _loadData,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showAddMaintenanceDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Create Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminStyles.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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

  Widget _buildAccountsSection(List<MaintenanceAccount> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _showArchivedAccounts ? 'Archived Accounts' : 'Active Accounts',
              style: AdminStyles.headingStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Active (${_activeAccounts.length})'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Archived (${_archivedAccounts.length})'),
                ),
              ],
              selected: {_showArchivedAccounts},
              onSelectionChanged: (value) {
                setState(() => _showArchivedAccounts = value.first);
              },
            ),
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
                      _showArchivedAccounts
                          ? 'No archived maintenance accounts.'
                          : 'No maintenance accounts created yet.',
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
                          Text(
                            account.fullName,
                            style: AdminStyles.bodyStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AdminStyles.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          AvailabilityStatusBadge(
                            status: account.availabilityStatus,
                            size: BadgeSize.small,
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
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
                          IconButton(
                            tooltip: 'View details',
                            onPressed: () => _showMaintenanceDetails(account),
                            icon: const Icon(Icons.visibility_outlined),
                          ),
                          if (!_showArchivedAccounts) ...[
                            IconButton(
                              tooltip: 'Edit account',
                              onPressed: () =>
                                  _showEditMaintenanceDialog(account),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Archive account',
                              onPressed: () =>
                                  _archiveMaintenanceAccount(account),
                              icon: const Icon(Icons.archive_outlined),
                            ),
                          ] else ...[
                            IconButton(
                              tooltip: 'Restore account',
                              onPressed: () =>
                                  _restoreMaintenanceAccount(account),
                              icon: const Icon(Icons.restore_rounded),
                            ),
                          ],
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
        .where((item) => item.status.toLowerCase() == 'cancelled')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            _MiniPill(label: 'Declined: $declined', color: AdminStyles.error),
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
                        child: Row(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
