// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:colors_notes/l10n/app_localizations.dart'; // Pour les chaînes localisées
import '../providers/language_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context)!; // Pour accéder aux chaînes localisées

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings), // "Paramètres"
      ),
      body: languageProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(
            title: Text(l10n.language), // "Langue"
            subtitle: Text(languageProvider.getLanguageName(languageProvider.appLocale)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showLanguageSelectionDialog(context, languageProvider);
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.theme), // "Thème"
            subtitle: Text(l10n.comingSoon), // "Bientôt disponible"
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.themeSettingsComingSoon)), // "Les paramètres de thème arrivent bientôt !"
              );
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.notifications), // "Notifications"
            subtitle: Text(l10n.comingSoon), // "Bientôt disponible"
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.notificationSettingsComingSoon)), // "Les paramètres de notification arrivent bientôt !"
              );
            },
          ),
          // Ajoutez d'autres paramètres ici
        ],
      ),
    );
  }

  void _showLanguageSelectionDialog(BuildContext context, LanguageProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.selectLanguage), // "Sélectionnez une langue"
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AppLocalizations.supportedLocales.length,
              itemBuilder: (BuildContext context, int index) {
                final locale = AppLocalizations.supportedLocales[index];
                final bool isSelected = locale == provider.appLocale;
                return RadioListTile<Locale>(
                  title: Text(provider.getLanguageName(locale)),
                  value: locale,
                  groupValue: provider.appLocale,
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      provider.setLocale(newLocale);
                      Navigator.of(dialogContext).pop(); // Ferme le dialogue
                    }
                  },
                  selected: isSelected,
                  activeColor: Theme.of(context).primaryColor,
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel), // Bouton Annuler localisé
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
