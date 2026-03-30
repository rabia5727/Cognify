import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/task_provider.dart';
import 'package:frontend/providers/project_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const CognifyApp());

    // Wait for any async operations
    await tester.pump();

    // Verify the app builds without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Providers are initialized', (WidgetTester tester) async {
    await tester.pumpWidget(const CognifyApp());
    await tester.pump();

    // Verify providers exist
    final context = tester.element(find.byType(MaterialApp));
    expect(Provider.of<AuthProvider>(context, listen: false), isNotNull);
    expect(Provider.of<TaskProvider>(context, listen: false), isNotNull);
    expect(Provider.of<ProjectProvider>(context, listen: false), isNotNull);
  });
}
