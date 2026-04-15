import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airsoft_app/features/home/home_screen.dart';

void main() {
  testWidgets('Home screen renders key sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('New fields'), findsOneWidget);
    expect(find.text('New events'), findsOneWidget);
  });
}
