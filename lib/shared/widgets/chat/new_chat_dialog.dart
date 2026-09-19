import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/chat_service.dart';

class NewChatDialog extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final void Function(
    String otherUserId,
    String otherUserName,
    String otherUserRole,
    String? workRequestId,
  ) onStartChat;

  const NewChatDialog({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.onStartChat,
  });

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedUserId;
  String? _workRequestId;

  static const Map<String, Color> _roleColors = {
    'campadmin': Color(0xFF0284C7),
    'teacher': Color(0xFF8B5CF6),
    'maintenance': Color(0xFF0F766E),
  };

  static const Map<String, String> _roleLabels = {
    'campadmin': 'Campus Admin',
    'teacher': 'Faculty',
    'maintenance': 'Maintenance',
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ChatService.fetchEligibleUsers(
        currentUserId: widget.currentUserId,
        currentUserRole: widget.currentUserRole,
      );

      // Filter out System Administrator entirely
      final eligible = users.where((u) {
        final role = (u['role'] as String? ?? '').toLowerCase();
        final name = (u['name'] as String? ?? '').toLowerCase();
        if (role == 'admin' || name.contains('system admin')) {
          return false;
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _users = eligible;
          _filtered = eligible;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              final name = (u['name'] as String? ?? '').toLowerCase();
              final email = (u['email'] as String? ?? '').toLowerCase();
              final role = (u['role'] as String? ?? '').toLowerCase();
              final roleLabel = (_roleLabels[role] ?? '').toLowerCase();
              return name.contains(q) ||
                  email.contains(q) ||
                  role.contains(q) ||
                  roleLabel.contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Dialog(
      backgroundColor: themeProvider.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? themeProvider.borderColor : Colors.transparent,
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(themeProvider, isDark),
            _buildSearchBar(themeProvider, isDark),
            const SizedBox(height: 6),
            Flexible(child: _buildUserList(themeProvider, isDark)),
            _buildActions(themeProvider, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F766E).withValues(alpha: 0.25)
                  : const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Conversation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a person to message',
                  style: TextStyle(
                    fontSize: 12,
                    color: themeProvider.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            color: themeProvider.subtitleColor,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeProvider themeProvider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? themeProvider.inputFillColor
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? themeProvider.inputBorderColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by name or email…',
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: themeProvider.subtitleColor,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            hintStyle: TextStyle(
              fontSize: 13,
              color: themeProvider.subtitleColor,
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            color: themeProvider.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(ThemeProvider themeProvider, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CircularProgressIndicator(
            color: const Color(0xFF0F766E),
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded, size: 36, color: themeProvider.subtitleColor),
              const SizedBox(height: 8),
              Text(
                'No eligible users found',
                style: TextStyle(
                  color: themeProvider.subtitleColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final user = _filtered[i];
        final id = user['id'] as String;
        final name = user['name'] as String? ?? 'Unknown';
        final email = user['email'] as String? ?? '';
        final role = user['role'] as String? ?? 'teacher';
        final isSelected = _selectedUserId == id;
        final roleColor = _roleColors[role] ?? const Color(0xFF0F766E);
        final roleLabel = _roleLabels[role] ?? role;

        final itemBg = isSelected
            ? (isDark
                ? const Color(0xFF0F766E).withValues(alpha: 0.22)
                : const Color(0xFF0F766E).withValues(alpha: 0.08))
            : (isDark
                ? const Color(0xFF242424)
                : const Color(0xFFF8FAFC));

        final itemBorder = isSelected
            ? const Color(0xFF0F766E)
            : (isDark
                ? themeProvider.borderColor.withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0));

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: itemBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedUserId = isSelected ? null : id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? roleColor.withValues(alpha: 0.22)
                            : roleColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF5EEAD4) : roleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name & Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: themeProvider.textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? roleColor.withValues(alpha: 0.22)
                                      : roleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? const Color(0xFF5EEAD4)
                                        : roleColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: themeProvider.subtitleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Selection indicator
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0F766E)
                              : (isDark ? Colors.grey.shade600 : const Color(0xFFCBD5E1)),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(ThemeProvider themeProvider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: themeProvider.textColor,
                side: BorderSide(
                  color: isDark ? themeProvider.borderColor : const Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedUserId == null
                  ? null
                  : () {
                      final user = _users.firstWhere(
                        (u) => u['id'] == _selectedUserId,
                      );
                      Navigator.pop(context);
                      widget.onStartChat(
                        user['id'] as String,
                        user['name'] as String? ?? 'Unknown',
                        user['role'] as String? ?? 'teacher',
                        _workRequestId,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                disabledForegroundColor:
                    isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text(
                'Start Chat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
