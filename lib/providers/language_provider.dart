// lib/providers/language_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../l10n/app_localizations.dart';

final _logger = Logger();

class LanguageProvider with ChangeNotifier {
  Locale? _appLocale;
  bool _isLoading = true;
  bool _isInitialized = false; // Drapeau pour éviter les initialisations multiples

  Locale get appLocale {
    return _appLocale ?? AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == 'fr', orElse: () => AppLocalizations.supportedLocales.first);
  }

  bool get isLoading => _isLoading;

  // CONSTRUCTEUR MODIFIÉ : Ne fait plus rien, rendant le provider "passif".
  LanguageProvider();

  // La méthode loadLocale est maintenant appelée manuellement depuis l'interface.
  Future<void> loadLocale() async {
    // Si déjà initialisé, on ne fait rien.
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String? languageCode = prefs.getString('languageCode');
      String? countryCode = prefs.getString('countryCode');

      if (languageCode != null) {
        _appLocale = Locale(languageCode, countryCode);
        _logger.i('Locale chargée: $_appLocale');
      } else {
        _appLocale = AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == 'fr', orElse: () => AppLocalizations.supportedLocales.first);
        _logger.i('Aucune locale sauvegardée, utilisation de la locale par défaut: $_appLocale');
      }
    } catch (e) {
      _logger.e('Erreur lors du chargement de la locale: $e');
      _appLocale = AppLocalizations.supportedLocales.firstWhere((l) => l.languageCode == 'fr', orElse: () => AppLocalizations.supportedLocales.first);
    } finally {
      _isLoading = false;
      _isInitialized = true; // Marquer comme initialisé
      notifyListeners();
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

  String getLanguageName(Locale locale, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return locale.languageCode.toUpperCase();

    switch (locale.languageCode) {
      case 'fr': return l10n.languageFrench;
      case 'en': return l10n.languageEnglish;
      case 'es': return l10n.languageSpanish;
      case 'de': return l10n.languageGerman;
      case 'it': return l10n.languageItalian;
      case 'pt':
        return (locale.countryCode == "BR") ? l10n.languagePortugueseBrazil : l10n.languagePortuguese;
      default: return locale.languageCode.toUpperCase();
    }
  }
}
