// test/integration/auth_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import your app's main entry point
import 'package:colors_notes/main.dart' as app;

// Import your default Firebase options
import 'package:colors_notes/firebase_options.dart';

// Import Firebase Core
import 'package:firebase_core/firebase_core.dart';

// Import your widgets
import 'package:colors_notes/widgets/dynamic_journal_app_bar.dart';

// Main function for the test file
Future<void> main() async {
  // Ensure the binding is initialized. This is critical and should be the first line.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase ONCE here, before any tests or app.main() is called.
  // This makes it available globally for the test run.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Optional: If using Firebase emulators, configure them here AFTER initializeApp.
  // try {
  //   await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  //   await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  // } catch (e) {
  //   print('Error setting up Firebase emulators in test: $e');
  // }

  // Now define your test groups.
  group('Authentication Flow Tests', () {
    // setUpAll is not strictly needed for Firebase init if done in the main scope as above.
    // Individual test setup/teardown can be done with setUp/tearDown if needed.

    testWidgets('User can sign up with email and password, and see the homepage', (WidgetTester tester) async {
      // Start the app. Firebase is already initialized from the main scope of this test file.
      app.main(); // This will run your MyApp widget
      await tester.pumpAndSettle(); // Wait for app to initialize and animations to settle

      // Navigate to Register Page
      // Expecting SignInPage to be the initial route from AuthGate if not logged in.
      expect(find.text('Se connecter'), findsOneWidget); // On SignInPage
      await tester.tap(find.text("Pas encore de compte ? S'inscrire")); // Navigate to RegisterPage
      await tester.pumpAndSettle();

      // On Register Page
      expect(find.text('Créer un compte'), findsOneWidget); // AppBar title of RegisterPage

      // Find form fields on RegisterPage
      final displayNameField = find.widgetWithText(TextFormField, 'Nom d\'affichage');
      final emailField = find.widgetWithText(TextFormField, 'Email');
      final passwordField = find.widgetWithText(TextFormField, 'Mot de passe');
      final confirmPasswordField = find.widgetWithText(TextFormField, 'Confirmer le mot de passe');
      final signUpButton = find.widgetWithText(ElevatedButton, 'S\'inscrire et se connecter');

      expect(displayNameField, findsOneWidget);
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(confirmPasswordField, findsOneWidget);
      expect(signUpButton, findsOneWidget);

      // Generate unique email for each test run to avoid conflicts
      final uniqueEmail = 'testuser_${DateTime.now().millisecondsSinceEpoch}@example.com';

      // Enter text into the fields
      await tester.enterText(displayNameField, 'Test User Signup');
      await tester.enterText(emailField, uniqueEmail);
      await tester.enterText(passwordField, 'Password123!'); // Ensure this meets password criteria
      await tester.enterText(confirmPasswordField, 'Password123!');
      await tester.pump(); // Allow text to propagate

      // Tap the sign-up button
      await tester.tap(signUpButton);
      // Wait for Firebase operations (signup, user data init, navigation)
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify navigation to MainScreen/LoggedHomepage after successful signup
      // The DynamicJournalAppBar is part of MainScreen
      expect(find.byType(DynamicJournalAppBar), findsOneWidget);
      // LoggedHomepage shows "Bienvenue"
      expect(find.textContaining('Bienvenue'), findsOneWidget);
    });

    // Add more authentication tests (sign in, sign out, Google sign in) here.
  });

  group('Journal and Note Management Tests', () {
    testWidgets('User can create a journal, then create a note in it', (WidgetTester tester) async {
      // Start the app. Firebase is already initialized.
      app.main();
      await tester.pumpAndSettle();

      // --- Pre-requisite: User is logged in ---
      // For robust tests, each testWidgets should handle its own login or ensure a clean state.
      // Repeating signup here to ensure user exists and is logged in for this test.
      expect(find.text('Se connecter'), findsOneWidget);
      await tester.tap(find.text("Pas encore de compte ? S'inscrire"));
      await tester.pumpAndSettle();

      final uniqueEmail = 'journaltest_${DateTime.now().millisecondsSinceEpoch}@example.com';
      await tester.enterText(find.widgetWithText(TextFormField, 'Nom d\'affichage'), 'Journal Tester');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), uniqueEmail);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmer le mot de passe'), 'Password123!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'S\'inscrire et se connecter'));
      await tester.pumpAndSettle(const Duration(seconds: 10)); // Wait for login and initial journal setup

      // --- 1. Navigate to Journal Management and Create a new Journal ---
      expect(find.byType(DynamicJournalAppBar), findsOneWidget); // Verify on MainScreen
      // Open AppBar menu (more_vert_outlined icon)
      await tester.tap(find.byIcon(Icons.more_vert_outlined));
      await tester.pumpAndSettle(); // Wait for menu to appear
      // Tap on "Journaux" menu item
      await tester.tap(find.text('Journaux'));
      await tester.pumpAndSettle(); // Wait for navigation

      // Now on JournalManagementPage
      expect(find.text('Gérer les Journaux'), findsOneWidget); // AppBar title
      // Tap 'Créer un nouveau journal' card. The InkWell contains a Row with the text.
      await tester.tap(find.widgetWithText(InkWell, 'Créer un nouveau journal'));
      await tester.pumpAndSettle();

      // Now on CreateJournalPage
      expect(find.text('Créer un nouveau journal'), findsOneWidget); // AppBar title of CreateJournalPage
      final journalNameField = find.widgetWithText(TextFormField, 'Choisissez un nom pour votre journal...');
      await tester.enterText(journalNameField, 'Mon Journal de Test');
      await tester.pump();

      // Assuming "Palette Vierge" is the default or selected.
      // The InlinePaletteEditorWidget is used. We need to add at least one color.
      // Find the "Add" button within InlinePaletteEditorWidget.
      // This could be an Icon or a specific ListTile.
      Finder addColorButton;
      // Check if the list view's add button is present
      if (tester.any(find.widgetWithText(ListTile, "Ajouter une nouvelle couleur/dégradé"))) {
        addColorButton = find.widgetWithText(ListTile, "Ajouter une nouvelle couleur/dégradé");
      } else {
        // Fallback to the grid view's add icon, assuming it's unique enough or the first one
        addColorButton = find.byIcon(Icons.add_circle_outline).first;
      }
      await tester.ensureVisible(addColorButton); // Ensure it's visible before tapping
      await tester.tap(addColorButton);
      await tester.pumpAndSettle(); // Wait for the add color dialog to appear

      // In the _showEditColorDialog from InlinePaletteEditorWidget
      await tester.enterText(find.widgetWithText(TextFormField, 'Nom de base pour la couleur/dégradé'), 'Couleur Test');
      await tester.pump();
      // Assuming default color from picker is fine. Tap "Ajouter la couleur".
      await tester.tap(find.text('Ajouter la couleur'));
      await tester.pumpAndSettle(); // Dialog closes, palette editor updates

      // Now tap the "Créer le journal" button on CreateJournalPage
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer le journal'));
      await tester.pumpAndSettle(const Duration(seconds: 5)); // Wait for journal creation and navigation

      // --- 2. Back on LoggedHomepage (or MainScreen), select the created journal's color to create a note ---
      // The new journal "Mon Journal de Test" should be active and its name in the AppBar.
      expect(find.text('Mon Journal de Test'), findsOneWidget);
      // Tap the color button created ("Couleur Test") on LoggedHomepage
      final colorButtonFinder = find.widgetWithText(ElevatedButton, 'Couleur Test');
      await tester.ensureVisible(colorButtonFinder); // Ensure button is visible
      await tester.tap(colorButtonFinder);
      await tester.pumpAndSettle();

      // --- 3. On EntryPage, fill in note details and save ---
      expect(find.text('Nouvelle Note'), findsOneWidget); // AppBar title of EntryPage
      final noteContentField = find.widgetWithText(TextFormField, 'Contenu de la note...');
      await tester.enterText(noteContentField, 'Ceci est ma première note de test d\'intégration !');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sauvegarder la Note'));
      await tester.pumpAndSettle(const Duration(seconds: 5)); // Wait for note creation and navigation

      // --- 4. Verify the note appears in NoteListPage ---
      // The app might navigate back to LoggedHomepage or directly to NoteListPage.
      // If on LoggedHomepage, navigate to the notes list.
      if (tester.any(find.textContaining('Bienvenue'))) { // If on LoggedHomepage
        expect(find.byType(DynamicJournalAppBar), findsOneWidget);
        // Assuming MainScreen has BottomNavBar or use AppBar to navigate to Notes
        // Check for active or inactive icon for 'Notes' tab
        Finder notesTabFinder;
        if (tester.any(find.byIcon(Icons.list_alt))) { // Active icon
          notesTabFinder = find.byIcon(Icons.list_alt);
        } else if (tester.any(find.byIcon(Icons.list_alt_outlined))) { // Inactive icon
          notesTabFinder = find.byIcon(Icons.list_alt_outlined);
        } else {
          // Fallback: try to find via text if icons aren't unique enough or state changes them
          notesTabFinder = find.text('Notes');
        }
        await tester.tap(notesTabFinder);
        await tester.pumpAndSettle();
      }

      // On NoteListPage for "Mon Journal de Test"
      expect(find.text('Mon Journal de Test'), findsOneWidget); // AppBar title on NoteListPage
      // Verify the note content is displayed
      expect(find.text('Ceci est ma première note de test d\'intégration !'), findsOneWidget);
      // Also check for the color association if possible (e.g., colorData.title is shown in the list item)
      expect(find.text('Couleur Test'), findsOneWidget);
    });

    // Add more journal and note management tests here.
  });
}
