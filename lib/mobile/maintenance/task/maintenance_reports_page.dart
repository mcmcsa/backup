import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'task_details_page.dart';
import '../../../shared/widgets/common_app_bar.dart';
import '../../../authentication/services/auth_service.dart';
import '../../../shared/services/work_request_service.dart';
import '../../../shared/models/work_request_model.dart';

class MaintenanceReportsPage extends StatefulWidget {
  const MaintenanceReportsPage({super.key});

  @override
  State<MaintenanceReportsPage> createState() => _MaintenanceReportsPageState();
}

class _MaintenanceReportsPageState extends State<MaintenanceReportsPage> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Pending',
    'Approved',
    'In Progress',
    'Under Maintenance',
    'Completed',
    'High Priority',
  ];

  List<WorkRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user != null) {
        final data = await WorkRequestService.fetchAssignedTo(user.id);
        if (mounted) {
          setState(() {
            _requests = data;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<WorkRequest> get _filteredRequests {
    if (_selectedCategory == 'All') return _requests;
    if (_selectedCategory == 'Pending') {
      return _requests.where((r) => r.status == 'pending').toList();
    }
    if (_selectedCategory == 'Approved') {
      return _requests.where((r) => r.status == 'approved').toList();
    }
    if (_selectedCategory == 'In Progress') {
      return _requests.where((r) => r.status == 'ongoing' || r.status == 'in_progress').toList();
    }
    if (_selectedCategory == 'Under Maintenance') {
      return _requests.where((r) => r.status == 'under_maintenance').toList();
    }
    if (_selectedCategory == 'Completed') {
      return _requests.where((r) => r.status == 'done' || r.status == 'completed').toList();
    }
    if (_selectedCategory == 'High Priority') {
      return _requests.where((r) => r.priority == 'high').toList();
    }
    return _requests;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CommonAppBar(
        roleText: 'Welcome Maintenance Staff',
        primaryColor: const Color(0xFF4169E1),
        showMenu: false,
        onNotificationPressed: () {
          // Handle notification press
        },
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                const Text(
                  'Maintenance Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search tracking ID or location',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFF1A1A2E),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Reports List
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_filteredRequests.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No reports found',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._filteredRequests.map((r) {
                    String statusLabel;
                    Color statusColor;
                    switch (r.status.toLowerCase()) {
                      case 'pending':
                        statusLabel = 'PENDING';
                        statusColor = Colors.orange;
                        break;
                      case 'ongoing':
                        statusLabel = 'IN PROGRESS';
                        statusColor = const Color(0xFF00BFA5);
                        break;
                      case 'done':
                        statusLabel = 'COMPLETED';
                        statusColor = Colors.green;
                        break;
                      default:
                        statusLabel = r.status.toUpperCase();
                        statusColor = const Color(0xFF1A1A2E);
                    }

                    IconData catIcon;
                    Color catColor;
                    switch (r.typeOfRequest.toLowerCase()) {
                      case 'electrical':
                        catIcon = Icons.electrical_services;
                        catColor = Colors.blue;
                        break;
                      case 'plumbing':
                        catIcon = Icons.plumbing;
                        catColor = Colors.orange;
                        break;
                      default:
                        catIcon = Icons.handyman;
                        catColor = const Color(0xFF00BFA5);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildReportCard(
                        id: r.id,
                        status: statusLabel,
                        statusColor: statusColor,
                        category: r.typeOfRequest,
                        categoryIcon: catIcon,
                        categoryColor: catColor,
                        location: '${r.buildingName}, ${r.officeRoom}',
                        assignedTo: r.requestorName,
                      ),
                    );
                  }),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String id,
    required String status,
    required Color statusColor,
    required String category,
    required IconData categoryIcon,
    required Color categoryColor,
    required String location,
    required String assignedTo,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsPage(
              taskId: id,
              title: category,
              location: location,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: status == 'NEW'
                          ? statusColor
                          : status == 'PENDING'
                          ? Colors.orange
                          : status == 'ASSIGNED'
                          ? const Color(0xFF00BFA5)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.toUpperCase()} REQUEST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request ID
            Text(
              id,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  assignedTo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
