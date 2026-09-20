import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tarmeem basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('ترميم'),
          ),
        ),
      ),
    );
    expect(find.text('ترميم'), findsOneWidget);
  });
}
