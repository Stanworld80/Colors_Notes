import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/providers/language_provider.dart'; // Importer LanguageProvider

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  /// Charge le contenu de la politique de confidentialité depuis le fichier d'asset approprié.
  ///
  /// Tente de charger le fichier correspondant à la langue actuelle.
  /// Si ce fichier n'existe pas, il se rabat sur la version anglaise ('en').
  Future<String> _loadPrivacyPolicyAsset(BuildContext context) async {
    // Récupère la locale actuelle depuis le LanguageProvider.
    final locale = Provider.of<LanguageProvider>(context, listen: false).appLocale;
    final languageCode = locale.languageCode;

    // Construit le chemin du fichier pour la langue actuelle.
    final localizedAssetPath = 'assets/privacy_policy_$languageCode.md';
    final defaultAssetPath = 'assets/privacy_policy_en.md';

    try {
      // Tente de charger le fichier de la langue spécifique.
      return await rootBundle.loadString(localizedAssetPath);
    } catch (e) {
      // Si le fichier spécifique à la langue n'est pas trouvé,
      // charge le fichier par défaut (anglais).
      return await rootBundle.loadString(defaultAssetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utilise le système de localisation pour le titre.
    final l10n = AppLocalizations.of(context)!;
    // Créez une nouvelle clé de localisation pour 'privacyPolicyTitle' dans vos fichiers .arb
    // Exemple: "privacyPolicyTitle": "Privacy Policy" dans intl_en.arb
    // Pour l'instant, on utilise une valeur codée en dur.
    final String pageTitle = l10n.privacyPolicy;

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
      ),
      body: FutureBuilder<String>(
        future: _loadPrivacyPolicyAsset(context),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Affichez un message d'erreur plus spécifique si possible.
            return Center(child: Text('Erreur de chargement du document.\n${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Contenu non disponible.'));
          }

          return Markdown(
            data: snapshot.data!,
            padding: const EdgeInsets.all(16.0),
            // Optionnel: ajoutez un style pour les liens si nécessaire
            onTapLink: (text, href, title) {
              // Vous pouvez gérer les clics sur les liens ici, par exemple avec url_launcher
            },
          );
        },
      ),
    );
  }
}
