import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../admin/shared/admin_styles.dart';

class TeacherLogsWeb extends StatefulWidget {
  const TeacherLogsWeb({super.key});

  @override
  State<TeacherLogsWeb> createState() => _TeacherLogsWebState();
}

class _TeacherLogsWebState extends State<TeacherLogsWeb> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminStyles.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildFilters(),
            const SizedBox(height: 32),
            _buildLogsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity Logs', style: AdminStyles.headingStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text('Track your recent interactions and system updates.', style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary, fontSize: 16)),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: AdminStyles.cardDecoration(hasShadow: false, borderColor: AdminStyles.border),
            child: TextField(
              controller: _searchController,
              decoration: AdminStyles.searchInputDecoration(
                hintText: 'Search logs...',
                prefixIcon: Icons.search_rounded,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        _buildTab('All'),
        const SizedBox(width: 12),
        _buildTab('Submitted'),
        const SizedBox(width: 12),
        _buildTab('Updated'),
      ],
    );
  }

  Widget _buildTab(String label) {
    final isSelected = _selectedTab == label;
    return InkWell(
      onTap: () => setState(() => _selectedTab = label),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AdminStyles.primary : AdminStyles.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AdminStyles.primary : AdminStyles.border),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            color: isSelected ? Colors.white : AdminStyles.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsContent() {
    return Container(
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Recent History', style: AdminStyles.headingStyle(fontSize: 18)),
          ),
          Divider(height: 1, color: AdminStyles.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (context, index) => Divider(height: 1, color: AdminStyles.border),
            itemBuilder: (context, index) {
              final logs = [
                {'action': 'Work request submitted', 'desc': 'Room 101 - HVAC Issue', 'time': '2 hours ago', 'icon': Icons.assignment_rounded, 'color': AdminStyles.info},
                {'action': 'Work request updated', 'desc': 'Room 205 - Light Replacement', 'time': '1 day ago', 'icon': Icons.edit_rounded, 'color': AdminStyles.warning},
                {'action': 'Work request completed', 'desc': 'Room 301 - Door Lock', 'time': '3 days ago', 'icon': Icons.check_circle_rounded, 'color': AdminStyles.success},
                {'action': 'Profile updated', 'desc': 'Changed contact information', 'time': '1 week ago', 'icon': Icons.person_rounded, 'color': AdminStyles.primary},
              ];
              final log = logs[index];
              return _buildLogItem(log['action'] as String, log['desc'] as String, log['time'] as String, log['icon'] as IconData, log['color'] as Color);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(String action, String description, String timeAgo, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: AdminStyles.headingStyle(fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: AdminStyles.bodyStyle(color: AdminStyles.textSecondary)),
              ],
            ),
          ),
          Text(timeAgo, style: AdminStyles.bodyStyle(color: AdminStyles.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
