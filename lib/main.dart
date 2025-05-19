// fichier: lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:colors_notes/l10n/app_localizations.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/cookie_consent_service.dart';
import 'providers/active_journal_provider.dart';

import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart';
import 'screens/register_page.dart';
import 'screens/main_screen.dart';

// NE PAS IMPORTER 'package:flutter_cookie_consent/flutter_cookie_consent.dart' DIRECTEMENT ICI

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, printEmojis: true, colors: true));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        ChangeNotifierProvider<ActiveJournalNotifier>(create: (context) => ActiveJournalNotifier(authService, firestoreService)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Utilise le service abstrait/conditionnel
  final CookieConsentService _cookieConsentService = CookieConsentService();
  late final Future<void> _initConsentFuture;

  @override
  void initState() {
    super.initState();
    // L'initialisation du service est toujours appelée.
    // Sur non-web, l'implémentation stub sera utilisée.
    _initConsentFuture = _cookieConsentService.initialize().then((_) {
      if (mounted) {
        // Mettre à jour le consentement analytique basé sur les préférences chargées
        // (ou les valeurs par défaut du stub sur non-web).
        _updateAnalyticsConsentFromPreferences();
      }
    });

    // Logique spécifique à la plateforme pour la configuration initiale de l'analytique
    // si elle ne dépend pas du service de consentement (par exemple, activer par défaut sur mobile).
    if (!kIsWeb) {
      _applyAnalyticsConsent(true); // Exemple: activer par défaut pour non-web
      _logger.i("Plateforme non-web, consentement analytique activé par défaut (hors service cookie).");
    }
  }

  /// Lit les préférences via le service et met à jour Firebase Analytics.
  Future<void> _updateAnalyticsConsentFromPreferences() async {
    // kIsWeb est utilisé ici pour s'assurer que nous ne nous basons sur les préférences
    // du service que si nous sommes sur le web. Sur mobile, le stub retourne des valeurs par défaut.
    bool analyticsEnabledTarget = !kIsWeb; // Par défaut à true pour non-web

    if (kIsWeb) {
      final preferences = _cookieConsentService.preferences;
      analyticsEnabledTarget = preferences['analytics'] ?? false;
    }

    await _applyAnalyticsConsent(analyticsEnabledTarget);

    // Rafraîchir l'état pour reconstruire l'UI si shouldShowBanner a changé.
    if (mounted) {
      setState(() {});
    }
  }

  /// Applique le consentement pour Firebase Analytics.
  Future<void> _applyAnalyticsConsent(bool consented) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(consented);
      _logger.i("Firebase Analytics collection ${consented ? 'activée' : 'désactivée'}.");
    } catch (e) {
      _logger.e("Erreur lors de la configuration de Firebase Analytics: $e");
    }
  }

  /// Construit le widget MaterialApp de base avec un contenu d'accueil dynamique.
  Widget _buildAppShell({required Widget homeWidget}) {
    return MaterialApp(
      title: 'Colors & Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.amberAccent),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: homeWidget,
      routes: {'/signin': (context) => const SignInPage(), '/register': (context) => const RegisterPage(), '/main': (context) => MainScreen()},
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pour les plateformes non-web, le service stub sera utilisé,
    // et `shouldShowBanner` retournera false.
    // `_buildAppShell` est toujours utilisé.

    return FutureBuilder<void>(
      future: _initConsentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            // Fournir un MaterialApp pendant le chargement
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          _logger.e("Erreur initialisation CookieConsentService: ${snapshot.error}");
          return MaterialApp(
            // Fournir un MaterialApp pour l'erreur
            home: Scaffold(body: Center(child: Text("Erreur module consentement: ${snapshot.error}"))),
          );
        }

        // L'initialisation est terminée.
        Widget mainPageContent = AuthGate(); // Contenu principal par défaut

        // Le bandeau ne sera construit que si kIsWeb est vrai ET shouldShowBanner est vrai.
        if (kIsWeb && _cookieConsentService.shouldShowBanner) {
          mainPageContent = Stack(
            children: [
              AuthGate(), // Le contenu principal
              // Utilise le service pour créer le bandeau.
              // Sur non-web, createBanner du stub retournera SizedBox.shrink().
              // Mais cette branche if(kIsWeb...) empêche son appel sur non-web.
              _cookieConsentService.createBanner(
                context: context,
                title: 'Gestion des Cookies',
                message:
                    "Nous utilisons des cookies pour améliorer votre expérience. Les cookies essentiels sont nécessaires au fonctionnement du site. Acceptez-vous l'utilisation de cookies analytiques pour nous aider à améliorer nos services ?",
                acceptButtonText: 'Tout Accepter',
                declineButtonText: 'Refuser',
                settingsButtonText: 'Paramètres',
                showSettings: true,
                position: 'bottom',
                // Le service web gère la conversion en BannerPosition
                onAccept: (bool accepted) async {
                  _logger.i('Service: Bouton "Tout Accepter" cliqué. Valeur booléenne reçue: $accepted');
                  // L'implémentation web de savePreferences mettra à jour les préférences réelles.
                  var currentPrefs = _cookieConsentService.preferences; // Lire les prefs actuelles
                  currentPrefs['analytics'] = true; // Modifier
                  await _cookieConsentService.savePreferences(currentPrefs); // Sauvegarder via le service
                  await _updateAnalyticsConsentFromPreferences(); // Mettre à jour l'état et l'analytique
                },
                onDecline: (bool declined) async {
                  _logger.i('Service: Bouton "Refuser Analytiques" cliqué. Valeur booléenne reçue: $declined');
                  var currentPrefs = _cookieConsentService.preferences;
                  currentPrefs['analytics'] = false;
                  await _cookieConsentService.savePreferences(currentPrefs);
                  await _updateAnalyticsConsentFromPreferences();
                },
                onSettings: () {
                  _logger.i('Service: Ouverture des paramètres de cookies.');
                  // Après la fermeture du dialogue de paramètres (géré par le package dans l'implémentation web),
                  // les préférences devraient être mises à jour. Nous rappelons
                  // _updateAnalyticsConsentFromPreferences pour refléter ces changements.
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _updateAnalyticsConsentFromPreferences();
                    }
                  });
                },
              ),
            ],
          );
        }
        return _buildAppShell(homeWidget: mainPageContent);
      },
    );
  }
}
