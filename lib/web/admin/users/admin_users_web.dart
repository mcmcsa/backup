import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/faculty_user_service.dart';
import '../../../shared/services/chat_service.dart';
import '../shared/admin_styles.dart';
import '../admin_main_navigation_web.dart';
import '../admin_nav_controller.dart';

class AdminUsersWeb extends StatefulWidget {
  const AdminUsersWeb({super.key});

  @override
  State<AdminUsersWeb> createState() => _AdminUsersWebState();
}

class _AdminUsersWebState extends State<AdminUsersWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  // Mapping local colors to AdminStyles
  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _successGreen = AdminStyles.success;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;
  static const Color _borderColor = AdminStyles.border;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await FacultyUserService.fetchAllFacultyUsers();

      if (!mounted) return;

      final mapped = users.map((user) {
        return {
          'id': user.userId,
          'name': user.fullName,
          'email': user.email,
          'department': user.department ?? '-',
          'status': user.isActive ? 'Active' : 'Inactive',
        };
      }).toList();

      setState(() {
        _users = mapped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading faculty users: $e');
      if (!mounted) return;
      setState(() {
        _users = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _users;
    return _users
        .where((u) =>
            u['name'].toLowerCase().contains(query) ||
            u['email'].toLowerCase().contains(query) ||
            u['department'].toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            SizedBox(height: isMobile ? 20 : 24),

            // Search and Add button
            _buildSearchAndActions(isMobile),
            SizedBox(height: isMobile ? 20 : 32),

            // Users Table
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: _primaryBlue))
            else
              _buildUsersTable(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users Management',
          style: AdminStyles.headingStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage faculty and staff accounts.',
          style: AdminStyles.bodyStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndActions(bool isMobile) {
    final searchField = Container(
      width: isMobile ? double.infinity : 350,
      height: 48,
      decoration: AdminStyles.cardDecoration(borderRadius: 14),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search users by name or email...',
          hintStyle: AdminStyles.bodyStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );

    return searchField;
  }

  Widget _buildUsersTable(bool isMobile) {
    final filtered = _filteredUsers;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: AdminStyles.cardDecoration(),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: _subtleText.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'No users found',
              style: AdminStyles.bodyStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = filtered[index];
          final statusColor = user['status'] == 'Active' ? AdminStyles.success : AdminStyles.textMuted;
          return Container(
            decoration: AdminStyles.cardDecoration(borderRadius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        user['name'],
                        style: AdminStyles.bodyStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AdminStyles.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: AdminStyles.pillDecoration(color: statusColor, isSecondary: true),
                      child: Text(
                        user['status'].toUpperCase(),
                        style: AdminStyles.headingStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  user['email'],
                  style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dept: ${user['department']}',
                      style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AdminStyles.primary),
                      onPressed: () async {
                        final currentUser = context.read<AuthService>().currentUser;
                        if (currentUser == null) return;
                        
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (c) => const Center(child: CircularProgressIndicator(color: AdminStyles.primary)),
                        );

                        try {
                          final room = await ChatService.findOrCreateDirectRoom(
                            currentUserId: currentUser.id,
                            currentUserName: currentUser.name,
                            currentUserRole: currentUser.role.name,
                            otherUserId: user['id'],
                            otherUserName: user['name'],
                            otherUserRole: 'teacher',
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          AdminNavController.of(context)?.navigateTo(AdminMainNavigationWeb.chatIndex, chatRoom: room);
                        } catch (e) {
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    return Container(
      decoration: AdminStyles.cardDecoration(borderRadius: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 800,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: AdminStyles.bg.withValues(alpha: 0.5),
                  border: Border(bottom: BorderSide(color: _borderColor)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildTableHeader('Full Name')),
                    Expanded(flex: 2, child: _buildTableHeader('Email Address', align: TextAlign.center)),
                    Expanded(flex: 1, child: _buildTableHeader('Department', align: TextAlign.center)),
                    Expanded(flex: 1, child: _buildTableHeader('Status', align: TextAlign.center)),
                    SizedBox(width: 60, child: _buildTableHeader('Action', align: TextAlign.center)),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: _borderColor.withValues(alpha: 0.5)),
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  return _UserTableRow(user: user);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String title, {TextAlign align = TextAlign.left}) {
    return Text(
      title.toUpperCase(),
      textAlign: align,
      style: AdminStyles.headingStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _subtleText),
    );
  }
}

class _UserTableRow extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserTableRow({required this.user});

  @override
  State<_UserTableRow> createState() => _UserTableRowState();
}

class _UserTableRowState extends State<_UserTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.user['status'] == 'Active' ? AdminStyles.success : AdminStyles.textMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            Expanded(
              flex: 2,
              child: Text(
                widget.user['name'],
                style: AdminStyles.bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AdminStyles.textPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                widget.user['email'],
                textAlign: TextAlign.center,
                style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                widget.user['department'],
                textAlign: TextAlign.center,
                style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: AdminStyles.pillDecoration(color: statusColor, isSecondary: true),
                  child: Text(
                    widget.user['status'].toUpperCase(),
                    style: AdminStyles.headingStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AdminStyles.primary),
                  onPressed: () async {
                    final currentUser = context.read<AuthService>().currentUser;
                    if (currentUser == null) return;
                    
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => const Center(child: CircularProgressIndicator(color: AdminStyles.primary)),
                    );

                    try {
                      final room = await ChatService.findOrCreateDirectRoom(
                        currentUserId: currentUser.id,
                        currentUserName: currentUser.name,
                        currentUserRole: currentUser.role.name,
                        otherUserId: widget.user['id'],
                        otherUserName: widget.user['name'],
                        otherUserRole: 'teacher',
                      );
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      AdminNavController.of(context)?.navigateTo(AdminMainNavigationWeb.chatIndex, chatRoom: room);
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
