import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import 'admin_work_process_web.dart';
import '../admin_nav_controller.dart';

class MaintenanceHistoryPageWeb extends StatefulWidget {
  const MaintenanceHistoryPageWeb({super.key});

  @override
  State<MaintenanceHistoryPageWeb> createState() => _MaintenanceHistoryPageWebState();
}

class _MaintenanceHistoryPageWebState extends State<MaintenanceHistoryPageWeb> {
  final TextEditingController _searchController = TextEditingController();

  List<WorkRequest> _historyItems = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _warningAmber = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _darkText = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    try {
      final data = await WorkRequestService.fetchAll();
      if (!mounted) return;
      setState(() {
        _historyItems = data.where((item) {
          final status = item.status.toLowerCase();
          return status == 'completed' || status == 'cancelled';
        }).toList()
          ..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyItems = [];
        _isLoading = false;
      });
    }
  }

  List<WorkRequest> get _filteredItems {
    var filtered = List<WorkRequest>.from(_historyItems);

    if (_selectedFilter == 'Completed') {
      filtered = filtered.where((item) => item.status.toLowerCase() == 'completed').toList();
    } else if (_selectedFilter == 'Declined') {
      filtered = filtered.where((item) => item.status.toLowerCase() == 'cancelled').toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((item) {
        final buildingName = (item.buildingName ?? '').toLowerCase();
        final officeRoom = (item.officeRoom ?? '').toLowerCase();
        return item.id.toLowerCase().contains(query) ||
            item.title.toLowerCase().contains(query) ||
            item.requestorName.toLowerCase().contains(query) ||
            buildingName.contains(query) ||
            officeRoom.contains(query);
      }).toList();
    }

    return filtered;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _successGreen;
      case 'cancelled':
        return _dangerRed;
      default:
        return _subtleText;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'DECLINED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final completedCount = _historyItems.where((item) => item.status.toLowerCase() == 'completed').length;
    final declinedCount = _historyItems.where((item) => item.status.toLowerCase() == 'cancelled').length;

    return Material(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Maintenance History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Completed and declined requests from database records',
                style: TextStyle(fontSize: 14, color: _subtleText),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TopStat(title: 'Total Records', value: _historyItems.length.toString(), color: _primaryBlue),
                  const SizedBox(width: 12),
                  _TopStat(title: 'Completed', value: completedCount.toString(), color: _successGreen),
                  const SizedBox(width: 12),
                  _TopStat(title: 'Declined', value: declinedCount.toString(), color: _warningAmber),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by ID, title, requestor, or location...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
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
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completed',
                    isSelected: _selectedFilter == 'Completed',
                    onTap: () => setState(() => _selectedFilter = 'Completed'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Declined',
                    isSelected: _selectedFilter == 'Declined',
                    onTap: () => setState(() => _selectedFilter = 'Declined'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(
                              child: Text(
                                'No maintenance history found',
                                style: TextStyle(color: _subtleText),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) =>
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return InkWell(
                                onTap: () {
                                  final controller = AdminNavController.of(context);
                                  if (controller != null) {
                                    controller.openWorkProcess(item);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AdminWorkProcessWeb(request: item),
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        item.formattedId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _darkText,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(color: _darkText),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        item.requestorName,
                                        style: const TextStyle(color: _subtleText),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${item.officeRoom ?? '-'}, ${item.buildingName ?? '-'}',
                                        style: const TextStyle(color: _subtleText),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        DateFormat('MMM dd, yyyy').format(item.dateSubmitted),
                                        style: const TextStyle(color: _subtleText),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _statusColor(item.status).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(item.status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(item.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  static const Color _localSubtleText = Color(0xFF64748B);

  const _TopStat({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: _localSubtleText)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const chipPrimaryBlue = Color(0xFF3B82F6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? chipPrimaryBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
