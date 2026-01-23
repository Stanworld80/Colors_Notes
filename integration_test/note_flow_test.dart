import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:colors_notes/main.dart' as app;

// Note: This test assumes it runs AFTER a user is logged in,
// OR it registers a new one.
// For simplicity in independent runs, we will register a new user again.
// In a real suite, we might reuse session if not cleared.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Note Flow', () {
    testWidgets('Login and Create a Note', (tester) async {
      app.main();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // --- Login Step ---
      // 1. Check if we need to switch to Login page
      if (find.text("Déjà un compte ? Se connecter").evaluate().isNotEmpty) {
        await tester.tap(find.text("Déjà un compte ? Se connecter"));
        await tester.pumpAndSettle();
      }

      // 2. Fill Credentials
      const email = 'CompteTechnique-Testeur@stanworld.org';
      const password = 'Tester=2025';

      // Email
      await tester.enterText(
          find.ancestor(
              of: find.byIcon(Icons.email_outlined),
              matching: find.byType(TextFormField)),
          email);

      // Password
      final passwordField = find.ancestor(
          of: find.byIcon(Icons.lock_outline),
          matching: find.byType(TextFormField));

      if (passwordField.evaluate().isNotEmpty) {
        await tester.enterText(passwordField, password);
      } else {
        await tester.enterText(find.byType(TextFormField).last, password);
      }

      // 3. Submit ("Se connecter")
      final loginButton = find.widgetWithText(ElevatedButton, "Se connecter");
      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton);
      } else {
        await tester.tap(find.byType(ElevatedButton).last);
      }

      await tester.pumpAndSettle(const Duration(seconds: 8));
      // -----------------------------------------------------

      // 1. Verify we are on Home (Grid of colors)
      // Assuming GridView
      expect(find.byType(GridView), findsOneWidget);

      // 2. Select a Color (First one)
      // Typically InkWell or GestureDetector inside Grid
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // 3. We should be on EntryPage
      // Enter Note Content
      const noteContent = "Hello from Integration Test!";
      await tester.enterText(find.byType(TextFormField).first, noteContent);
      // Note: Date/Time are usually pre-filled

      // 4. Save
      // Look for Save Icon or Button
      await tester.tap(find.byIcon(Icons.check)); // Common for save
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 5. Verify we are back (or snackbar shown?)
      // Checks if note appears in the list (if Note List is reachable or displayed)
      // Usually App goes back to Home or List.
      // If Home: Navigate to List
      // If List: Verify content

      // Let's assume we go back to Home.
      // Go to List Page (via FAB or Menu?)
      // Checking specs: "Boutons flottants ou menu pour accéder... à la liste des notes."
      final listButton = find.byIcon(Icons.list);
      if (listButton.evaluate().isNotEmpty) {
        await tester.tap(listButton);
        await tester.pumpAndSettle();
      }

      // Verify Note Content is present
      expect(find.text(noteContent), findsOneWidget);
    });
  });
}
