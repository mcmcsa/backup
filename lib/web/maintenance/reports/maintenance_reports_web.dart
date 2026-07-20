import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';

class MaintenanceReportsWeb extends StatefulWidget {
  const MaintenanceReportsWeb({super.key});

  @override
  State<MaintenanceReportsWeb> createState() => _MaintenanceReportsWebState();
}

class _MaintenanceReportsWebState extends State<MaintenanceReportsWeb> {
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Professional color palette
  static const Color _primarySky = Color(0xFF0EA5E9);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _infoBlue = Color(0xFF3B82F6);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      // For maintenance, fetch all requests (not filtered by user)
      final data = await WorkRequestService.fetchAll();
      if (mounted) {
        setState(() {
          _requests = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<WorkRequest> get _filteredRequests {
    List<WorkRequest> filtered = _requests;
    
    if (_selectedFilter == 'Pending') {
      filtered = filtered.where((r) => r.status == 'pending').toList();
    } else if (_selectedFilter == 'In Progress') {
      filtered = filtered
          .where((r) => r.status == 'in_progress' || r.status == 'under_maintenance')
          .toList();
    } else if (_selectedFilter == 'Completed') {
      filtered = filtered.where((r) => r.status == 'completed').toList();
    } else if (_selectedFilter == 'High Priority') {
      filtered = filtered.where((r) => r.priority == 'high').toList();
    }
    
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.id.toLowerCase().contains(query) ||
              (r.roomName?.toLowerCase().contains(query) ?? false) ||
              r.title.toLowerCase().contains(query))
          .toList();
    }
    
    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _successGreen;
      case 'in_progress':
      case 'under_maintenance':
        return _infoBlue;
      case 'pending':
        return _warningOrange;
      default:
        return _subtleText;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: _pageBg,
        child: const Center(
          child: CircularProgressIndicator(color: _primarySky),
        ),
      );
    }

    return Container(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // Search and Filter
            _buildSearchAndFilter(),
            const SizedBox(height: 32),

            // Reports List
            _buildReportsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Work Reports',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _darkText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'View all work requests assigned to maintenance staff.',
          style: TextStyle(
            fontSize: 15,
            color: _subtleText.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by tracking number or room...',
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
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Filter Buttons
        Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 12),
            _buildFilterChip('Pending'),
            const SizedBox(width: 12),
            _buildFilterChip('In Progress'),
            const SizedBox(width: 12),
            _buildFilterChip('Completed'),
            const SizedBox(width: 12),
            _buildFilterChip('High Priority'),
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
          color: isSelected ? _primarySky : _cardBg,
          border: Border.all(
            color: isSelected ? _primarySky : _borderColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _darkText,
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    final filtered = _filteredRequests;

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 48,
              color: _subtleText.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No reports found',
              style: TextStyle(
                fontSize: 16,
                color: _subtleText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border.all(color: _borderColor),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Tracking #',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Title',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Room',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Status',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _darkText,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ...filtered.asMap().entries.map((entry) {
          final index = entry.key;
          final request = entry.value;
          final isLast = index == filtered.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border(
                left: BorderSide(color: _borderColor),
                right: BorderSide(color: _borderColor),
                bottom: BorderSide(
                  color: isLast ? _borderColor : _borderColor.withValues(alpha: 0.5),
                ),
              ),
              borderRadius: isLast
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    )
                  : BorderRadius.zero,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    request.id.substring(0, 8),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _darkText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _darkText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    request.roomName ?? 'N/A',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _subtleText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(request.status),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
