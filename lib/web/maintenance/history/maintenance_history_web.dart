import 'package:flutter/material.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/work_request_model.dart';

class MaintenanceHistoryWeb extends StatefulWidget {
  const MaintenanceHistoryWeb({super.key});

  @override
  State<MaintenanceHistoryWeb> createState() => _MaintenanceHistoryWebState();
}

class _MaintenanceHistoryWebState extends State<MaintenanceHistoryWeb> {
  List<WorkRequest> _history = [];
  bool _isLoading = true;
  final String _selectedStatus = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Professional color palette
  static const Color _primarySky = Color(0xFF0EA5E9);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _warningOrange = Color(0xFFF59E0B);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _pageBg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await WorkRequestService.fetchAll();
      // Filter for completed tasks
      final completed = data.where((r) => r.status == 'completed').toList();
      
      if (mounted) {
        setState(() {
          _history = completed;
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

  List<WorkRequest> get _filteredHistory {
    List<WorkRequest> filtered = _history;
    
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

            // Search
            _buildSearchBar(),
            const SizedBox(height: 32),

            // History List
            _buildHistoryList(),
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
          'Task History',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _darkText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'View all completed work requests and task history.',
          style: TextStyle(
            fontSize: 15,
            color: _subtleText.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
    );
  }

  Widget _buildHistoryList() {
    final filtered = _filteredHistory;

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
              Icons.history_rounded,
              size: 48,
              color: _subtleText.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No history found',
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

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = filtered[index];
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _successGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          task.roomName ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            color: _subtleText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '• ${task.id.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _subtleText.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                (task.dateCompleted ?? task.dateSubmitted)
                    .toString()
                    .split(' ')[0],
                style: TextStyle(
                  fontSize: 12,
                  color: _subtleText.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
