import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Un widget dédié à l'affichage du bandeau de consentement aux cookies.
///
/// Ce widget est stateless et reçoit les actions à exécuter
/// via les callbacks `onAccept` et `onDecline`.
class CustomCookieBanner extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const CustomCookieBanner({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    // Récupère les traductions de manière sûre.
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      // Ne rien afficher si les traductions ne sont pas encore prêtes.
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 8,
        child: Container(
          color: const Color(0xFF37474F), // Equivalent de Colors.blueGrey[800]
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  // Utilisation des textes de secours au cas où une traduction manquerait.
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
