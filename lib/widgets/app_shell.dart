// lib/widgets/app_shell.dart
import 'package:colors_notes/widgets/custom_cookie_banner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:colors_notes/services/cookie_consent_service.dart';

/// Une "coquille" qui enveloppe le contenu principal de l'application.
/// Son rôle est d'afficher le bandeau de cookies par-dessus la page actuelle si nécessaire.
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
    // On initialise le service de consentement seulement pour cette coquille.
    if (kIsWeb) {
      _initializeConsent();
    }
  }

  Future<void> _initializeConsent() async {
    await _cookieConsentService.initialize();
    if (mounted) {
      setState(() {
        _showBanner = _cookieConsentService.shouldShowBanner;
      });
    }
  }

  Future<void> _updateAnalyticsConsent(bool consented) async {
    await _cookieConsentService.savePreferences({'analytics': consented});
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(consented);
    if (mounted) {
      setState(() {
        _showBanner = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Affiche le contenu de la page actuelle (ex: AuthGate, SettingsPage).
          widget.child,
          // Affiche le bandeau par-dessus si les conditions sont remplies.
          if (kIsWeb && _showBanner)
            CustomCookieBanner(
              onAccept: () => _updateAnalyticsConsent(true),
              onDecline: () => _updateAnalyticsConsent(false),
            ),
        ],
      ),
    );
  }
}
