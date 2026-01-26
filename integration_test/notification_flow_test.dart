import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:colors_notes/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Flow', () {
    testWidgets('Enable Notifications and Trigger Test', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Check if we are already logged in (Home Screen check)
      // Wait for either Home Screen or Auth Screen
      bool onHome = false;
      bool onAuth = false;
      for (int i = 0; i < 20; i++) {
        if (find.byType(AppBar).evaluate().isNotEmpty) {
          // Verify if it's Home (AppBar usually has title "Journaux" or similar)
          // Simple check: If AppBar exists, we are likely inside.
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
        print("Already logged in, skipping authentication.");
      } else {
        // Go to Login if needed
        final goToLoginLink = find.text("Déjà un compte ? Se connecter");
        if (goToLoginLink.evaluate().isNotEmpty) {
          await tester.tap(goToLoginLink);
          await tester.pumpAndSettle();
        }

        // Wait for Email Field
        final emailFieldFinder = find.ancestor(
            of: find.byIcon(Icons.email_outlined),
            matching: find.byType(TextFormField));

        // Wait loop for fields
        for (int i = 0; i < 10; i++) {
          if (emailFieldFinder.evaluate().isNotEmpty) break;
          await tester.pump(const Duration(milliseconds: 500));
        }

        const email = 'CompteTechnique-Testeur@stanworld.org';
        const password = 'Tester=2025';

        if (emailFieldFinder.evaluate().isNotEmpty) {
          await tester.enterText(emailFieldFinder, email);
        } else {
          // Last ditch fallback if finder failed but fields exist
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

        // Submit Button "Se connecter"
        final loginButton = find.widgetWithText(ElevatedButton, "Se connecter");
        await tester.tap(loginButton.evaluate().isNotEmpty
            ? loginButton
            : find.byType(ElevatedButton).last);

        await tester.pumpAndSettle(const Duration(seconds: 8)); // Wait for Auth
      }

      // -------------------------

      // 1. Create a Journal first (to edit it basically, or we can use the default if exists)
      // The default journal is usually created on register.
      // Let's Edit the active journal.
      // Look for Edit Button in AppBar (Pencil icon usually) or via Menu.

      // Checking DynamicJournalAppBar in specs...
      // "Bouton pour basculer entre vue liste et vue grille..."
      // Actually Journal Editing is often in the Menu or a specific Edit icon in the AppBar title area.

      // Let's assume we are on Home.
      // Tap on the "Open Menu" if it's a drawer, or the Journal Selector.
      // Or maybe there is a settings/edit icon.

      // From previous `journal_flow_test`, we saw we can create a new journal.
      // Let's create one to be sure we are owners and it's fresh.
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouveau journal'));
      await tester.pumpAndSettle();

      const journalName = "Notify Journal";
      await tester.enterText(find.byType(TextFormField), journalName);
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Now we are in the new journal.
      // Find the Edit Journal button.
      // It might be in the drop down too? "Éditer le journal"?
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      // Check for an Edit icon (Pencil) next to the journal name in the list?
      // Or maybe a menu item "Modifier le journal".
      // Let's guess "Modifier" or try to find an Edit icon.
      final editIcon = find.byIcon(Icons.edit);
      if (editIcon.evaluate().isNotEmpty) {
        await tester.tap(editIcon.first);
      } else {
        // Fallback: look for text
        await tester.tap(find.textContaining('Modifier'));
      }
      await tester.pumpAndSettle();

      // 2. We should be in EditJournalPage
      expect(find.textContaining('Modifier le journal'),
          findsOneWidget); // Localized title

      // 3. Enable Notifications Switch
      // "Activer les notifications" (French) or "Enable notifications"
      // We look for a Switch or Toggle.
      final switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);
      // If it's off, toggle it.
      if (tester.widget<Switch>(switchFinder).value == false) {
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        // Permission dialog might appear here (System or In-App).
        // Since it's integration test on emulator, usually permissions are auto-granted or we tap "Allow".
        // Tapping native dialogs is hard in integration_test.
        // We hope defaults allow or we catch the in-app snackbar.
      }

      // 4. Fill required phrase if needed
      // "Phrase de notification"
      // Check if visible
      final phraseField = find.ancestor(
          of: find.textContaining('Phrase'),
          matching: find.byType(TextFormField));
      if (phraseField.evaluate().isNotEmpty) {
        await tester.enterText(phraseField, "It's time to write!");
      }

      // 5. Trigger "Test: Immediate"
      // Need to scroll down probably.
      final testButton = find.text("Test: Immediate");
      await tester.scrollUntilVisible(testButton, 500.0);
      await tester.tap(testButton);
      await tester.pumpAndSettle();

      // 6. Verify success Snackbar for Immediate
      expect(
          find.textContaining("Sent immediate notification!"), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 7. Trigger "Test: Notify in 10s"
      final scheduleButton = find.text("Test: Notify in 10s");
      await tester.scrollUntilVisible(scheduleButton, 500.0);
      await tester.tap(scheduleButton);
      await tester.pumpAndSettle();

      // 8. Verify success Snackbar for Scheduling
      // It should say "Success! Exact (10s): ..."
      expect(find.textContaining("Success! Exact"), findsOneWidget);

      // 9. Trigger "Fix Battery Restrictions" (for coverage)
      final batteryButton = find.text("Fix Battery Restrictions");
      if (batteryButton.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(batteryButton, 500.0);
        await tester.tap(batteryButton);
        await tester.pumpAndSettle();
        // We might get a snackbar or nothing depending on emulation.
        // Just ensuring no crash.
      }

      // Wait for the notification to actually trigger (10s scheduled + buffer)
      await Future.delayed(const Duration(seconds: 15));
    });
  });
}
