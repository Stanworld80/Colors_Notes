import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/date_symbol_data_local.dart';

// Flutter Localization Imports
import 'package:flutter_localizations/flutter_localizations.dart';
// Import YOUR generated AppLocalizations class!
// The exact path will depend on your setup and package name.
// If your package is 'colors_notes' and app_localizations.dart is in lib/l10n:
import 'package:colors_notes/l10n/app_localizations.dart'; // Adjust if necessary

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'providers/active_journal_provider.dart';
// import 'providers/locale_provider.dart'; // Uncomment if you create a LocaleProvider
import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart';
import 'screens/register_page.dart';
import 'screens/main_screen.dart';

/// Logger instance for application-wide logging.
final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    printEmojis: true,
    colors: true,
  ),
);

/// The main entry point for the application.
///
/// Initializes Firebase, date formatting, and sets up service providers.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize date formatting for French locale before running the app.
  await initializeDateFormatting('fr_FR', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.i('Firebase initialized successfully.');
  } catch (e, stackTrace) {
    _logger.e('Error initializing Firebase', error: e, stackTrace: stackTrace);
  }

  final firebaseAuthInstance = FirebaseAuth.instance;
  final googleSignInInstance = GoogleSignIn();
  final firestoreInstance = FirebaseFirestore.instance;

  final firestoreService = FirestoreService(firestoreInstance);
  final authService = AuthService(firebaseAuthInstance, googleSignInInstance, firestoreService);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<ActiveJournalNotifier>(
          create: (context) => ActiveJournalNotifier(
            authService,
            firestoreService,
          ),
        ),
        // ChangeNotifierProvider<LocaleProvider>( // Add your LocaleProvider here
        //   create: (_) => LocaleProvider(),
        // ),
      ],
      child: const MyApp(),
    ),
  );
}

/// The root widget of the application.
///
/// Configures the [MaterialApp], including theme, localization,
/// and navigation routes.
class MyApp extends StatelessWidget {
  /// Creates the root application widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If using a LocaleProvider for dynamic language switching:
    // final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Colors & Notes', // This title could also be localized later.
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          secondary: Colors.amberAccent,
        ),
      ),

      // --- Crucial Localization Setup ---
      localizationsDelegates: AppLocalizations.localizationsDelegates, // USE THIS
      supportedLocales: AppLocalizations.supportedLocales,       // AND THIS

      // Manage the current locale (either forced, via provider, or system detection)
      // Example with a LocaleProvider (to be created and provided via MultiProvider):
      // locale: localeProvider.locale,

      // OR to force a language on startup for testing:
      locale: const Locale('fr'), // or const Locale('en')

      // OR for more advanced system locale detection:
      // localeResolutionCallback: (locale, supportedLocales) {
      //   if (locale != null) {
      //     for (var supportedLocale in supportedLocales) {
      //       if (supportedLocale.languageCode == locale.languageCode) {
      //         // You can ignore countryCode for a broader match
      //         return supportedLocale;
      //       }
      //     }
      //   }
      //   // If the system locale is not supported, use the first in your list as a fallback
      //   return supportedLocales.first;
      // },

      home: AuthGate(),
      routes: {
        '/signin': (context) => const SignInPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => MainScreen(),
      },
    );
  }
}

// If implementing dynamic language switching, you'll need a LocaleProvider:
// /// Manages the application's current locale.
// class LocaleProvider extends ChangeNotifier {
//   Locale _currentLocale = const Locale('fr'); // Default language

//   /// The currently active locale.
//   Locale get locale => _currentLocale;

//   /// Sets the application's locale.
//   ///
//   /// If the [newLocale] is not among the [AppLocalizations.supportedLocales],
//   /// this method does nothing. Otherwise, it updates the locale and notifies listeners.
//   void setLocale(Locale newLocale) {
//     if (!AppLocalizations.supportedLocales.contains(newLocale)) return;
//     _currentLocale = newLocale;
//     notifyListeners();
//     // Optional: save user preference here (e.g., using shared_preferences)
//   }

//   // Optional: load saved preference on startup
//   // Future<void> loadSavedLocale() async { ... }
// }