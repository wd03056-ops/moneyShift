import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp smoke builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Money Shift')),
        ),
      ),
    );

    expect(find.text('Money Shift'), findsOneWidget);
  });
}
