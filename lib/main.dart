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
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options_dev.dart' as dev_options;
import 'firebase_options_prod.dart' as prod_options;
import 'firebase_options_staging.dart' as staging_options;

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, printEmojis: true));
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServices();

  final firestoreService = FirestoreService(FirebaseFirestore.instance);
  final authService = AuthService(FirebaseAuth.instance, GoogleSignIn(), firestoreService);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: authService),
        Provider.value(value: firestoreService),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ActiveJournalNotifier(authService, firestoreService)),
      ],
      child: const AppInitializer(), // On commence par un widget d'initialisation
    ),
  );
}

Future<void> _initializeServices() async {
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('en_US', null);
  final options = _getFirebaseOptions();
  try {
    await Firebase.initializeApp(options: options);
    _logger.i('Firebase initialisé pour l\'environnement : $appEnv');
  } catch (e) {
    _logger.e('Erreur d\'initialisation de Firebase', error: e);
  }
}

FirebaseOptions _getFirebaseOptions() {
  switch (appEnv) {
    case 'prod': return prod_options.DefaultFirebaseOptions.currentPlatform;
    case 'staging': return staging_options.DefaultFirebaseOptions.currentPlatform;
    default: return dev_options.DefaultFirebaseOptions.currentPlatform;
  }
}

/// Widget qui gère l'initialisation asynchrone des providers
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadAsyncData();
  }

  Future<void> _loadAsyncData() async {
    // On récupère les providers et on appelle leurs méthodes d'initialisation.
    // C'est sûr de le faire ici car ce widget est un enfant de MultiProvider.
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.loadLocale();

    // Le ActiveJournalNotifier est maintenant initialisé depuis AuthGate,
    // ce qui est une meilleure pratique car son état dépend de celui de l'authentification.
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) {
          return MaterialApp(home: Scaffold(body: Center(child: Text('Erreur: ${snapshot.error}'))));
        }
        // Une fois l'initialisation terminée, on affiche l'application principale.
        return const MyApp();
      },
    );
  }
}


/// Le widget principal de l'application, maintenant plus simple.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // On utilise Consumer pour réagir aux changements de langue.
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'Colors & Notes',
          theme: ThemeData(
            primarySwatch: Colors.teal,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.amberAccent),
          ),
          locale: languageProvider.appLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          initialRoute: '/',
          routes: {
            '/': (context) => const AppShell(child: AuthGate()),
            '/signin': (context) => const AppShell(child: SignInPage()),
            '/register': (context) => const AppShell(child: RegisterPage()),
            '/main': (context) => const AppShell(child: MainScreen()),
            '/settings': (context) => const AppShell(child: SettingsPage()),
            '/help': (context) => const AppShell(child: HelpPage()),
            '/privacy': (context) => const AppShell(child: PrivacyPolicyPage()),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/privacy/') {
              return MaterialPageRoute(builder: (context) => const AppShell(child: PrivacyPolicyPage()));
            }
            return MaterialPageRoute(builder: (context) => const AppShell(child: AuthGate()));
          },
        );
      },
    );
  }
}

/// Un widget "coquille" qui gère l'affichage du bandeau de cookies par-dessus le contenu principal.
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final CookieConsentService _cookieConsentService = CookieConsentService();
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _initializeConsent();
  }

  Future<void> _initializeConsent() async {
    await _cookieConsentService.initialize();
    if (mounted) {
      setState(() {
        _showBanner = _cookieConsentService.shouldShowBanner;
      });
      _updateAnalyticsConsent();
    }
  }

  Future<void> _updateAnalyticsConsent() async {
    final prefs = _cookieConsentService.preferences;
    final isAnalyticsEnabled = prefs['analytics'] ?? false;
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(isAnalyticsEnabled);
    _logger.i('Collecte Firebase Analytics ${isAnalyticsEnabled ? 'activée' : 'désactivée'}.');
  }

  void _handleAccept() {
    _cookieConsentService.savePreferences({'analytics': true});
    setState(() => _showBanner = false);
    _updateAnalyticsConsent();
  }

  void _handleDecline() {
    _cookieConsentService.savePreferences({'analytics': false});
    setState(() => _showBanner = false);
    _updateAnalyticsConsent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (kIsWeb && _showBanner)
            _CustomCookieBanner(onAccept: _handleAccept, onDecline: _handleDecline),
        ],
      ),
    );
  }
}

// Widget pour le bandeau de cookies (inchangé)
class _CustomCookieBanner extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _CustomCookieBanner({required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 8,
        child: Container(
          color: const Color(0xFF37474F),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.cookieConsentMessage ?? 'We use cookies to enhance your experience.',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 24),
              TextButton(
                onPressed: onDecline,
                child: Text(
                  l10n.cookieConsentDecline ?? 'Decline',
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
                    )),
                child: Text(l10n.cookieConsentAcceptAll ?? 'Accept All'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
