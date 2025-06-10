// fichier: lib/main.dart

import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:colors_notes/providers/language_provider.dart';
import 'package:colors_notes/screens/auth_gate.dart';
import 'package:colors_notes/screens/help_page.dart';
import 'package:colors_notes/screens/main_screen.dart';
import 'package:colors_notes/screens/privacy_policy_page.dart';
import 'package:colors_notes/screens/register_page.dart';
import 'package:colors_notes/screens/settings_page.dart';
import 'package:colors_notes/screens/sign_in_page.dart';
import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/cookie_consent_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

// Imports pour les configurations Firebase par environnement
import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
import 'firebase_options_staging.dart' as staging_options;

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, printEmojis: true));

// Détermine l'environnement de build (dev, staging, prod)
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

// POINT D'ENTRÉE DE L'APPLICATION
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();

  final firestoreService = FirestoreService(FirebaseFirestore.instance);
  final authService = AuthService(
    FirebaseAuth.instance,
    GoogleSignIn(),
    firestoreService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: authService),
        Provider.value(value: firestoreService),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(
          create: (_) => ActiveJournalNotifier(authService, firestoreService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Initialise les services essentiels comme Firebase et la localisation.
Future<void> _initializeServices() async {
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null);

  FirebaseOptions options;
  switch (appEnv) {
    case 'prod':
      options = prod_options.DefaultFirebaseOptions.currentPlatform;
      break;
    case 'staging':
      options = staging_options.DefaultFirebaseOptions.currentPlatform;
      break;
    default: // dev
      options = dev_options.DefaultFirebaseOptions.currentPlatform;
  }

  try {
    await Firebase.initializeApp(options: options);
    _logger.i('Firebase initialisé pour l\'environnement : $appEnv');
  } catch (e) {
    _logger.e('Erreur d\'initialisation de Firebase', error: e);
  }
}

// WIDGET RACINE DE L'APPLICATION
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final CookieConsentService _cookieConsentService = CookieConsentService();
  late final Future<void> _initAppFuture;

  @override
  void initState() {
    super.initState();
    _initAppFuture = _initializeAsyncDependencies();
  }

  Future<void> _initializeAsyncDependencies() async {
    await _cookieConsentService.initialize();
    if (mounted) {
      await _updateAnalyticsConsentFromPreferences();
    }
  }

  Future<void> _updateAnalyticsConsentFromPreferences() async {
    bool isAnalyticsEnabled = !kIsWeb;
    if (kIsWeb) {
      final preferences = _cookieConsentService.preferences;
      isAnalyticsEnabled = preferences['analytics'] ?? false;
    }
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(isAnalyticsEnabled);
      _logger.i('Collecte Firebase Analytics ${isAnalyticsEnabled ? 'activée' : 'désactivée'}.');
    } catch (e) {
      _logger.e("Erreur de configuration Firebase Analytics", error: e);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (languageProvider.isLoading) {
          return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }

        return FutureBuilder<void>(
          future: _initAppFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MaterialApp(
                  home: Scaffold(body: Center(child: CircularProgressIndicator())));
            }
            if (snapshot.hasError) {
              return MaterialApp(
                  home: Scaffold(
                      body: Center(
                          child: Text(
                              "Erreur d'initialisation : ${snapshot.error}"))));
            }
            return _buildMaterialApp(languageProvider.appLocale);
          },
        );
      },
    );
  }

  /// Construit le widget MaterialApp principal.
  Widget _buildMaterialApp(Locale currentLocale) {
    return MaterialApp(
      title: 'Colors & Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: Colors.amberAccent),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: currentLocale,
      home :  AuthGate(),
      initialRoute: '/',
      routes: {
        '/signin': (context) => const SignInPage(),
        '/register': (context) => const RegisterPage(),
        '/main': (context) => const MainScreen(),
        '/settings': (context) => const SettingsPage(),
        '/help': (context) => const HelpPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/privacy') {
          return MaterialPageRoute(builder: (context) => const PrivacyPolicyPage());
        }
        return MaterialPageRoute(builder: (context) => const AuthGate());
      },
      builder: (context, child) {
        if (kIsWeb && _cookieConsentService.shouldShowBanner) {
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              // Utilisation du widget de bandeau personnalisé et isolé
              _CustomCookieBanner(
                onAccept: () async {
                  await _cookieConsentService
                      .savePreferences({'analytics': true});
                  _updateAnalyticsConsentFromPreferences();
                },
                onDecline: () async {
                  await _cookieConsentService
                      .savePreferences({'analytics': false});
                  _updateAnalyticsConsentFromPreferences();
                },
              ),
            ],
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

/// **NOUVEAU** : Un widget stateless dédié uniquement à l'affichage du bandeau.
/// Cela garantit qu'il est construit avec un contexte valide.
class _CustomCookieBanner extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _CustomCookieBanner({required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    // Ce contexte est maintenant garanti d'être un descendant de MaterialApp
    // et peut donc accéder aux localisations en toute sécurité.
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink(); // Ne rien afficher si les traductions ne sont pas prêtes.
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 8,
        child: Container(
          color: const Color(0xFF37474F), // Equivalent de Colors.blueGrey[800]
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cookieConsentMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 24),
              TextButton(
                onPressed: onDecline,
                child: Text(
                  l10n.cookieConsentDecline,
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    )
                ),
                child: Text(l10n.cookieConsentAcceptAll),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
