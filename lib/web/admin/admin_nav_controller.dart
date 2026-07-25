import 'package:flutter/material.dart';
import '../../shared/models/work_request_model.dart';

/// An InheritedWidget that exposes navigation functions so any child widget
/// inside Admin web navigation can open ticket details or switch tabs without
/// pushing full-screen routes over the left sidebar navigation shell.
class AdminNavController extends InheritedWidget {
  final void Function(int index, {WorkRequest? request}) navigateTo;
  final void Function(WorkRequest request) openWorkProcess;

  const AdminNavController({
    super.key,
    required this.navigateTo,
    required this.openWorkProcess,
    required super.child,
  });

  static AdminNavController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminNavController>();
  }

  @override
  bool updateShouldNotify(AdminNavController oldWidget) => false;
}
