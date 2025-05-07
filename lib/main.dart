import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Import pour les localisations

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'providers/active_journal_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart';
import 'screens/register_page.dart';
import 'screens/main_screen.dart';

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    printTime: true,
    printEmojis: true,
    colors: true,
  ),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialiser le formatage pour le français AVANT runApp
  await initializeDateFormatting('fr_FR', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.i('Firebase initialisé avec succès.');
  } catch (e, stackTrace) {
    _logger.e('Erreur lors de l\'initialisation de Firebase', error: e, stackTrace: stackTrace);
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
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colors & Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          secondary: Colors.amberAccent,
        ),
      ),
      // --- Configuration des Localisations ---
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // Pour les widgets style iOS si utilisés
      ],
      supportedLocales: [
        const Locale('fr', 'FR'), // Français
        const Locale('en', 'US'), // Anglais (langue par défaut/fallback)
        // Ajoutez d'autres langues si nécessaire
      ],
      locale: const Locale('fr', 'FR'), // Optionnel: Forcer la locale française par défaut

      home: AuthGate(),
      routes: {
        '/signin': (context) => SignInPage(),
        '/register': (context) => RegisterPage(),
        '/main': (context) => MainScreen(),
      },
    );
  }
}
