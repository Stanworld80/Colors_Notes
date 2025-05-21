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
import 'providers/language_provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/cookie_consent_service.dart';
import 'providers/active_journal_provider.dart';

import 'screens/auth_gate.dart';
import 'screens/sign_in_page.dart';
import 'screens/register_page.dart';
import 'screens/main_screen.dart';
import 'screens/settings_page.dart';

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, printEmojis: true, colors: true));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialisation pour le formatage des dates en français, par exemple.
  // Vous pouvez ajouter d'autres locales si nécessaire.
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null); // Pour l'anglais si utilisé

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

  // Création du LanguageProvider
  final languageProvider = LanguageProvider();
  // Il est important de charger la locale avant de construire l'UI principale
  // Cependant, LanguageProvider le fait dans son constructeur.
  // Si ce n'était pas le cas, on appellerait await languageProvider.loadLocale(); ici.

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        ChangeNotifierProvider<ActiveJournalNotifier>(create: (context) => ActiveJournalNotifier(authService, firestoreService)),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider), // AJOUTÉ
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
  // LanguageProvider sera accédé via Consumer ou Provider.of dans build

  @override
  void initState() {
    super.initState();
    // L'initialisation du LanguageProvider (chargement de la locale) se fait dans son constructeur.
    // Si ce n'était pas le cas:
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Provider.of<LanguageProvider>(context, listen: false).loadLocale();
    // });

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
      setState(() {});
    }
  }

  Future<void> _applyAnalyticsConsent(bool consented) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(consented);
      _logger.i("Firebase Analytics collection ${consented ? 'activée' : 'désactivée'}.");
    } catch (e) {
      _logger.e("Erreur lors de la configuration de Firebase Analytics: $e");
    }
  }

  Widget _buildAppShell({required Widget homeWidget, required Locale currentLocale}) { // MODIFIÉ pour accepter currentLocale
    return MaterialApp(
      title: 'Colors & Notes', // Sera localisé si vous utilisez AppLocalizations.of(context)!.appName ici
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.amberAccent),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: currentLocale, // MODIFIÉ pour utiliser la locale du provider
      home: homeWidget,
      routes: {
        '/signin': (context) => const SignInPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => const MainScreen(),
        '/settings': (context) => const SettingsPage(), // AJOUTÉ
        // Ajoutez d'autres routes ici
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Consommer LanguageProvider pour obtenir la locale actuelle
    final languageProvider = Provider.of<LanguageProvider>(context);

    // Si LanguageProvider est toujours en train de charger la locale, afficher un indicateur de chargement.
    // Cela évite un flash de contenu non localisé ou avec la mauvaise locale.
    if (languageProvider.isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return FutureBuilder<void>(
      future: _initConsentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp( // MODIFIÉ pour passer la locale ici aussi
            locale: languageProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          _logger.e("Erreur initialisation CookieConsentService: ${snapshot.error}");
          return MaterialApp( // MODIFIÉ
            locale: languageProvider.appLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: Center(child: Text("Erreur module consentement: ${snapshot.error}"))),
          );
        }

        Widget mainPageContent = AuthGate();

        if (kIsWeb && _cookieConsentService.shouldShowBanner) {
          mainPageContent = Stack(
            children: [
              AuthGate(),
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
        // Passer la locale actuelle à _buildAppShell
        return _buildAppShell(homeWidget: mainPageContent, currentLocale: languageProvider.appLocale);
      },
    );
  }
}
