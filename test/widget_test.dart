// OpenClaw Mobile App Tests
//
// Basic widget tests for the OpenClaw Mobile app.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openclaw_mobile/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenClawApp Tests', () {
    setUp(() async {
      // Set up mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('App initializes and shows loading state', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const OpenClawApp());

      // The app should show a loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('App has correct theme', (WidgetTester tester) async {
      await tester.pumpWidget(const OpenClawApp());

      // Verify MaterialApp exists
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}