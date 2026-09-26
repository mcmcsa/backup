import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/room_comparison_dialog.dart';
import 'package:intl/intl.dart';

class ArchivesPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const ArchivesPage({super.key, this.scaffoldKey});

  @override
  State<ArchivesPage> createState() => _ArchivesPageState();
}

class _ArchivesPageState extends State<ArchivesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<WorkRequest> _archivedRequests = [];
  bool _isLoading = true;
  StreamSubscription<void>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadArchives();
    _streamSub = WorkRequestService.onWorkRequestsChanged.listen((_) {
      if (mounted) _loadArchives();
    });
  }

  Future<void> _loadArchives() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      List<WorkRequest> data;
      if (user != null && user.id.isNotEmpty) {
        data = await WorkRequestService.fetchHistoryForUser(user.id);
      } else {
        data = [];
      }
      if (mounted) setState(() { _archivedRequests = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  List<WorkRequest> get _filteredArchives {
    List<WorkRequest> filtered = _archivedRequests;
    if (_selectedFilter == 'Approved') {
      filtered = filtered.where((r) {
        final s = r.status.toLowerCase();
        final dhs = r.deptHeadStatus.toLowerCase();
        return dhs == 'approved' || s.contains('approved');
      }).toList();
    } else if (_selectedFilter == 'Acknowledged') {
      filtered = filtered.where((r) {
        final s = r.status.toLowerCase();
        final dhs = r.deptHeadStatus.toLowerCase();
        return dhs == 'acknowledged' || s == 'acknowledged' || r.isAcknowledged;
      }).toList();
    } else if (_selectedFilter == 'Completed') {
      filtered = filtered.where((r) => r.status.toLowerCase().contains('completed')).toList();
    } else if (_selectedFilter == 'Declined') {
      filtered = filtered.where((r) {
        final s = r.status.toLowerCase();
        final dhs = r.deptHeadStatus.toLowerCase();
        return (s.contains('declined') || dhs == 'declined') && !r.isCancelled;
      }).toList();
    } else if (_selectedFilter == 'Canceled') {
      filtered = filtered.where((r) {
        final s = r.status.toLowerCase();
        return r.isCancelled || s.contains('cancelled') || s.contains('canceled');
      }).toList();
    }
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered.where((r) =>
        r.id.toLowerCase().contains(query) ||
        r.formattedId.toLowerCase().contains(query) ||
        (r.officeRoom?.toLowerCase().contains(query) ?? false) ||
        (r.roomName?.toLowerCase().contains(query) ?? false) ||
        (r.buildingName?.toLowerCase().contains(query) ?? false) ||
        r.title.toLowerCase().contains(query) ||
        r.requestorName.toLowerCase().contains(query)
      ).toList();
    }
    return filtered;
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.appBarIconColor, size: 24),
          onPressed: () {
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.go(teacherDashboardRoute);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: themeProvider.appBarTextColor,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: 'Search request history...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade400, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  borderSide: BorderSide(color: Color(0xFF4169E1), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', themeProvider),
                const SizedBox(width: 8),
                _buildFilterChip('Approved', themeProvider),
                const SizedBox(width: 8),
                _buildFilterChip('Acknowledged', themeProvider),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', themeProvider),
                const SizedBox(width: 8),
                _buildFilterChip('Declined', themeProvider),
                const SizedBox(width: 8),
                _buildFilterChip('Canceled', themeProvider),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Archives List
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredArchives.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 48, color: themeProvider.subtitleColor),
                        const SizedBox(height: 12),
                        Text('No request history found', style: TextStyle(color: themeProvider.subtitleColor)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredArchives.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = _filteredArchives[index];
                      final user = context.read<AuthService>().currentUser;
                      final s = r.status.toLowerCase();
                      final dhs = r.deptHeadStatus.toLowerCase();
                      final isHeadEval = user != null && r.deptHeadId == user.id;

                      String statusLabel;
                      Color statusColor;

                      if (r.isCancelled || s == 'cancelled' || s == 'canceled') {
                        statusLabel = 'CANCELED';
                        statusColor = const Color(0xFFEF4444);
                      } else if (dhs == 'acknowledged' || s == 'acknowledged' || r.isAcknowledged) {
                        statusLabel = isHeadEval ? 'ACKNOWLEDGED BY YOU' : 'ACKNOWLEDGED';
                        statusColor = const Color(0xFF0F766E);
                      } else if (s == 'completed') {
                        statusLabel = 'COMPLETED';
                        statusColor = const Color(0xFF4CAF50);
                      } else if (dhs == 'approved') {
                        statusLabel = isHeadEval ? 'APPROVED BY YOU' : 'HEAD APPROVED';
                        statusColor = const Color(0xFF0284C7);
                      } else if (s == 'declined' || dhs == 'declined') {
                        statusLabel = 'DECLINED';
                        statusColor = Colors.red;
                      } else {
                        statusLabel = r.status.toUpperCase();
                        statusColor = const Color(0xFF0F766E);
                      }

                      final loc = '${r.roomName ?? r.officeRoom ?? "N/A"}${r.buildingName != null && r.buildingName!.isNotEmpty ? ", ${r.buildingName}" : ""}';

                      return _buildArchiveCard(
                        request: r,
                        trackingNumber: r.formattedId.isNotEmpty ? r.formattedId : r.id,
                        title: r.title,
                        location: loc,
                        date: DateFormat('MMM dd, yyyy').format(r.deptHeadApprovedDate ?? r.dateSubmitted),
                        status: statusLabel,
                        statusColor: statusColor,
                        themeProvider: themeProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleArchiveTap(WorkRequest request) async {
    context.push(
      '/request-details',
      extra: {
        'trackingNumber': request.id,
        'status': request.status,
        'request': request,
      },
    );
  }

  Widget _buildFilterChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BFA5) : themeProvider.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BFA5) : themeProvider.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : themeProvider.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveCard({
    required WorkRequest request,
    required String trackingNumber,
    required String title,
    required String location,
    required String date,
    required String status,
    required Color statusColor,
    required ThemeProvider themeProvider,
  }) {
    final shortTrack = trackingNumber.trim().length > 8
        ? '#${trackingNumber.trim().substring(0, 8).toUpperCase()}'
        : '#${trackingNumber.trim().toUpperCase()}';

    return Material(
      color: themeProvider.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _handleArchiveTap(request),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeProvider.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      shortTrack,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        icon: Icon(Icons.more_vert, size: 18, color: themeProvider.subtitleColor),
                        onSelected: (val) {
                          if (val == 'view') {
                            _handleArchiveTap(request);
                          } else if (val == 'compare' && request.roomId != null && request.roomId!.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (context) => RoomComparisonDialog(roomId: request.roomId!),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('View Details', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          if (request.roomId != null && request.roomId!.isNotEmpty)
                            const PopupMenuItem(
                              value: 'compare',
                              child: Row(
                              children: [
                                Icon(Icons.difference_outlined, size: 16, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Compare Room', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: themeProvider.subtitleColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.subtitleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: themeProvider.subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
