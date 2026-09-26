import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../authentication/services/auth_service.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/services/department_service.dart';
import '../../../shared/services/faculty_user_service.dart';
import '../admin_main_navigation_web.dart';
import '../admin_nav_controller.dart';
import '../shared/admin_styles.dart';

class AdminUsersWeb extends StatefulWidget {
  const AdminUsersWeb({super.key});

  @override
  State<AdminUsersWeb> createState() => _AdminUsersWebState();
}

class _AdminUsersWebState extends State<AdminUsersWeb> {
  final TextEditingController _searchController = TextEditingController();

  List<FacultyUserAccount> _users = [];
  List<Department> _departments = [];
  bool _isLoading = true;
  String? _startingChatUserId;

  String _selectedDepartmentFilter = 'All';
  String _selectedStatusFilter = 'All';

  RealtimeChannel? _usersChannel;
  RealtimeChannel? _teacherUsersChannel;
  RealtimeChannel? _departmentsChannel;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
  }

  void _setupRealtime() {
    try {
      _usersChannel = Supabase.instance.client
          .channel('public:users_admin_faculty_sync')
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

    try {
      _teacherUsersChannel = Supabase.instance.client
          .channel('public:teacher_users_admin_faculty_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'teacher_users',
            callback: (_) {
              if (mounted) _loadData(showLoading: false);
            },
          )
          .subscribe();
    } catch (_) {}

    try {
      _departmentsChannel = Supabase.instance.client
          .channel('public:departments_admin_faculty_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'departments',
            callback: (_) {
              if (mounted) _loadData(showLoading: false);
            },
          )
          .subscribe();
    } catch (_) {}

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _loadData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    if (_usersChannel != null) Supabase.instance.client.removeChannel(_usersChannel!);
    if (_teacherUsersChannel != null) Supabase.instance.client.removeChannel(_teacherUsersChannel!);
    if (_departmentsChannel != null) Supabase.instance.client.removeChannel(_departmentsChannel!);
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FacultyUserService.fetchAllFacultyUsers(),
        DepartmentService.fetchAll(),
      ]);

      if (!mounted) return;

      setState(() {
        _users = results[0] as List<FacultyUserAccount>;
        _departments = results[1] as List<Department>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading faculty users: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<FacultyUserAccount> get _filteredUsers {
    var list = _users;

    // Filter by department
    if (_selectedDepartmentFilter != 'All') {
      if (_selectedDepartmentFilter == 'No Department') {
        list = list.where((u) {
          final dept = (u.department ?? '').trim();
          return dept.isEmpty || dept.toLowerCase() == 'no department' || dept == '-';
        }).toList();
      } else {
        list = list.where((u) {
          return (u.department ?? '').trim().toLowerCase() ==
              _selectedDepartmentFilter.trim().toLowerCase();
        }).toList();
      }
    }

    // Filter by status
    if (_selectedStatusFilter == 'Active') {
      list = list.where((u) => u.isActive).toList();
    } else if (_selectedStatusFilter == 'Inactive') {
      list = list.where((u) => !u.isActive).toList();
    }

    // Search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return list;

    return list.where((u) {
      final haystack =
          '${u.fullName} ${u.email} ${u.employeeId ?? ''} ${u.department ?? ''} ${u.position ?? ''}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _startChat(FacultyUserAccount user) async {
    setState(() => _startingChatUserId = user.userId);
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final room = await ChatService.findOrCreateDirectRoom(
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserRole: currentUser.role.name,
        otherUserId: user.userId,
        otherUserName: user.fullName,
        otherUserRole: 'teacher',
      );

      if (mounted) {
        AdminNavController.of(context)?.navigateTo(
          AdminMainNavigationWeb.chatIndex,
          chatRoom: room,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: AdminStyles.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _startingChatUserId = null);
      }
    }
  }

  Future<void> _showFacultyDetails(FacultyUserAccount user) async {
    final formattedDate = DateFormat('MMMM dd, yyyy').format(user.createdAt.toLocal());
    final hasDept = (user.department ?? '').trim().isNotEmpty &&
        user.department?.toLowerCase() != 'no department' &&
        user.department != '-';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AdminStyles.primary.withValues(alpha: 0.12),
              child: Text(
                _getInitials(user.fullName),
                style: const TextStyle(
                  color: AdminStyles.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminStyles.headingStyle(fontSize: 18),
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 24),
              _detailRow('Department', hasDept ? user.department! : 'No Department (Unassigned)', isHighlighted: hasDept),
              _detailRow('Employee ID', user.employeeId?.isNotEmpty == true ? user.employeeId! : 'Not Provided'),
              _detailRow('Position', user.position ?? 'Faculty Member'),
              _detailRow('Account Status', user.isActive ? 'Active' : 'Inactive'),
              _detailRow('Date Registered', formattedDate),
            ],
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

  Widget _detailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                color: isHighlighted ? AdminStyles.primary : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 800;
    final paddingVal = isCompact ? 16.0 : 28.0;

    final users = _filteredUsers;

    // Distinct department names present in current dataset for filtering
    final Set<String> deptSet = {};
    for (final u in _users) {
      final d = (u.department ?? '').trim();
      if (d.isNotEmpty && d.toLowerCase() != 'no department' && d != '-') {
        deptSet.add(d);
      }
    }
    for (final d in _departments) {
      if (d.name.trim().isNotEmpty) {
        deptSet.add(d.name.trim());
      }
    }
    final sortedDepts = deptSet.toList()..sort();

    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(paddingVal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header with Refresh
            _buildPageHeader(isCompact),
            const SizedBox(height: 20),

            // Search & Filter Bar
            _buildSearchAndFilters(
              departments: sortedDepts,
              isCompact: isCompact,
            ),
            const SizedBox(height: 18),

            // Table or Card List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(color: AdminStyles.primary),
                ),
              )
            else if (users.isEmpty)
              _buildEmptyState()
            else
              isCompact
                  ? _buildMobileCards(users)
                  : _buildDesktopTable(users),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Users', style: AdminStyles.pageTitleStyle(fontSize: isCompact ? 22 : 26)),
              const SizedBox(height: 4),
              Text(
                'Manage and view faculty accounts and departmental assignments',
                style: AdminStyles.pageSubtitleStyle(fontSize: isCompact ? 12 : 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(isCompact ? '' : 'Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AdminStyles.textPrimary,
            side: const BorderSide(color: AdminStyles.border),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters({
    required List<String> departments,
    required bool isCompact,
  }) {
    final searchInput = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: AdminStyles.searchInputDecoration(
          hintText: 'Search faculty by name, email, employee ID, or department...',
          prefixIcon: Icons.search_rounded,
        ).copyWith(
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );

    final deptDropdown = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminStyles.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedDepartmentFilter,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AdminStyles.primary),
          style: AdminStyles.bodyStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AdminStyles.textPrimary,
          ),
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All Departments')),
            const DropdownMenuItem(value: 'No Department', child: Text('Unassigned (No Dept)')),
            ...departments.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            }),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedDepartmentFilter = val);
          },
        ),
      ),
    );

    final statusPills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterPill('All'),
        const SizedBox(width: 8),
        _buildFilterPill('Active'),
        const SizedBox(width: 8),
        _buildFilterPill('Inactive'),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchInput,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: deptDropdown),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: statusPills,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchInput),
        const SizedBox(width: 12),
        SizedBox(width: 240, child: deptDropdown),
        const SizedBox(width: 16),
        statusPills,
      ],
    );
  }

  Widget _buildFilterPill(String label) {
    final isSelected = _selectedStatusFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AdminStyles.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AdminStyles.primary : AdminStyles.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AdminStyles.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<FacultyUserAccount> users) {
    return Container(
      decoration: AdminStyles.cardDecoration(borderRadius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: AdminStyles.bg.withValues(alpha: 0.6),
            child: Row(
              children: [
                Expanded(flex: 3, child: _tableHeaderTitle('Faculty Member')),
                Expanded(flex: 3, child: _tableHeaderTitle('Email Address', align: TextAlign.center)),
                Expanded(flex: 3, child: _tableHeaderTitle('Department', align: TextAlign.center)),
                SizedBox(width: 90, child: _tableHeaderTitle('Status', align: TextAlign.center)),
                const SizedBox(width: 16),
                SizedBox(width: 90, child: _tableHeaderTitle('Actions', align: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminStyles.border),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AdminStyles.border.withValues(alpha: 0.6),
            ),
            itemBuilder: (context, index) {
              final user = users[index];
              return _DesktopTableRow(
                user: user,
                initials: _getInitials(user.fullName),
                isStartingChat: _startingChatUserId == user.userId,
                onChat: () => _startChat(user),
                onView: () => _showFacultyDetails(user),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCards(List<FacultyUserAccount> users) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final hasDept = (user.department ?? '').trim().isNotEmpty &&
            user.department?.toLowerCase() != 'no department' &&
            user.department != '-';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminStyles.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name & Email + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AdminStyles.primary.withValues(alpha: 0.16),
                          AdminStyles.primary.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AdminStyles.primary.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(user.fullName),
                        style: const TextStyle(
                          color: AdminStyles.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminStyles.headingStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminStyles.bodyStyle(
                            fontSize: 12,
                            color: AdminStyles.textSecondary,
                          ),
                        ),
                        if ((user.employeeId ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${user.employeeId}',
                            style: AdminStyles.bodyStyle(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(user.isActive),
                ],
              ),
              const SizedBox(height: 10),

              // Department info chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: hasDept
                      ? AdminStyles.primary.withValues(alpha: 0.05)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: hasDept
                        ? AdminStyles.primary.withValues(alpha: 0.15)
                        : const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasDept ? Icons.school_outlined : Icons.help_outline_rounded,
                      size: 14,
                      color: hasDept ? AdminStyles.primary : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hasDept ? user.department! : 'No Department (Unassigned)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasDept ? AdminStyles.primary : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Action buttons row: View Details & Message
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showFacultyDetails(user),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text(
                        'View Details',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startingChatUserId == user.userId ? null : () => _startChat(user),
                      icon: _startingChatUserId == user.userId
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      label: const Text(
                        'Message',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminStyles.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: AdminStyles.cardDecoration(borderRadius: 18),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AdminStyles.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 32,
              color: AdminStyles.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No faculty members found',
            style: AdminStyles.headingStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search criteria or filter options.',
            style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderTitle(String title, {TextAlign align = TextAlign.left}) {
    return Text(
      title.toUpperCase(),
      textAlign: align,
      style: AdminStyles.headingStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AdminStyles.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget _buildStatusBadge(bool isActive) {
    final color = isActive ? AdminStyles.success : const Color(0xFF94A3B8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDepartmentBadge(String? dept, bool hasDept) {
    if (hasDept) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AdminStyles.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AdminStyles.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_rounded, size: 14, color: AdminStyles.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                dept!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminStyles.bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminStyles.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AdminStyles.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminStyles.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline_rounded, size: 14, color: AdminStyles.warning),
          const SizedBox(width: 6),
          Text(
            'No Department (Unassigned)',
            style: AdminStyles.bodyStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AdminStyles.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTableRow extends StatefulWidget {
  final FacultyUserAccount user;
  final String initials;
  final bool isStartingChat;
  final VoidCallback onChat;
  final VoidCallback onView;

  const _DesktopTableRow({
    required this.user,
    required this.initials,
    required this.isStartingChat,
    required this.onChat,
    required this.onView,
  });

  @override
  State<_DesktopTableRow> createState() => _DesktopTableRowState();
}

class _DesktopTableRowState extends State<_DesktopTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasDept = (widget.user.department ?? '').trim().isNotEmpty &&
        widget.user.department?.toLowerCase() != 'no department' &&
        widget.user.department != '-';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered ? AdminStyles.primary.withValues(alpha: 0.03) : Colors.white,
          border: Border(
            left: BorderSide(
              color: _isHovered ? AdminStyles.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Faculty Member Name & Avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AdminStyles.primary.withValues(alpha: 0.12),
                    child: Text(
                      widget.initials,
                      style: const TextStyle(
                        color: AdminStyles.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminStyles.bodyStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AdminStyles.textPrimary,
                          ),
                        ),
                        if (widget.user.employeeId != null && widget.user.employeeId!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'ID: ${widget.user.employeeId}',
                              style: AdminStyles.bodyStyle(
                                fontSize: 11,
                                color: AdminStyles.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Email (Centered)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Department (Centered)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.center,
                  child: _AdminUsersWebState._buildDepartmentBadge(widget.user.department, hasDept),
                ),
              ),
            ),
            // Status
            SizedBox(
              width: 90,
              child: Center(
                child: _AdminUsersWebState._buildStatusBadge(widget.user.isActive),
              ),
            ),
            const SizedBox(width: 16),
            // Actions
            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    tooltip: 'Send Message',
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AdminStyles.primary,
                    hoverBg: AdminStyles.primary.withValues(alpha: 0.1),
                    isLoading: widget.isStartingChat,
                    onTap: widget.onChat,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    tooltip: 'View Details',
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                    hoverBg: const Color(0xFFF1F5F9),
                    onTap: widget.onView,
                  ),
                ],
              ),
            ),
          ],
        ),
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminStyles.border.withValues(alpha: 0.8)),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  )
                : Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}
