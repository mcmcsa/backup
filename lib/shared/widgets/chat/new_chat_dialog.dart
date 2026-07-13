import 'package:flutter/material.dart';
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
    'admin': Color(0xFF0369A1),
    'campadmin': Color(0xFF0369A1),
    'teacher': Color(0xFF7C3AED),
    'maintenance': Color(0xFF0F766E),
  };

  static const Map<String, String> _roleLabels = {
    'admin': 'Administrator',
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
      if (mounted) {
        setState(() {
          _users = users;
          _filtered = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users
              .where((u) =>
                  (u['name'] as String? ?? '').toLowerCase().contains(q) ||
                  (u['email'] as String? ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Flexible(child: _buildUserList()),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF0F766E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Conversation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF134E4A),
                  ),
                ),
                Text(
                  'Select a person to message',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search by name or email…',
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0F766E).withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.3))
                : null,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF134E4A),
              ),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: isSelected
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF0F766E),
                    size: 22,
                  )
                : null,
            onTap: () => setState(() =>
                _selectedUserId = isSelected ? null : id),
          ),
        );
      },
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedUserId == null
                  ? null
                  : () {
                      final user = _users.firstWhere(
                          (u) => u['id'] == _selectedUserId);
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Start Chat',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
