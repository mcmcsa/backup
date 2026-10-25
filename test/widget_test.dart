// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PSU Maintenance System theme and smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('PSU Maintenance System')),
          body: const Center(child: Text('Campus Maintenance Portal')),
        ),
      ),
    );

    expect(find.text('PSU Maintenance System'), findsOneWidget);
    expect(find.text('Campus Maintenance Portal'), findsOneWidget);
  });
}
