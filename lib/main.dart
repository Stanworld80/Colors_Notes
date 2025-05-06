import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import pour intl

import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';

import 'package:colors_notes/screens/entry_page.dart';
import 'package:colors_notes/screens/logged_homepage.dart';
import 'package:colors_notes/screens/register_page.dart';
import 'package:colors_notes/screens/sign_in_page.dart';

import 'firebase_options.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialisation pour le package intl (DateFormatting)
  // Vous pouvez spécifier une locale par défaut si nécessaire, ex: 'fr_FR'
  await initializeDateFormatting(null);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
        ChangeNotifierProvider<ActiveJournalNotifier>(create: (_) => ActiveJournalNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Colors & Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const EntryPage(),
        '/signin': (context) => const SignInPage(),
        '/register': (context) => const RegisterPage(),
        '/logged_homepage': (context) => const LoggedHomepage(),
      },
    );
  }
}
