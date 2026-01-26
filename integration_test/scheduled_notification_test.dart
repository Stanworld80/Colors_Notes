import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:colors_notes/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Scheduled Notification Scenario', () {
    testWidgets('Schedule notifications every 5 minutes', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // --- Authentication (Reuse from notification_flow_test) ---
      // Wait for either Home Screen or Auth Screen
      bool onHome = false;
      bool onAuth = false;
      for (int i = 0; i < 20; i++) {
        if (find.byType(AppBar).evaluate().isNotEmpty) {
          onHome = true;
          break;
        }
        if (find
                .widgetWithText(ElevatedButton, "Se connecter")
                .evaluate()
                .isNotEmpty ||
            find.text("Déjà un compte ? Se connecter").evaluate().isNotEmpty) {
          onAuth = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 500));
      }

      if (onHome) {
        // Logged in
      } else {
        final goToLoginLink = find.text("Déjà un compte ? Se connecter");
        if (goToLoginLink.evaluate().isNotEmpty) {
          await tester.tap(goToLoginLink);
          await tester.pumpAndSettle();
        }

        // Wait for Email Field
        final emailFieldFinder = find.ancestor(
            of: find.byIcon(Icons.email_outlined),
            matching: find.byType(TextFormField));

        for (int i = 0; i < 10; i++) {
          if (emailFieldFinder.evaluate().isNotEmpty) break;
          await tester.pump(const Duration(milliseconds: 500));
        }

        const email = 'CompteTechnique-Testeur@stanworld.org';
        const password = 'Tester=2025';

        if (emailFieldFinder.evaluate().isNotEmpty) {
          await tester.enterText(emailFieldFinder, email);
        } else {
          await tester.enterText(find.byType(TextFormField).first, email);
        }

        final passwordField = find.ancestor(
            of: find.byIcon(Icons.lock_outline),
            matching: find.byType(TextFormField));

        if (passwordField.evaluate().isNotEmpty) {
          await tester.enterText(passwordField, password);
        } else {
          await tester.enterText(find.byType(TextFormField).at(1), password);
        }

        final loginButton = find.widgetWithText(ElevatedButton, "Se connecter");
        await tester.tap(loginButton.evaluate().isNotEmpty
            ? loginButton
            : find.byType(ElevatedButton).last);

        await tester.pumpAndSettle(const Duration(seconds: 8));
      }

      // --- Open Journal for Editing ---
      // We assume at least one journal exists or we create one.
      // Let's create a new one to be safe and clean.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouveau journal'));
      await tester.pumpAndSettle();

      const journalName = "Interval Test Journal";
      await tester.enterText(find.byType(TextFormField), journalName);
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Open Edit Page
      await tester.tap(find.byIcon(Icons.arrow_drop_down)); // Open Selector
      await tester.pumpAndSettle();

      // Find the Edit icon (Pencil)
      final editIcon = find.byIcon(Icons.edit);
      if (editIcon.evaluate().isNotEmpty) {
        await tester.tap(editIcon.first);
      } else {
        await tester.tap(find.textContaining('Modifier')); // Fallback
      }
      await tester.pumpAndSettle();

      // Enable Notifications if off
      final switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);
      if (tester.widget<Switch>(switchFinder).value == false) {
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
      }

      // --- Trigger "Test: Schedule Interval" ---
      final intervalButton = find.text("Test: Schedule Interval");
      await tester.scrollUntilVisible(intervalButton, 500.0);
      expect(intervalButton, findsOneWidget);

      await tester.tap(intervalButton);
      await tester.pumpAndSettle(); // Wait for dialog

      // Verify Test Interval Dialog
      expect(find.text("Test Interval"), findsOneWidget);
      expect(find.text("Enter interval in minutes (or 0 for seconds test):"),
          findsOneWidget);

      // Enter 5 minutes (default is 5, but let's be explicit)
      // The TextField should have '5' initially.
      // Let's change it to 2 for a quicker test or keep 5.
      // Let's keep 5 to match the scenario name.
      await tester.tap(find.text("Schedule"));
      await tester.pumpAndSettle(); // Wait for Success Dialog

      // Verify Success Dialog
      expect(find.text("Scheduled!"), findsOneWidget);
      expect(find.textContaining("Scheduled 5 notifications:"), findsOneWidget);

      // Close Dialog
      await tester.tap(find.text("OK"));
      await tester.pumpAndSettle();

      // At this point, the device has 5 notifications scheduled for +5, +10, +15, +20, +25 mins.
      // In a real device test, one would just leave the app backgrounded and observe.
      // For automated test, we verified the scheduling logic executed successfully.
    });
  });
}
