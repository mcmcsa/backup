import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/admin_styles.dart';
import 'package:provider/provider.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/chat_service.dart';
import '../admin_nav_controller.dart';

// ─────────────────────────────────────────────────────────────
// Unified user model — teacher, maintenance, campadmin
// ─────────────────────────────────────────────────────────────
class _AppUser {
  final String id;
  final String email;
  final String name;
  final String role;         // 'teacher' | 'maintenance' | 'campadmin'
  final String? employeeId;
  final String? department;
  final String? position;    // e.g. "Faculty", specialization, etc.
  final bool isActive;

  const _AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.employeeId,
    this.department,
    this.position,
    required this.isActive,
  });

  static const Map<String, Color> _roleColors = {
    'teacher': Color(0xFF7C3AED),
    'maintenance': Color(0xFF0F766E),
    'campadmin': Color(0xFF0369A1),
  };

  static const Map<String, String> _roleLabels = {
    'teacher': 'Faculty',
    'maintenance': 'Maintenance',
    'campadmin': 'Campus Admin',
  };

  Color get roleColor => _roleColors[role] ?? AdminStyles.primary;
  String get roleLabel => _roleLabels[role] ?? role;
}

// ─────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────
class UsersPageWeb extends StatefulWidget {
  const UsersPageWeb({super.key});

  @override
  State<UsersPageWeb> createState() => _UsersPageWebState();
}

class _UsersPageWebState extends State<UsersPageWeb> {
  final TextEditingController _searchController = TextEditingController();
  List<_AppUser> _users = [];
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
        .channel('campus_admin_all_users_sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            if (mounted) _loadUsers();
          },
        )
        .subscribe();
  }

  String? _errorMessage;

  Future<void> _loadUsers() async {
    try {
      final db = Supabase.instance.client;

      // Fetch only teacher users
      final raw = await db
          .from('users')
          .select(
            'id, email, name, role, is_active, '
            'teacher_users(employee_id, position, departments(name))'
          )
          .eq('role', 'teacher')
          .order('name', ascending: true);

      final users = (raw as List).map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final role = r['role'] as String? ?? 'teacher';

        String? empId, dept, position;

        if (role == 'teacher') {
          final tList = r['teacher_users'] as List?;
          final t = (tList != null && tList.isNotEmpty)
              ? tList.first as Map<String, dynamic>
              : null;
          empId = t?['employee_id']?.toString();
          position = t?['position']?.toString() ?? 'Faculty';
          final deptMap = t?['departments'] as Map?;
          dept = deptMap?['name']?.toString();
        }

        return _AppUser(
          id: r['id']?.toString() ?? '',
          email: r['email']?.toString() ?? '',
          name: r['name']?.toString() ?? 'Unknown',
          role: role,
          employeeId: empId,
          department: dept,
          position: position,
          isActive: r['is_active'] == true,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<_AppUser> get _filteredUsers {
    var list = _users;

    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((u) {
      final hay = '${u.name} ${u.email} ${u.employeeId ?? ''} '
          '${u.department ?? ''} ${u.position ?? ''} ${u.roleLabel}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _syncChannel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTableHeader(String title) {
    return Center(
      child: Text(
        title.toUpperCase(),
        textAlign: TextAlign.center,
        style: AdminStyles.bodyStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AdminStyles.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }



  InputDecoration _searchDecoration() {
    return InputDecoration(
      hintText: 'Search users...',
      hintStyle: AdminStyles.bodyStyle(
        fontSize: 13,
        color: AdminStyles.textMuted,
      ),
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 12, right: 8),
        child: Icon(Icons.search_rounded, color: AdminStyles.textMuted, size: 20),
      ),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 44, minHeight: 44),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AdminStyles.textMuted, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminStyles.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AdminStyles.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    );
  }

  Widget _buildMobileList(List<_AppUser> filtered) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = filtered[index];
        return _buildMobileCard(user);
      },
    );
  }

  Widget _buildMobileCard(_AppUser u) {
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
                  u.name,
                  style: AdminStyles.headingStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminStyles.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: AdminStyles.pillDecoration(
                  color: u.isActive ? AdminStyles.success : AdminStyles.warning,
                  isSecondary: true,
                ),
                child: Text(
                  u.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: AdminStyles.headingStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: u.isActive ? AdminStyles.success : AdminStyles.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            u.email,
            style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: u.roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  u.roleLabel.toUpperCase(),
                  style: AdminStyles.headingStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: u.roleColor,
                  ),
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      u.department ?? u.position ?? '—',
                      style: AdminStyles.bodyStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminStyles.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (u.employeeId != null)
                      Text(
                        'ID: ${u.employeeId}',
                        style: AdminStyles.bodyStyle(
                            fontSize: 10, color: AdminStyles.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final filtered = _filteredUsers;

        return Container(
          color: AdminStyles.bg,
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Users', style: AdminStyles.pageTitleStyle()),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          style: AdminStyles.bodyStyle(
                            fontSize: 13,
                            color: AdminStyles.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _searchDecoration(),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text('Users', style: AdminStyles.pageTitleStyle()),
                        const Spacer(),
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: AdminStyles.bodyStyle(
                              fontSize: 13,
                              color: AdminStyles.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _searchDecoration(),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 14),

              // ── User Count ───────────────────────────────
              Row(
                children: [
                  const Spacer(),
                  Text(
                    '${filtered.length} faculty member${filtered.length == 1 ? '' : 's'}',
                    style: AdminStyles.pageSubtitleStyle(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Table / Mobile List ───────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminStyles.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AdminStyles.error, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Error Loading Users',
                                      style: AdminStyles.headingStyle(fontSize: 16, color: AdminStyles.error),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.group_off_rounded,
                                          size: 48, color: AdminStyles.textMuted.withValues(alpha: 0.4)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No users found',
                                        style: AdminStyles.bodyStyle(
                                          fontSize: 14,
                                          color: AdminStyles.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : isMobile
                                  ? _buildMobileList(filtered)
                                  : Column(
                                      children: [
                                        // Table Header
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 14),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(color: AdminStyles.border)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 3, child: _buildTableHeader('User')),
                                              Expanded(flex: 2, child: _buildTableHeader('Role')),
                                              Expanded(flex: 2, child: _buildTableHeader('Details')),
                                              Expanded(flex: 1, child: _buildTableHeader('Status')),
                                              Expanded(flex: 1, child: _buildTableHeader('Action')),
                                            ],
                                          ),
                                        ),
                                        // Rows
                                        Expanded(
                                          child: ListView.separated(
                                            itemCount: filtered.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(height: 1, color: AdminStyles.border),
                                            itemBuilder: (context, index) {
                                              return _UserRow(user: filtered[index]);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Row widget
// ─────────────────────────────────────────────────────────────
class _UserRow extends StatefulWidget {
  final _AppUser user;
  const _UserRow({required this.user});

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _isHovered = false;
  bool _isStartingChat = false;

  Future<void> _startChat() async {
    setState(() => _isStartingChat = true);
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final room = await ChatService.findOrCreateDirectRoom(
        currentUserId: currentUser.id,
        currentUserName: currentUser.name,
        currentUserRole: currentUser.role.name,
        otherUserId: widget.user.id,
        otherUserName: widget.user.name,
        otherUserRole: widget.user.role,
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
        setState(() => _isStartingChat = false);
      }
    }
  }

  String _t(String? v, {String fallback = '—'}) {
    final s = (v ?? '').trim();
    return s.isEmpty ? fallback : s;
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: _isHovered
              ? u.roleColor.withValues(alpha: 0.03)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // ── User ────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: u.roleColor.withValues(alpha: 0.12),
                    child: Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: AdminStyles.headingStyle(
                        color: u.roleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
                          u.name,
                          style: AdminStyles.headingStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          u.email,
                          style: AdminStyles.bodyStyle(
                              fontSize: 12, color: AdminStyles.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Role badge ────────────────────────────────────
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: u.roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    u.roleLabel.toUpperCase(),
                    style: AdminStyles.headingStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: u.roleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            // ── Details (dept/position, empId) ────────────────
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _t(u.department ?? u.position),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminStyles.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (u.employeeId != null)
                    Text(
                      'ID: ${u.employeeId}',
                      textAlign: TextAlign.center,
                      style: AdminStyles.bodyStyle(
                          fontSize: 11, color: AdminStyles.textSecondary),
                    ),
                ],
              ),
            ),

            // ── Status ────────────────────────────────────────
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: AdminStyles.pillDecoration(
                    color: u.isActive ? AdminStyles.success : AdminStyles.warning,
                    isSecondary: true,
                  ),
                  child: Text(
                    u.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: AdminStyles.headingStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: u.isActive ? AdminStyles.success : AdminStyles.warning,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            // ── Action ────────────────────────────────────────
            Expanded(
              flex: 1,
              child: Center(
                child: _isStartingChat
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AdminStyles.primary),
                      )
                    : IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AdminStyles.primary),
                        onPressed: _startChat,
                        tooltip: 'Send message',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
