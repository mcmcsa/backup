import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../shared/admin_styles.dart';

class AdminWorkRequestsWeb extends StatefulWidget {
  const AdminWorkRequestsWeb({super.key});

  @override
  State<AdminWorkRequestsWeb> createState() => _AdminWorkRequestsWebState();
}

class _AdminWorkRequestsWebState extends State<AdminWorkRequestsWeb> {
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Mapping local colors to AdminStyles
  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _successGreen = AdminStyles.success;
  static const Color _warningOrange = AdminStyles.warning;
  static const Color _infoBlue = AdminStyles.info;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;
  static const Color _cardBg = AdminStyles.surface;
  static const Color _borderColor = AdminStyles.border;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredRequests {
    List<WorkRequest> filtered = _requests;
    if (_selectedFilter == 'Pending') {
      filtered = filtered.where((r) => r.status == 'pending').toList();
    } else if (_selectedFilter == 'In Progress') {
      filtered = filtered.where((r) => r.status == 'in_progress' || r.status == 'under_maintenance').toList();
    } else if (_selectedFilter == 'Completed') {
      filtered = filtered.where((r) => r.status == 'completed').toList();
    }
    
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((r) => r.id.toLowerCase().contains(query) || r.title.toLowerCase().contains(query)).toList();
    }
    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return _successGreen;
      case 'in_progress': case 'under_maintenance': return _infoBlue;
      case 'pending': return _warningOrange;
      default: return _subtleText;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSearchAndFilter(),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: _primaryBlue))
            else
              _buildRequestsTable(),
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
          'Work Requests',
          style: AdminStyles.headingStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage all work requests across the system.',
          style: AdminStyles.bodyStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminStyles.border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by tracking number or title...',
              hintStyle: AdminStyles.bodyStyle(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 12),
            _buildFilterChip('Pending'),
            const SizedBox(width: 12),
            _buildFilterChip('In Progress'),
            const SizedBox(width: 12),
            _buildFilterChip('Completed'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue : _cardBg,
          border: Border.all(color: isSelected ? _primaryBlue : _borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : _darkText)),
      ),
    );
  }

  Widget _buildRequestsTable() {
    final filtered = _filteredRequests;
    if (filtered.isEmpty) {
      return Center(child: Text('No requests found', style: TextStyle(color: _subtleText)));
    }

    return Container(
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
            child: Row(
              children: [
                Expanded(flex: 1, child: _buildTableHeader('Tracking #')),
                Expanded(flex: 2, child: _buildTableHeader('Title')),
                Expanded(flex: 1, child: _buildTableHeader('Room')),
                Expanded(flex: 1, child: _buildTableHeader('Status')),
                Expanded(flex: 1, child: _buildTableHeader('Priority')),
              ],
            ),
          ),
          ...filtered.asMap().entries.map((entry) {
            final isLast = entry.key == filtered.length - 1;
            final req = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text(req.id.substring(0, 8).toUpperCase(), style: AdminStyles.dataStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _darkText))),
                      Expanded(flex: 2, child: Text(req.title, style: AdminStyles.bodyStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _darkText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(flex: 1, child: Text(req.roomName ?? 'N/A', style: AdminStyles.bodyStyle(fontSize: 13, color: _subtleText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _getStatusColor(req.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(req.status.replaceAll('_', ' ').toUpperCase(), style: AdminStyles.headingStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _getStatusColor(req.status)), textAlign: TextAlign.center),
                        ),
                      ),
                      Expanded(flex: 1, child: Text(req.priority, style: AdminStyles.bodyStyle(fontSize: 13, color: _subtleText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                if (!isLast) Divider(height: 1, color: _borderColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Text(title, style: AdminStyles.headingStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _darkText));
  }
}
