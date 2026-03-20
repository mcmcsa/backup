import 'package:flutter/material.dart';

/// Compatibility page kept to satisfy legacy references.
/// This page can be removed once all old references are deleted.
class ScheduleManagementPageWeb extends StatelessWidget {
  const ScheduleManagementPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Schedule management moved to room schedule pages.'),
      ),
    );
  }
}
