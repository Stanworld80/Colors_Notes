import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:colors_notes/widgets/loading_indicator.dart';

void main() {
  testWidgets('LoadingIndicator displays a CircularProgressIndicator', (WidgetTester tester) async {
    // Build the widget in a test MaterialApp environment
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingIndicator(),
        ),
      ),
    );

    // Verify that the LoadingIndicator contains a CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify that it has a Container with a background color
    final containerFinder = find.byType(Container);
    expect(containerFinder, findsOneWidget);

    final Container container = tester.widget<Container>(containerFinder);
    expect(container.color, Colors.black.withOpacity(0.1));
  });
}
