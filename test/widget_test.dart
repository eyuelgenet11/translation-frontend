import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:geez_translation_marketplace/main.dart';

void main() {
  testWidgets('App shows login screen correctly', (WidgetTester tester) async {
    await tester.pumpWidget(TranslationApp as Widget);
    await tester.pumpAndSettle();

    // Title of login screen
    expect(find.text('Geez Script Translation'), findsOneWidget);

    // Phone number TextField
    expect(find.byType(TextField), findsOneWidget);

    // Continue button
    expect(find.text('Continue'), findsOneWidget);

    // Register link text
    expect(find.text("Don't have an account? Register"), findsOneWidget);
  });

  testWidgets('Login to Register navigation works', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(TranslationApp as Widget);
    await tester.pumpAndSettle();

    final registerButton = find.text("Don't have an account? Register");
    expect(registerButton, findsOneWidget);

    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Check RegisterScreen title
    expect(find.text('Create Account'), findsOneWidget);

    // Check the three labels that your CustomTextField receives:
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Check Register button exists
    expect(find.text('Register'), findsOneWidget);

    // Check Login navigation link exists
    expect(find.text('Already have an account? Login'), findsOneWidget);
  });
}
