// fichier: lib/main.dart

// Imports pour les configurations Firebase par environnement
// Assurez-vous que ces fichiers existent bien dans lib/
import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_staging.dart' as staging_options;
import 'firebase_options_prod.dart' as prod_options;

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
import 'providers/language_provider.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/cookie_consent_service.dart';
import 'providers/active_journal_provider.dart';

import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart';
import 'screens/register_page.dart';
import 'screens/main_screen.dart';
import 'screens/settings_page.dart';
import 'screens/help_page.dart';


final _logger = Logger(printer: PrettyPrinter(methodCount: 1, dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, printEmojis: true, colors: true));

const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialisation pour le formatage des dates.
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null);

  FirebaseOptions options;

  // Sélection des options Firebase en fonction de l'environnement
  switch (appEnv) {
    case 'prod':
      options = prod_options.DefaultFirebaseOptions.currentPlatform;
      _logger.i('Firebase initialisé avec les options PROD.');
      break;
    case 'staging':
      options = staging_options.DefaultFirebaseOptions.currentPlatform;
      _logger.i('Firebase initialisé avec les options STAGING.');
      break;
    case 'dev':
    default: // 'dev' ou toute autre valeur non reconnue utilisera les options dev
      options = dev_options.DefaultFirebaseOptions.currentPlatform;
      _logger.i('Firebase initialisé avec les options DEV.');
      break;
  }

  try {
    // Initialisation de Firebase avec les options sélectionnées
    await Firebase.initializeApp(options: options);
    _logger.i('Firebase initialisé avec succès pour l\'environnement : $appEnv');
  } catch (e, stackTrace) {
    _logger.e('Erreur lors de l\'initialisation de Firebase pour l\'environnement : $appEnv', error: e, stackTrace: stackTrace);
  }

  final firebaseAuthInstance = FirebaseAuth.instance;
  final googleSignInInstance = GoogleSignIn();
  final firestoreInstance = FirebaseFirestore.instance;

  final firestoreService = FirestoreService(firestoreInstance);
  final authService = AuthService(firebaseAuthInstance, googleSignInInstance, firestoreService);

  final languageProvider = LanguageProvider();
  // Le chargement de la locale se fait dans le constructeur de LanguageProvider

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<ActiveJournalNotifier>(create: (context) => ActiveJournalNotifier(authService, firestoreService)),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
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
  final CookieConsentService _cookieConsentService = CookieConsentService();
  late final Future<void> _initConsentFuture;

  @override
  void initState() {
    super.initState();
    _initConsentFuture = _cookieConsentService.initialize().then((_) {
      if (mounted) {
        _updateAnalyticsConsentFromPreferences();
      }
    });

    if (!kIsWeb) {
      _applyAnalyticsConsent(true);
      _logger.i("Plateforme non-web, consentement analytique activé par défaut (hors service cookie).");
    }
  }

  Future<void> _updateAnalyticsConsentFromPreferences() async {
    bool analyticsEnabledTarget = !kIsWeb;

    if (kIsWeb) {
      final preferences = _cookieConsentService.preferences;
      analyticsEnabledTarget = preferences['analytics'] ?? false;
    }

    await _applyAnalyticsConsent(analyticsEnabledTarget);
    if (mounted) {
      setState(() {}); // Pour reconstruire si le bandeau de consentement doit disparaître
    }
  }

  Future<void> _applyAnalyticsConsent(bool consented) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(consented);
      _logger.i("Collecte Firebase Analytics ${consented ? 'activée' : 'désactivée'}.");
    } catch (e) {
      _logger.e("Erreur lors de la configuration de Firebase Analytics: $e");
    }
  }

  Widget _buildAppShell({required Widget homeWidget, required Locale currentLocale}) {
    return MaterialApp(
      title: 'Colors & Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.amberAccent),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: currentLocale,
      home: homeWidget,
      routes: {
        '/signin': (context) => const SignInPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => const MainScreen(),
        '/settings': (context) => const SettingsPage(),
        '/help': (context) => const HelpPage(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (languageProvider.isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return FutureBuilder<void>(
      future: _initConsentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            locale: languageProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          _logger.e("Erreur initialisation CookieConsentService: ${snapshot.error}");
          return MaterialApp(
            locale: languageProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: Center(child: Text("Erreur module consentement: ${snapshot.error}"))),
          );
        }

        Widget mainPageContent = const AuthGate();

        if (kIsWeb && _cookieConsentService.shouldShowBanner) {
          final l10n = AppLocalizations.of(context)!; // Accès à l10n ici
          mainPageContent = Stack(
            children: [
              const AuthGate(),
              _cookieConsentService.createBanner(
                context: context,
                title: l10n.cookieConsentTitle,
                message: l10n.cookieConsentMessage,
                acceptButtonText: l10n.cookieConsentAcceptAll,
                declineButtonText: l10n.cookieConsentDecline,
                settingsButtonText: l10n.cookieConsentSettings,
                showSettings: true,
                position: 'bottom',
                onAccept: (bool accepted) async {
                  _logger.i('Service: Bouton "Tout Accepter" cliqué. Valeur booléenne reçue: $accepted');
                  var currentPrefs = _cookieConsentService.preferences;
                  currentPrefs['analytics'] = true;
                  await _cookieConsentService.savePreferences(currentPrefs);
                  await _updateAnalyticsConsentFromPreferences();
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
        return _buildAppShell(homeWidget: mainPageContent, currentLocale: languageProvider.appLocale);
      },
    );
  }
}
