// fichier: lib/services/cookie_consent_service_stub.dart
// Implémentation "stub" (vide ou par défaut) pour les plateformes non-web.

import 'package:flutter/material.dart';

// PAS D'IMPORT de 'package:flutter_cookie_consent/flutter_cookie_consent.dart'
// PAS D'IMPORT de 'dart:js_interop' ou 'dart:html'

/// Service de consentement aux cookies - Implémentation STUB pour non-web.
///
/// Cette classe fournit une interface cohérente pour le service de consentement,
/// mais avec des implémentations vides ou par défaut pour les plateformes
/// où le bandeau de cookies web n'est pas applicable.
class CookieConsentService {
  /// Constructeur.
  CookieConsentService() {
    debugPrint("CookieConsentService: Stub (non-web) initialized.");
  }

  /// Initialise le service. Pour le stub, cela peut ne rien faire.
  Future<void> initialize() async {
    debugPrint("CookieConsentService: Stub initialize() called.");
    // Aucune initialisation réelle nécessaire pour le stub.
  }

  /// Indique si le bandeau de consentement doit être affiché.
  ///
  /// Sur les plateformes non-web, retourne toujours `false`.
  bool get shouldShowBanner {
    debugPrint("CookieConsentService: Stub shouldShowBanner called, returning false.");
    return false;
  }

  /// Récupère les préférences de consentement actuelles de l'utilisateur.
  ///
  /// Sur les plateformes non-web, retourne une map vide ou des valeurs par défaut.
  Map<String, bool> get preferences {
    debugPrint("CookieConsentService: Stub preferences called, returning empty map.");
    return {};
  }

  /// Sauvegarde les préférences de consentement de l'utilisateur.
  ///
  /// Sur les plateformes non-web, cette méthode peut ne rien faire.
  Future<void> savePreferences(Map<String, bool> prefs) async {
    debugPrint("CookieConsentService: Stub savePreferences() called with $prefs. No action taken.");
  }

  /// Crée et retourne le widget du bandeau de consentement.
  ///
  /// Sur les plateformes non-web, retourne un widget vide (SizedBox.shrink)
  /// car le bandeau n'est pas pertinent.
  Widget createBanner({
    required BuildContext context,
    required String title,
    required String message,
    required String acceptButtonText,
    String? declineButtonText,
    String? settingsButtonText,
    bool showSettings = false,
    // Le type BannerPosition vient du package web, donc on utilise dynamic ici
    // ou un type simple que l'implémentation web peut interpréter.
    dynamic position = 'bottom', // Exemple: 'bottom' ou 'top'
    // Les callbacks doivent avoir des signatures qui n'exposent pas de types spécifiques au package web.
    void Function(bool acceptedAll)? onAccept,
    void Function(bool declinedAll)? onDecline,
    VoidCallback? onSettings,
  }) {
    debugPrint("CookieConsentService: Stub createBanner() called. Returning empty widget.");
    return const SizedBox.shrink();
  }
}