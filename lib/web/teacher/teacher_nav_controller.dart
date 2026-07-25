import 'package:flutter/material.dart';
import '../../shared/models/work_request_model.dart';

/// A simple InheritedWidget that exposes a callback so any child widget
/// inside the teacher navigation can switch pages without using go_router.
class TeacherNavController extends InheritedWidget {
  final void Function(int index, {String? roomId, String? roomName, String? buildingName, WorkRequest? request}) navigateTo;

  const TeacherNavController({
    super.key,
    required this.navigateTo,
    required super.child,
  });

  static TeacherNavController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TeacherNavController>();
  }

  @override
  bool updateShouldNotify(TeacherNavController oldWidget) => false;
}
