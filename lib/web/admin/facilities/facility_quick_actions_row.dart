import 'package:flutter/material.dart';

import '../shared/admin_styles.dart';

class FacilityQuickActionsConfig {
  final int departmentsIndex;
  final int buildingsIndex;
  final int floorsIndex;
  final int roomTypesIndex;
  final int requestTypesIndex;

  const FacilityQuickActionsConfig({
    required this.departmentsIndex,
    required this.buildingsIndex,
    required this.floorsIndex,
    required this.roomTypesIndex,
    required this.requestTypesIndex,
  });
}

class FacilityQuickActionsRow extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final FacilityQuickActionsConfig config;

  const FacilityQuickActionsRow({
    super.key,
    required this.activeIndex,
    required this.onSelect,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Map<String, dynamic>>[
      {
        'label': 'Department',
        'icon': Icons.account_tree_rounded,
        'index': config.departmentsIndex,
      },
      {
        'label': 'Building',
        'icon': Icons.apartment_rounded,
        'index': config.buildingsIndex,
      },
      {
        'label': 'Floor',
        'icon': Icons.layers_rounded,
        'index': config.floorsIndex,
      },
      {
        'label': 'Room Type',
        'icon': Icons.category_rounded,
        'index': config.roomTypesIndex,
      },
      {
        'label': 'Request Type',
        'icon': Icons.assignment_rounded,
        'index': config.requestTypesIndex,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        if (!isWide) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: actions.map((action) {
                final targetIndex = action['index'] as int;
                final isSelected = activeIndex == targetIndex;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: OutlinedButton.icon(
                    onPressed: () => onSelect(targetIndex),
                    icon: Icon(action['icon'] as IconData, size: 18),
                    label: Text(action['label'] as String),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSelected
                          ? Colors.white
                          : AdminStyles.textSecondary,
                      backgroundColor: isSelected
                          ? AdminStyles.primary
                          : Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AdminStyles.primary
                            : AdminStyles.border,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminStyles.border),
          ),
          child: Row(
            children: List.generate(actions.length, (index) {
              final action = actions[index];
              final targetIndex = action['index'] as int;
              final isSelected = activeIndex == targetIndex;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == actions.length - 1 ? 0 : 8,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => onSelect(targetIndex),
                    icon: Icon(action['icon'] as IconData, size: 18),
                    label: Text(action['label'] as String),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSelected
                          ? Colors.white
                          : AdminStyles.textSecondary,
                      backgroundColor: isSelected
                          ? AdminStyles.primary
                          : Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AdminStyles.primary
                            : AdminStyles.border,
                      ),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
