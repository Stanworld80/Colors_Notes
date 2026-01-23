import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:colors_notes/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('verify app starts and main screen loads', (tester) async {
      app.main();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Basic smoke test: verify we are on the home screen
      // You might need to adjust this depending on your actual home screen widgets
      // For now, checks that we don't crash and render *something*
      expect(find.byType(app.MyApp), findsOneWidget);

      // Example: delay to observe
      await Future.delayed(const Duration(seconds: 2));
    });
  });
}
