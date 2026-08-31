import 'package:flutter/material.dart';
import '../../../shared/services/maintenance_account_service.dart';

class MaintenanceManagementPage extends StatefulWidget {
  const MaintenanceManagementPage({super.key});

  @override
  State<MaintenanceManagementPage> createState() =>
      _MaintenanceManagementPageState();
}

class _MaintenanceManagementPageState extends State<MaintenanceManagementPage> {
  bool _isLoading = true;
  bool _showArchived = false;
  List<MaintenanceAccount> _activeAccounts = const [];
  List<MaintenanceAccount> _archivedAccounts = const [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MaintenanceAccountService.fetchCreatedByCurrentAdmin(),
        MaintenanceAccountService.fetchArchivedByCurrentAdmin(),
      ]);
      final activeData = results[0];
      final archivedData = results[1];
      if (!mounted) return;
      setState(() {
        _activeAccounts = activeData;
        _archivedAccounts = archivedData;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditMaintenanceDialog(MaintenanceAccount account) async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: account.email);
    final employeeIdController = TextEditingController(
      text: account.employeeId ?? '',
    );
    final specializationController = TextEditingController(
      text: account.specialization ?? '',
    );
    final fullNameController = TextEditingController(text: account.fullName);
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
                width: 450,
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
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
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
                            labelText: 'Maintenance FullName',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Full Name is required';
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
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          await _loadAccounts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Maintenance account updated successfully.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
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
    specializationController.dispose();
    fullNameController.dispose();
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

    await _loadAccounts();
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

    await _loadAccounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Maintenance account restored.'),
        backgroundColor: Colors.green,
      ),
    );
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

  Future<void> _showAddMaintenanceDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final employeeIdController = TextEditingController();
    final fullNameController = TextEditingController();
    final specializationController = TextEditingController();
    final contactController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Maintenance Account'),
              content: SizedBox(
                width: 450,
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
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
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
                            labelText: 'Maintenance FullName',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Full Name is required';
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
                              onPressed: () {
                                setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final v = value ?? '';
                            if (v.isEmpty) return 'Password is required';
                            if (v.length < 8) {
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
                              onPressed: () {
                                setDialogState(
                                  () => obscureConfirm = !obscureConfirm,
                                );
                              },
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Confirm Password is required';
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
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          await _loadAccounts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Maintenance account created successfully.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
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

  @override
  Widget build(BuildContext context) {
    final displayedAccounts = _showArchived
        ? _archivedAccounts
        : _activeAccounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance Management')),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddMaintenanceDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Maintenance'),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: displayedAccounts.isEmpty
                      ? Center(
                          child: Text(
                            _showArchived
                                ? 'No archived maintenance accounts.'
                                : 'No maintenance accounts created yet.',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                            children: [
                              ...displayedAccounts.map((account) {
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
                                                  Text(
                                                    account.fullName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Specialization: ${account.specialization ?? '-'}',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
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
                                              if (!_showArchived) ...[
                                                IconButton(
                                                  tooltip: 'Edit account',
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
                                                    Icons.edit_outlined,
                                                  ),
                                                  onPressed: () =>
                                                      _showEditMaintenanceDialog(
                                                        account,
                                                      ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Archive account',
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
                                                    Icons.archive_outlined,
                                                  ),
                                                  onPressed: () =>
                                                      _archiveMaintenanceAccount(
                                                        account,
                                                      ),
                                                ),
                                              ] else ...[
                                                IconButton(
                                                  tooltip: 'Restore account',
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
                                                    Icons.unarchive_outlined,
                                                  ),
                                                  onPressed: () =>
                                                      _restoreMaintenanceAccount(
                                                        account,
                                                      ),
                                                ),
                                              ],
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
