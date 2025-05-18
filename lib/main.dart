import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_cookie_consent/flutter_cookie_consent.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'providers/active_journal_provider.dart';

import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart';
import 'screens/register_page.dart';
import 'screens/main_screen.dart';

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
  final FlutterCookieConsent _cookieConsent = FlutterCookieConsent();
  late final Future<void> _initConsentFuture;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initConsentFuture = _cookieConsent.initialize().then((_) {
        if (mounted) {
          _updateAnalyticsConsentFromPreferences();
        }
      });
    } else {
      _initConsentFuture = Future.value();
      _applyAnalyticsConsent(true);
      _logger.i("Plateforme non-web, consentement analytique activé par défaut.");
    }
  }

  Future<void> _updateAnalyticsConsentFromPreferences() async {
    final preferences = _cookieConsent.preferences;
    final analyticsEnabled = preferences['analytics'] ?? false;
    await _applyAnalyticsConsent(analyticsEnabled);
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
      // Le contenu d'accueil est passé en paramètre
      routes: {'/signin': (context) => const SignInPage(), '/register': (context) => const RegisterPage(), '/main': (context) => MainScreen()},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return _buildAppShell(homeWidget: AuthGate());
    }

    return FutureBuilder<void>(
      future: _initConsentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }

        if (snapshot.hasError) {
          _logger.e("Erreur initialisation flutter_cookie_consent: ${snapshot.error}");
          return MaterialApp(home: Scaffold(body: Center(child: Text("Erreur module consentement: ${snapshot.error}"))));
        }

        Widget mainAppContent = AuthGate();

        if (_cookieConsent.shouldShowBanner) {
          mainAppContent = Stack(
            children: [
              AuthGate(),
              _cookieConsent.createBanner(
                context: context,
                title: 'Gestion des Cookies',
                message:
                    "Nous utilisons des cookies pour améliorer votre expérience. Les cookies essentiels sont nécessaires au fonctionnement du site. Acceptez-vous l'utilisation de cookies analytiques pour nous aider à améliorer nos services ?",
                acceptButtonText: 'Tout Accepter',
                declineButtonText: 'Refuser les cookies analytiques',
                settingsButtonText: 'Paramètres',
                showSettings: true,
                position: BannerPosition.bottom,
                onAccept: (bool accepted) async {
                  _logger.i('Bouton "Tout Accepter" cliqué. Valeur booléenne reçue: $accepted');
                  var currentPrefs = _cookieConsent.preferences;
                  currentPrefs['analytics'] = true;
                  await _cookieConsent.savePreferences(currentPrefs);
                  await _updateAnalyticsConsentFromPreferences();
                },
                onDecline: (bool declined) async {
                  _logger.i('Bouton "Refuser Analytiques" cliqué. Valeur booléenne reçue: $declined');
                  var currentPrefs = _cookieConsent.preferences;
                  currentPrefs['analytics'] = false;
                  await _cookieConsent.savePreferences(currentPrefs);
                  await _updateAnalyticsConsentFromPreferences();
                },
                onSettings: () {
                  _logger.i('Ouverture des paramètres de cookies.');
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
        return _buildAppShell(homeWidget: mainAppContent);
      },
    );
  }
}
