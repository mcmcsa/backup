import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/faculty_user_service.dart';
import '../shared/admin_styles.dart';

class UsersPageWeb extends StatefulWidget {
  const UsersPageWeb({super.key});

  @override
  State<UsersPageWeb> createState() => _UsersPageWebState();
}

class _UsersPageWebState extends State<UsersPageWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<FacultyUserAccount> _facultyUsers = [];
  bool _isLoading = true;

  RealtimeChannel? _syncChannel;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _setupRealtime();
  }

  void _setupRealtime() {
    _syncChannel = Supabase.instance.client
        .channel('campus_admin_users_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            if (mounted) _loadUsers();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'teacher_users',
          callback: (payload) {
            if (mounted) _loadUsers();
          },
        )
        .subscribe();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await FacultyUserService.fetchAllFacultyUsers();
      if (!mounted) return;
      setState(() {
        _facultyUsers = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<FacultyUserAccount> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _facultyUsers;

    return _facultyUsers.where((user) {
      final haystack =
          '${user.fullName} ${user.email} ${user.employeeId ?? ''} '
          '${user.department ?? ''} ${user.position ?? ''}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _syncChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void _showEditDialog(BuildContext context, FacultyUserAccount user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final deptCtrl = TextEditingController(text: user.department ?? '');
    final empIdCtrl = TextEditingController(text: user.employeeId ?? '');
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Faculty User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(labelText: 'Department (e.g. CS, IT)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: empIdCtrl,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Active Account'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await FacultyUserService.updateFacultyUser(
                        userId: user.userId,
                        fullName: nameCtrl.text.trim(),
                        department: deptCtrl.text.trim(),
                        employeeId: empIdCtrl.text.trim(),
                        isActive: isActive,
                      );
                      _loadUsers();
                    } catch (e) {
                      setState(() => _isLoading = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Faculty Users',
                style: AdminStyles.pageTitleStyle(),
              ),
              const Spacer(),
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search faculty users...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    filled: false,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: Color(0xFF4169E1),
                        width: 1.4,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${filtered.length} faculty users found',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No faculty users found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFEEF2FF),
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF4169E1),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if ((user.department ?? '').isNotEmpty)
                                        _chip(
                                          Icons.apartment_outlined,
                                          user.department!,
                                        ),
                                      if ((user.position ?? '').isNotEmpty)
                                        _chip(
                                          Icons.badge_outlined,
                                          user.position!,
                                        ),
                                      if ((user.employeeId ?? '').isNotEmpty)
                                        _chip(
                                          Icons.tag_outlined,
                                          user.employeeId!,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.isActive
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      user.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: user.isActive
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFF97316),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF64748B), size: 20),
                                    onPressed: () => _showEditDialog(context, user),
                                    tooltip: 'Edit Faculty',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
