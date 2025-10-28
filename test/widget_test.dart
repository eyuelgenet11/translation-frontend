import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:translation_frontend/main.dart';

void main() {
  Widget makeTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('App shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(makeTestableWidget(const TranslationApp()));

    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Login to Register navigation works',
      (WidgetTester tester) async {
    await tester.pumpWidget(makeTestableWidget(const TranslationApp()));

    final registerButton = find.text('Register');
    expect(registerButton, findsOneWidget);

    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(find.text('Register'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
}
