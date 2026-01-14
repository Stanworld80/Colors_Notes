// lib/services/bootstrap.dart
import 'package:colors_notes/providers/language_provider.dart';
import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';

import '../firebase_options_dev.dart' as dev_options;
import '../firebase_options_prod.dart' as prod_options;
import '../firebase_options_staging.dart' as staging_options;

final _logger = Logger();

/// Contient toutes les instances de services initialisées avant le démarrage de l'application.
class AppBootstrap {
  final AuthService authService;
  final FirestoreService firestoreService;
  final LanguageProvider languageProvider;

  AppBootstrap({
    required this.authService,
    required this.firestoreService,
    required this.languageProvider,
  });

  /// Méthode statique qui crée et initialise tous les services de l'application.
  static Future<AppBootstrap> create() async {
    // 1. Configurer le routage web pour des URLs propres (sans #)
    usePathUrlStrategy();

    // 2. Initialiser les bindings Flutter
    WidgetsFlutterBinding.ensureInitialized();

    // 3. Initialiser la localisation pour les dates
    await initializeDateFormatting('fr_FR', null);
    await initializeDateFormatting('en_US', null);

    // 4. Initialiser Firebase avec les options de l'environnement actuel
    const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    final firebaseOptions = _getFirebaseOptions(appEnv);
    await Firebase.initializeApp(options: firebaseOptions);
    _logger.i('Firebase initialisé pour l\'environnement : $appEnv');

    // 5. Instancier les services de bas niveau
    final firestoreService = FirestoreService(FirebaseFirestore.instance);
    final authService = AuthService(FirebaseAuth.instance, GoogleSignIn(scopes: []), firestoreService);

    // 6. Instancier et charger les providers qui nécessitent une initialisation asynchrone
    final languageProvider = LanguageProvider();
    await languageProvider.loadLocale();

    // 7. Retourner l'objet bootstrap contenant tous les services prêts à l'emploi
    return AppBootstrap(
      authService: authService,
      firestoreService: firestoreService,
      languageProvider: languageProvider,
    );
  }

  static FirebaseOptions _getFirebaseOptions(String env) {
    switch (env) {
      case 'prod': return prod_options.DefaultFirebaseOptions.currentPlatform;
      case 'staging': return staging_options.DefaultFirebaseOptions.currentPlatform;
      default: return dev_options.DefaultFirebaseOptions.currentPlatform;
    }
  }
}
