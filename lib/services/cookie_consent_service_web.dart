// fichier: lib/services/cookie_consent_service_web.dart
// Implémentation réelle pour le web utilisant flutter_cookie_consent.

import 'package:flutter/material.dart';
// Importe le package réel avec un alias pour éviter les conflits de nom si CookieConsentService était identique.
import 'package:flutter_cookie_consent/flutter_cookie_consent.dart' as ActualCookieConsent;
import 'package:logger/logger.dart'; // Assurez-vous d'avoir logger dans pubspec.yaml si vous l'utilisez ici

final _loggerWeb = Logger(printer: PrettyPrinter(methodCount:0));

/// Service de consentement aux cookies - Implémentation WEB.
///
/// Cette classe utilise le package `flutter_cookie_consent` pour gérer
/// le consentement sur les plateformes web.
class CookieConsentService {
  final ActualCookieConsent.FlutterCookieConsent _cookieConsentInstance = ActualCookieConsent.FlutterCookieConsent();

  /// Constructeur.
  CookieConsentService() {
    _loggerWeb.i("CookieConsentService: Web implementation initialized.");
  }

  /// Initialise le service de consentement en chargeant les préférences stockées.
  Future<void> initialize() async {
    await _cookieConsentInstance.initialize();
    _loggerWeb.i("CookieConsentService: Web initialize() complete. Preferences loaded.");
  }

  /// Indique si le bandeau de consentement doit être affiché.
  bool get shouldShowBanner {
    final show = _cookieConsentInstance.shouldShowBanner;
    _loggerWeb.d("CookieConsentService: Web shouldShowBanner returning $show.");
    return show;
  }

  /// Récupère les préférences de consentement actuelles de l'utilisateur.
  Map<String, bool> get preferences {
    final prefs = _cookieConsentInstance.preferences;
    _loggerWeb.d("CookieConsentService: Web preferences returning $prefs.");
    return prefs;
  }

  /// Sauvegarde les préférences de consentement de l'utilisateur.
  Future<void> savePreferences(Map<String, bool> prefs) async {
    await _cookieConsentInstance.savePreferences(prefs);
    _loggerWeb.i("CookieConsentService: Web savePreferences() called with $prefs.");
  }

  /// Crée et retourne le widget du bandeau de consentement.
  Widget createBanner({
    required BuildContext context,
    required String title,
    required String message,
    required String acceptButtonText,
    String? declineButtonText,
    String? settingsButtonText,
    bool showSettings = false,
    dynamic position = 'bottom', // Accepte une chaîne ou un BannerPosition
    void Function(bool acceptedAll)? onAccept,
    void Function(bool declinedAll)? onDecline,
    VoidCallback? onSettings,
  }) {
    _loggerWeb.i("CookieConsentService: Web createBanner() called.");

    ActualCookieConsent.BannerPosition bannerPosition;
    if (position is ActualCookieConsent.BannerPosition) {
      bannerPosition = position;
    } else if (position == 'top') {
      bannerPosition = ActualCookieConsent.BannerPosition.top;
    } else {
      bannerPosition = ActualCookieConsent.BannerPosition.bottom;
    }

    return _cookieConsentInstance.createBanner(
      context: context,
      title: title,
      message: message,
      acceptButtonText: acceptButtonText,
      declineButtonText: declineButtonText,
      settingsButtonText: settingsButtonText,
      showSettings: showSettings,
      position: bannerPosition,
      // Les callbacks du package attendent `Function(bool)`
      onAccept: onAccept, // Directement si la signature correspond
      onDecline: onDecline, // Directement si la signature correspond
      onSettings: onSettings,
    );
  }
}