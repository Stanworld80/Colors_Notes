import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importer User
import 'package:provider/provider.dart'; // Importer Provider

// Importer vos services
import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';

// Importer vos écrans
import 'package:colors_notes/screens/entry_page.dart';
import 'package:colors_notes/screens/logged_homepage.dart';
import 'package:colors_notes/screens/register_page.dart';
import 'package:colors_notes/screens/sign_in_page.dart';

import 'firebase_options.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // On lance l'application en l'enrobant avec MultiProvider
  runApp(
    MultiProvider(
      providers: [
        // 1. Fournir l'instance de AuthService
        Provider<AuthService>(create: (_) => AuthService()),
        // 2. Fournir l'instance de FirestoreService
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        // 3. Fournir le flux (Stream) de l'état d'authentification Firebase
        //    Ce Stream émettra null si déconnecté, ou l'objet User si connecté.
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges, // Utilise AuthService fourni ci-dessus
          initialData: null, // Donnée initiale avant que le Stream n'émette
        ),

        ChangeNotifierProvider<ActiveJournalNotifier>(create: (_) => ActiveJournalNotifier()),
      ],
      child: const MyApp(), // L'application elle-même est l'enfant
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colors & Notes', // Mis à jour le titre
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, // Optionnel: activer Material 3
      ),
      // Les routes restent les mêmes pour l'instant
      // EntryPage sera maintenant capable d'utiliser Provider pour l'état d'auth
      initialRoute: '/', // Assurez-vous que EntryPage est bien la route initiale
      routes: {
        '/': (context) => const EntryPage(),
        '/signin': (context) => const SignInPage(),
        '/register': (context) => const RegisterPage(),
        '/logged_homepage': (context) => const LoggedHomepage(),
      },
    );
  }
}
