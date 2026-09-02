import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/models/work_request_model.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/services/duplicate_detection_service.dart';
import '../shared/admin_styles.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'admin_work_process_web.dart';

class TicketsPageWeb extends StatefulWidget {
  final void Function(WorkRequest)? onViewDetails;

  const TicketsPageWeb({
    super.key,
    this.onViewDetails,
  });

  @override
  State<TicketsPageWeb> createState() => _TicketsPageWebState();
}

class _TicketsPageWebState extends State<TicketsPageWeb>
    with WidgetsBindingObserver {
  int _selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  List<WorkRequest> _requests = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _autoRefreshTimer;
  int _loadSequence = 0;
  bool _isGridView = false;
  Set<String> _duplicateRequestIds = {};

  // Professional color palette mapping
  static const Color _primaryBlue = AdminStyles.primary;
  static const Color _successGreen = AdminStyles.success;
  static const Color _warningYellow = AdminStyles.warning;
  static const Color _darkText = AdminStyles.textPrimary;
  static const Color _subtleText = AdminStyles.textSecondary;
  static const Color _pageBg = AdminStyles.bg;

  final List<String> _filters = [
    'All Requests',
    'Pending',
    'In Progress',
    'Declined',
    'Confirmed',
    'Rework',
    'Completed',
    'Duplicates',
  ];

  StreamSubscription? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRequests();
    _setupRealtime();
    _startAutoRefresh();
  }

  void _setupRealtime() {
    _realtimeSubscription?.cancel();
    // Using the service's listenToAllWorkRequests which returns a RealtimeChannel
    // For simplicity in this widget, we'll just trigger _loadRequests when any change occurs
    WorkRequestService.listenToAllWorkRequests((updatedRequests) {
      if (mounted) {
        setState(() {
          _requests = updatedRequests;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRequests();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _realtimeSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests({bool isManualRefresh = false}) async {
    final currentSequence = ++_loadSequence;

    if (isManualRefresh && mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final data = await WorkRequestService.fetchAll();
      Set<String> duplicateIds = {};
      try {
        final groups = await DuplicateDetectionService.fetchPotentialDuplicateGroups();
        for (final group in groups) {
          for (final r in group) {
            duplicateIds.add(r.id);
          }
        }
      } catch (_) {}

      if (mounted && currentSequence == _loadSequence) {
        setState(() {
          _requests = data;
          _duplicateRequestIds = duplicateIds;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted && currentSequence == _loadSequence) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  List<WorkRequest> get _filteredRequests {
    final query = _searchController.text.toLowerCase();
    var requests = _requests;

    // Apply status filter
    if (_selectedFilter == 1) {
      requests = requests
          .where((r) => r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'pending assignment')
          .toList();
    } else if (_selectedFilter == 2) {
      requests = requests
          .where(
            (r) => r.status.toLowerCase() == 'in progress' ||
                r.status.toLowerCase() == 'in_progress' ||
                r.status.toLowerCase() == 'assigned' ||
                r.status.toLowerCase() == 'accepted by maintenance' ||
                r.status.toLowerCase() == 'pre-inspection submitted',
          )
          .toList();
    } else if (_selectedFilter == 3) {
      requests = requests
          .where((r) => r.status.toLowerCase() == 'declined' || r.status.toLowerCase() == 'cancelled' || r.status.toLowerCase() == 'declined/cancelled' || r.status.toLowerCase() == 'pre-inspection declined')
          .toList();
    } else if (_selectedFilter == 4) {
      requests = requests
          .where((r) => r.status.toLowerCase() == 'confirmed' || r.status.toLowerCase() == 'pre-inspection approved' || r.status.toLowerCase() == 'post-repair submitted' || r.status.toLowerCase() == 'in progress (post-repair)' || r.status.toLowerCase() == 'under_maintenance')
          .toList();
    } else if (_selectedFilter == 5) {
      requests = requests
          .where((r) => r.status.toLowerCase() == 'rework' || r.status.toLowerCase() == 'for rework' || r.status.toLowerCase() == 'under evaluation')
          .toList();
    } else if (_selectedFilter == 6) {
      requests = requests
          .where((r) => r.status.toLowerCase() == 'completed')
          .toList();
    } else if (_selectedFilter == 7) {
      requests = requests
          .where((r) => r.duplicateOfId != null)
          .toList();
    }

    // Apply search filter
    if (query.isNotEmpty) {
      requests = requests
          .where(
            (r) =>
                r.title.toLowerCase().contains(query) ||
                r.id.toLowerCase().contains(query) ||
                r.requestorName.toLowerCase().contains(query),
          )
          .toList();
    }

    return requests;
  }

  int _getCountByFilter(int filter) {
    switch (filter) {
      case 0:
        return _requests.length;
      case 1:
        return _requests
            .where((r) => r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'pending assignment')
            .length;
      case 2:
        return _requests
            .where(
              (r) => r.status.toLowerCase() == 'in progress' ||
                  r.status.toLowerCase() == 'in_progress' ||
                  r.status.toLowerCase() == 'assigned' ||
                  r.status.toLowerCase() == 'accepted by maintenance' ||
                  r.status.toLowerCase() == 'pre-inspection submitted',
            )
            .length;
      case 3:
        return _requests
            .where((r) => r.status.toLowerCase() == 'declined' || r.status.toLowerCase() == 'cancelled' || r.status.toLowerCase() == 'declined/cancelled' || r.status.toLowerCase() == 'pre-inspection declined')
            .length;
      case 4:
        return _requests
            .where((r) => r.status.toLowerCase() == 'confirmed' || r.status.toLowerCase() == 'pre-inspection approved' || r.status.toLowerCase() == 'post-repair submitted' || r.status.toLowerCase() == 'in progress (post-repair)' || r.status.toLowerCase() == 'under_maintenance')
            .length;
      case 5:
        return _requests
            .where((r) => r.status.toLowerCase() == 'rework' || r.status.toLowerCase() == 'for rework' || r.status.toLowerCase() == 'under evaluation')
            .length;
      case 6:
        return _requests
            .where((r) => r.status.toLowerCase() == 'completed')
            .length;
      case 7:
        return _requests
            .where((r) => r.duplicateOfId != null)
            .length;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        _loadRequests();
      },
      child: Container(
        color: _pageBg,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryBlue),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 780;
                  final isTablet = constraints.maxWidth >= 780 && constraints.maxWidth < 1200;

                  return SingleChildScrollView(
                    primary: true,
                    padding: EdgeInsets.all(isMobile ? 12 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page-level header
                        _buildPageHeader(isMobile: isMobile),
                        SizedBox(height: isMobile ? 14 : 20),
                        _buildMainCard(
                          isMobile: isMobile,
                          isTablet: isTablet,
                          maxWidth: constraints.maxWidth,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatsRow({
    required double maxWidth,
    required bool isMobile,
    required bool isTablet,
  }) {
    final cards = [
      _StatCard(
        title: 'All Requests',
        value: _getCountByFilter(0),
        icon: Icons.confirmation_num_rounded,
        iconColor: _primaryBlue,
        isSelected: _selectedFilter == 0,
        onTap: () => setState(() => _selectedFilter = 0),
      ),
      _StatCard(
        title: 'Pending',
        value: _getCountByFilter(1),
        icon: Icons.hourglass_empty_rounded,
        iconColor: _warningYellow,
        isSelected: _selectedFilter == 1,
        onTap: () => setState(() => _selectedFilter = 1),
      ),
      _StatCard(
        title: 'In Progress',
        value: _getCountByFilter(2),
        icon: Icons.build_rounded,
        iconColor: _primaryBlue,
        isSelected: _selectedFilter == 2,
        onTap: () => setState(() => _selectedFilter = 2),
      ),
      _StatCard(
        title: 'Under Maintenance',
        value: _getCountByFilter(3),
        icon: Icons.build_circle_rounded,
        iconColor: const Color(0xFFF97316),
        isSelected: _selectedFilter == 3,
        onTap: () => setState(() => _selectedFilter = 3),
      ),
      _StatCard(
        title: 'Completed',
        value: _getCountByFilter(4),
        icon: Icons.check_circle_rounded,
        iconColor: _successGreen,
        isSelected: _selectedFilter == 4,
        onTap: () => setState(() => _selectedFilter = 4),
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    if (isTablet) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(width: 216, child: cards[0]),
          SizedBox(width: 216, child: cards[1]),
          SizedBox(width: 216, child: cards[2]),
          SizedBox(width: 216, child: cards[3]),
          SizedBox(width: 216, child: cards[4]),
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Page-level header: "Work Request Management" + action buttons
  Widget _buildPageHeader({required bool isMobile}) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work Request Management',
            style: AdminStyles.headingStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildViewToggle(),
              const Spacer(),
              _buildCreateRequestButton(),
              const SizedBox(width: 8),
              _buildRefreshButton(),
            ],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Work Request Management',
          style: AdminStyles.headingStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _darkText,
          ),
        ),
        const Spacer(),
        _buildViewToggle(),
        const SizedBox(width: 10),
        _buildCreateRequestButton(),
        const SizedBox(width: 10),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildMainCard({
    required bool isMobile,
    required bool isTablet,
    required double maxWidth,
  }) {
    final filteredRequests = _filteredRequests;

    final Widget filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusFilterButton('All', 0),
          const SizedBox(width: 8),
          _buildStatusFilterButton('Pending', 1),
          const SizedBox(width: 8),
          _buildStatusFilterButton('In Progress', 2),
          const SizedBox(width: 8),
          _buildStatusFilterButton('Confirmed', 4),
          const SizedBox(width: 8),
          _buildStatusFilterButton('Rework', 5),
          const SizedBox(width: 8),
          _buildStatusFilterButton('Completed', 6),
          const SizedBox(width: 8),
          _buildStatusFilterButton('Declined', 3),
        ],
      ),
    );

    Widget headerContent;

    if (isMobile) {
      // Mobile: stacked — title + chips + search
      headerContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.confirmation_num_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tickets List', style: AdminStyles.headingStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkText)),
                  Text('${filteredRequests.length} tickets', style: AdminStyles.bodyStyle(fontSize: 12, color: _subtleText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          filterChips,
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: _buildSearchBar(width: double.infinity)),
        ],
      );
    } else {
      // Desktop / Tablet: title + count | filter chips | search bar — all in one row
      headerContent = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.confirmation_num_rounded, color: _primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tickets List', style: AdminStyles.headingStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _darkText)),
              Text('${filteredRequests.length} tickets', style: AdminStyles.bodyStyle(fontSize: 12, color: _subtleText)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(child: filterChips),
          const SizedBox(width: 16),
          SizedBox(width: 220, child: _buildSearchBar(width: 220)),
        ],
      );
    }

    return Container(
      decoration: AdminStyles.cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
            child: headerContent,
          ),

          // Grid/List of Ticket Cards
          filteredRequests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No tickets found',
                          style: AdminStyles.headingStyle(
                            fontSize: 18,
                            color: _subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 14 : 20, 0, isMobile ? 14 : 20, 20),
                  child: _isGridView
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 1400
                                ? 3
                                : constraints.maxWidth > 900
                                    ? 2
                                    : 1;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                                mainAxisExtent: 260,
                              ),
                              itemCount: filteredRequests.length,
                              itemBuilder: (context, index) {
                                return _TicketCard(
                                  request: filteredRequests[index],
                                  onViewDetails: widget.onViewDetails,
                                );
                              },
                            );
                          },
                        )
                      : _buildTicketsTable(filteredRequests),
                ),
        ],
      ),
    );
  }

  Widget _buildTicketsTable(List<WorkRequest> filtered) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: _buildTableHeader('Ticket ID')),
                        Expanded(flex: 2, child: _buildTableHeader('Requestor')),
                        Expanded(flex: 2, child: _buildTableHeader('Title / Issue')),
                        Expanded(flex: 2, child: _buildTableHeader('Date & Type')),
                        Expanded(flex: 1, child: _buildTableHeader('Status')),
                        Expanded(flex: 1, child: _buildTableHeader('Action')),
                      ],
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      return _TicketTableRow(
                        request: filtered[index],
                        onViewDetails: widget.onViewDetails,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  Widget _buildSearchBar({required double width}) {
    return SizedBox(
      width: width,
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: AdminStyles.bodyStyle(
          fontSize: 13,
          color: AdminStyles.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search ticket ID, room, issue...',
          hintStyle: AdminStyles.bodyStyle(
            fontSize: 13,
            color: AdminStyles.textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminStyles.primary),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AdminStyles.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            borderSide: const BorderSide(color: AdminStyles.primaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Tooltip(
      message: 'Refresh requests',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadRequests(isManualRefresh: true),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AdminStyles.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlue),
                  )
                : const Icon(Icons.refresh_rounded, size: 20, color: _subtleText),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRequestButton() {
    return Tooltip(
      message: 'Create new request manually',
      child: SizedBox(
        height: 42,
        child: ElevatedButton.icon(
          onPressed: () => context.go('/admin/work-requests/create'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isGridView = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isGridView
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: _isGridView ? _primaryBlue : _subtleText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Grid',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isGridView ? _primaryBlue : _subtleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => setState(() => _isGridView = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !_isGridView ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: !_isGridView
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.list_rounded,
                    size: 16,
                    color: !_isGridView ? _primaryBlue : _subtleText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'List',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: !_isGridView ? _primaryBlue : _subtleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterButton(String label, int index) {
    final isSelected = _selectedFilter == index;
    final activeBgColor = AdminStyles.primary;
    final activeTextColor = Colors.white;
    final inactiveTextColor = AdminStyles.textSecondary;
    final borderColor = AdminStyles.border;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeBgColor : borderColor,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AdminStyles.bodyStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? activeTextColor : inactiveTextColor,
          ),
        ),
      ),
    );
  }

}

class _StatCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: widget.isSelected
              ? AdminStyles.glassDecoration(
                  color: widget.iconColor,
                  opacity: 0.1,
                  borderRadius: 18,
                )
              : AdminStyles.cardDecoration(
                  borderRadius: 18,
                  borderColor: _isHovered ? widget.iconColor.withValues(alpha: 0.3) : null,
                ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value.toString(),
                    style: AdminStyles.headingStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AdminStyles.textPrimary,
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      widget.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AdminStyles.bodyStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AdminStyles.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.isSelected) ...[
                const Spacer(),
                const Icon(Icons.check_circle_rounded, color: AdminStyles.primary, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AdminStyles.headingStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  final WorkRequest request;
  final void Function(WorkRequest)? onViewDetails;
  
  const _TicketCard({
    required this.request,
    this.onViewDetails,
  });

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminStyles.cardDecoration(
        borderRadius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminStyles.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${widget.request.id.length > 6 ? widget.request.id.substring(0, 6).toUpperCase() : widget.request.id.toUpperCase()}',
                  style: AdminStyles.headingStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AdminStyles.primary,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d, y').format(widget.request.dateSubmitted),
                style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.request.title,
            style: AdminStyles.headingStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AdminStyles.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.request.requestorName,
                  style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AdminStyles.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${widget.request.officeRoom}, ${widget.request.buildingName}',
                  style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _StatusBadge(status: widget.request.status),
              const SizedBox(width: 8),
              _PriorityBadge(priority: widget.request.priority),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () async {
                if (widget.onViewDetails != null) {
                  widget.onViewDetails!(widget.request);
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminWorkProcessWeb(request: widget.request),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: AdminStyles.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'VIEW DETAILS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending assignment':
        return AdminStyles.textMuted;
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return AdminStyles.info;
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return AdminStyles.error;
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return AdminStyles.primary;
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return AdminStyles.warning;
      case 'completed':
        return AdminStyles.success;
      default:
        return AdminStyles.textMuted;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AdminStyles.pillDecoration(color: config.textColor, isSecondary: true),
      child: Text(
        config.label.toUpperCase(),
        style: AdminStyles.headingStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: config.textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  _Config _getConfig() {
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
      case 'pending assignment':
        return _Config(
          'PENDING',
          const Color(0xFFF3F4F6),
          const Color(0xFF6B7280),
        );
      case 'in progress':
      case 'in_progress':
      case 'assigned':
      case 'accepted by maintenance':
      case 'pre-inspection submitted':
        return _Config(
          'IN PROGRESS',
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB),
        );
      case 'declined':
      case 'cancelled':
      case 'declined/cancelled':
      case 'pre-inspection declined':
        return _Config(
          'DECLINED',
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
        );
      case 'confirmed':
      case 'pre-inspection approved':
      case 'post-repair submitted':
      case 'in progress (post-repair)':
      case 'under_maintenance':
        return _Config(
          'CONFIRMED',
          const Color(0xFFF0FDFA),
          const Color(0xFF0F766E),
        );
      case 'rework':
      case 'for rework':
      case 'under evaluation':
        return _Config(
          'REWORK',
          const Color(0xFFFEF3C7),
          const Color(0xFFD97706),
        );
      case 'completed':
        return _Config(
          'COMPLETED',
          const Color(0xFFD1FAE5),
          const Color(0xFF059669),
        );
      default:
        return _Config(
          status.toUpperCase(),
          const Color(0xFFF1F5F9),
          const Color(0xFF64748B),
        );
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: config.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          priority.toUpperCase(),
          style: AdminStyles.headingStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: config.color,
          ),
        ),
      ],
    );
  }

  _PriorityConfig _getConfig() {
    switch (priority.toLowerCase()) {
      case 'high':
        return _PriorityConfig(const Color(0xFFDC2626));
      case 'medium':
        return _PriorityConfig(const Color(0xFFD97706));
      case 'low':
        return _PriorityConfig(const Color(0xFF16A34A));
      default:
        return _PriorityConfig(const Color(0xFF64748B));
    }
  }
}

class _Config {
  final String label;
  final Color bgColor;
  final Color textColor;
  _Config(this.label, this.bgColor, this.textColor);
}

class _PriorityConfig {
  final Color color;
  _PriorityConfig(this.color);
}

class _TicketTableRow extends StatefulWidget {
  final WorkRequest request;
  final void Function(WorkRequest)? onViewDetails;

  const _TicketTableRow({
    required this.request,
    this.onViewDetails,
  });

  @override
  State<_TicketTableRow> createState() => _TicketTableRowState();
}

class _TicketTableRowState extends State<_TicketTableRow> {
  bool _isHovered = false;

  String _text(String? value, {String fallback = '-'}) {
    final text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final isDuplicate = widget.request.status.toLowerCase() == 'duplicate';
    final formatter = DateFormat('MMM d, yyyy');
    final shortId = widget.request.id.length > 8 ? widget.request.id.substring(0, 8) : widget.request.id;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _isHovered ? AdminStyles.primary.withValues(alpha: 0.02) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminStyles.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${shortId.toUpperCase()}',
                    style: AdminStyles.headingStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminStyles.primary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _text(widget.request.requestorName, fallback: 'Unknown User'),
                    textAlign: TextAlign.center,
                    style: AdminStyles.headingStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _text(widget.request.departmentName, fallback: 'No Department'),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _text(widget.request.title, fallback: 'No Title'),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AdminStyles.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _text(widget.request.roomName, fallback: 'No Room'),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatter.format(widget.request.dateSubmitted),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 13, color: AdminStyles.textPrimary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _text(widget.request.typeOfRequest),
                    textAlign: TextAlign.center,
                    style: AdminStyles.bodyStyle(fontSize: 12, color: AdminStyles.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: _StatusBadge(status: isDuplicate ? 'duplicate' : widget.request.status),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Tooltip(
                  message: 'View Details',
                  child: InkWell(
                    onTap: () async {
                      if (widget.onViewDetails != null) {
                        widget.onViewDetails!(widget.request);
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminWorkProcessWeb(request: widget.request),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
