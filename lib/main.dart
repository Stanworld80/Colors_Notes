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

// Imports pour les configurations Firebase par environnement
import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_staging.dart' as staging_options;
import 'firebase_options_prod.dart' as prod_options;

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
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null);

  FirebaseOptions options;
  _logger.i('Environnement APP_ENV détecté : $appEnv');
  switch (appEnv) {
    case 'prod':
      options = prod_options.DefaultFirebaseOptions.currentPlatform;
      _logger.i('Initialisation de Firebase avec les options PROD.');
      break;
    case 'staging':
      options = staging_options.DefaultFirebaseOptions.currentPlatform;
      _logger.i('Initialisation de Firebase avec les options STAGING.');
      break;
    case 'dev':
    default:
      options = dev_options.DefaultFirebaseOptions.currentPlatform;
      _logger.i('Initialisation de Firebase avec les options DEV (ou par défaut).');
      break;
  }

  try {
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
      _logger.d("Préférences de consentement web lues : $preferences, analyticsEnabledTarget: $analyticsEnabledTarget");
    }
    await _applyAnalyticsConsent(analyticsEnabledTarget);
    if (mounted) {
      setState(() {});
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
      _logger.i("LanguageProvider est en cours de chargement...");
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    _logger.i("LanguageProvider chargé, locale : ${languageProvider.appLocale}.");

    return FutureBuilder<void>(
      future: _initConsentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.i("FutureBuilder pour CookieConsent en attente...");
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
        _logger.i("FutureBuilder pour CookieConsent terminé.");

        Widget mainAppContent = const AuthGate();

        if (kIsWeb && _cookieConsentService.shouldShowBanner) {
          mainAppContent = Stack(
            children: [
              const AuthGate(),
              Align(
                alignment: Alignment.bottomCenter,
                child: Builder(
                    builder: (BuildContext bannerBuildContext) {
                      final l10n = AppLocalizations.of(bannerBuildContext);

                      // Fallbacks pour les chaînes si l10n est null ou si les clés spécifiques sont nulles.
                      // La VRAIE solution est de s'assurer que les traductions existent.
                      String cookieTitle = "Consentement aux Cookies"; // Fallback
                      String cookieMessage = "Nous utilisons des cookies..."; // Fallback
                      String cookieAccept = "Tout Accepter"; // Fallback
                      String cookieDecline = "Refuser"; // Fallback
                      String cookieSettings = "Paramètres"; // Fallback

                      if (l10n != null) {
                        try {
                          cookieTitle = l10n.cookieConsentTitle;
                          cookieMessage = l10n.cookieConsentMessage;
                          cookieAccept = l10n.cookieConsentAcceptAll;
                          cookieDecline = l10n.cookieConsentDecline;
                          cookieSettings = l10n.cookieConsentSettings;
                          _logger.i("Affichage du bandeau de consentement aux cookies avec textes localisés.");
                        } catch (e) {
                          _logger.e("Erreur lors de l'accès aux clés de localisation pour le bandeau de cookies. Utilisation des fallbacks. Erreur: $e");
                          // Les fallbacks définis ci-dessus seront utilisés.
                        }
                      } else {
                        _logger.w("AppLocalizations.of(bannerBuildContext) est null. Utilisation des fallbacks pour le bandeau de cookies.");
                      }

                      return _cookieConsentService.createBanner(
                        context: bannerBuildContext,
                        title: cookieTitle,
                        message: cookieMessage,
                        acceptButtonText: cookieAccept,
                        declineButtonText: cookieDecline,
                        settingsButtonText: cookieSettings,
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
                      );
                    }
                ),
              ),
            ],
          );
        } else {
          _logger.i("Le bandeau de consentement aux cookies ne sera pas affiché.");
        }

        return _buildAppShell(homeWidget: mainAppContent, currentLocale: languageProvider.appLocale);
      },
    );
  }
}
