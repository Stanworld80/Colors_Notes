import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:colors_notes/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Journal Flow', () {
    testWidgets('Login and Create New Journal', (tester) async {
      app.main();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // 1. Check we are on Login Page
      // Title should be "Se connecter"
      // If we are on Register page, we might see "Créer un compte"

      final goToLoginLink = find.text("Déjà un compte ? Se connecter");
      if (goToLoginLink.evaluate().isNotEmpty) {
        await tester.tap(goToLoginLink);
        await tester.pumpAndSettle();
      }

      // 2. Fill Login Form
      const email = 'CompteTechnique-Testeur@stanworld.org';
      const password = 'Tester=2025';

      // Email
      await tester.enterText(
          find.ancestor(
              of: find.byIcon(Icons.email_outlined),
              matching: find.byType(TextFormField)),
          email);

      // Password
      // Try finding by Lock Icon or Label "Mot de passe"
      final passwordField = find.ancestor(
          of: find.byIcon(Icons.lock_outline),
          matching: find.byType(TextFormField));

      if (passwordField.evaluate().isNotEmpty) {
        await tester.enterText(passwordField, password);
      } else {
        await tester.enterText(find.byType(TextFormField).last, password);
      }

      // 3. Submit
      // Button "Se connecter"
      final loginButton = find.widgetWithText(ElevatedButton, "Se connecter");
      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton);
      } else {
        await tester.tap(find.byType(ElevatedButton).last);
      }

      await tester
          .pumpAndSettle(const Duration(seconds: 8)); // Wait for Firebase

      // 5. Verify Home Page (Look for Journal Name or specific UI)
      // Default journal might be "Journal par défaut" or similar
      expect(find.byType(AppBar), findsOneWidget);

      // 6. Create New Journal
      // Open Menu (assuming Dropdown in AppBar)
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      // Tap "Nouveau journal"
      await tester.tap(find.text('Nouveau journal'));
      await tester.pumpAndSettle();

      // 7. Fill Journal Name
      const newJournalName = "Integration Journal";
      await tester.enterText(find.byType(TextFormField), newJournalName);

      // 8. Save
      // Assuming a save button (Icon or Text)
      await tester.tap(find.text('Créer')); // Or Icon(Icons.check)
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 9. Verify new journal is active
      expect(find.text(newJournalName), findsOneWidget);
    });
  });
}
