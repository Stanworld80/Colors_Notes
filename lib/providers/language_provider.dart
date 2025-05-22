// lib/providers/language_provider.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../l10n/app_localizations.dart'; // Pour accéder à AppLocalizations.supportedLocales

final _logger = Logger();

class LanguageProvider with ChangeNotifier {
  Locale? _appLocale;
  bool _isLoading = true;

  Locale get appLocale {
    // Retourne la locale chargée, ou la première locale supportée (par exemple 'fr') par défaut.
    return _appLocale ?? AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == 'fr', orElse: () => AppLocalizations.supportedLocales.first);
  }

  bool get isLoading => _isLoading;

  LanguageProvider() {
    loadLocale();
  }

  Future<void> loadLocale() async {
    _isLoading = true;
    notifyListeners(); // Notifie le début du chargement

    try {
      final prefs = await SharedPreferences.getInstance();
      String? languageCode = prefs.getString('languageCode');
      String? countryCode = prefs.getString('countryCode');

      if (languageCode != null) {
        _appLocale = Locale(languageCode, countryCode);
        _logger.i('Locale chargée: $_appLocale');
      } else {
        // Si aucune préférence n'est sauvegardée, utiliser la locale par défaut de l'appareil
        // ou une locale par défaut codée en dur (ex: français).
        // Ici, nous allons utiliser la première locale supportée comme fallback,
        // en privilégiant le français si disponible.
        _appLocale = AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == 'fr', orElse: () => AppLocalizations.supportedLocales.first);
        _logger.i('Aucune locale sauvegardée, utilisation de la locale par défaut: $_appLocale');
      }
    } catch (e) {
      _logger.e('Erreur lors du chargement de la locale: $e');
      // En cas d'erreur, fallback sur une locale par défaut
      _appLocale = AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == 'fr', orElse: () => AppLocalizations.supportedLocales.first);
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifie la fin du chargement et la mise à jour de la locale
    }
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString('languageCode', locale.languageCode);
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
        await prefs.setString('countryCode', locale.countryCode!);
      } else {
        await prefs.remove('countryCode');
      }
      _appLocale = locale;
      _logger.i('Locale définie et sauvegardée: $_appLocale');
      notifyListeners();
    } catch (e) {
      _logger.e('Erreur lors de la sauvegarde de la locale: $e');
    }
  }

  // Helper pour obtenir le nom de la langue de manière lisible
  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'it':
        return 'Italien';
      case 'pt':
        return (locale.countryCode == "BR") ? 'Portugais (Brésil)' : 'Portugais';

      // Ajoutez d'autres langues ici si nécessaire
      default:
        return locale.languageCode.toUpperCase();
    }
  }
}
