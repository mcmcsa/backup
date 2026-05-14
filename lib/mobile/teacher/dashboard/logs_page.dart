import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/common_app_bar.dart';

class LogsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const LogsPage({super.key, this.scaffoldKey});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: CommonAppBar(
        roleText: 'Teacher',
        primaryColor: themeProvider.primaryColor,
        onMenuPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: 'Search tracking number or room...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                  borderSide: BorderSide(color: Color(0xFF4169E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // Tab Filters
          Container(
            color: themeProvider.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip('All', themeProvider),
                  const SizedBox(width: 8),
                  _buildTabChip('Account', themeProvider),
                  const SizedBox(width: 8),
                  _buildTabChip('Reports', themeProvider),
                  const SizedBox(width: 8),
                  _buildTabChip('Settings', themeProvider),
                ],
              ),
            ),
          ),

          // Logs Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 20, color: themeProvider.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: themeProvider.subtitleColor),
                        const SizedBox(height: 12),
                        Text(
                          'No activity logs yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your activity history will appear here',
                          style: TextStyle(
                            fontSize: 13,
                            color: themeProvider.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, ThemeProvider themeProvider) {
    final isSelected = _selectedTab == label;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == 'Account') ...[
            Icon(
              Icons.person_outline,
              size: 16,
              color: isSelected ? Colors.white : themeProvider.textColor,
            ),
            const SizedBox(width: 6),
          ] else if (label == 'Reports') ...[
            Icon(
              Icons.description_outlined,
              size: 16,
              color: isSelected ? Colors.white : themeProvider.textColor,
            ),
            const SizedBox(width: 6),
          ] else if (label == 'Settings') ...[
            Icon(
              Icons.settings_outlined,
              size: 16,
              color: isSelected ? Colors.white : themeProvider.textColor,
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTab = label;
        });
      },
      backgroundColor: themeProvider.cardColor,
      selectedColor: themeProvider.primaryColor,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : themeProvider.textColor,
      ),
      side: BorderSide(
        color: isSelected ? themeProvider.primaryColor : themeProvider.borderColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
