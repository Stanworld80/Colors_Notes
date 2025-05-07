import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/date_symbol_data_local.dart'; // Pour le formatage des dates en français

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'providers/active_journal_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart'; // Importer pour les routes
import 'screens/register_page.dart'; // Importer pour les routes
import 'screens/main_screen.dart'; // Importer pour les routes (si nécessaire)

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
  await initializeDateFormatting('fr_FR', null); // Initialisation pour le français

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
  // Retiré const car MyApp n'est pas const à cause de MaterialApp et des routes
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colors & Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal, // Changé pour un autre thème
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
          secondary: Colors.amberAccent, // Couleur d'accentuation
        ),
        // Vous pouvez ajouter d'autres configurations de thème ici
      ),
      home: AuthGate(), // AuthGate gère la redirection initiale
      routes: {
        // Définir les routes nommées utilisées dans l'application
        '/signin': (context) => SignInPage(),
        '/register': (context) => RegisterPage(),
        '/main': (context) => MainScreen(), // Si vous naviguez vers MainScreen par nom
        // Ajoutez d'autres routes ici si nécessaire
      },

    );
  }
}
