import 'package:flutter/material.dart';
import '../../shared/models/work_request_model.dart';

/// A simple InheritedWidget that exposes a callback so any child widget
/// inside the maintenance navigation can switch pages and pass task details
/// without pushing full-page routes over the sidebar shell.
class MaintenanceNavController extends InheritedWidget {
  final void Function(int index, {WorkRequest? request}) navigateTo;

  const MaintenanceNavController({
    super.key,
    required this.navigateTo,
    required super.child,
  });

  static MaintenanceNavController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MaintenanceNavController>();
  }

  @override
  bool updateShouldNotify(MaintenanceNavController oldWidget) => false;
}
