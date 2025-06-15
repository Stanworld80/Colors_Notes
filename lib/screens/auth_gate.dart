import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'main_screen.dart';
import 'sign_in_page.dart';

/// **MODIFIÉ** : AuthGate est maintenant un StatefulWidget pour gérer son propre cycle de vie.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Utiliser addPostFrameCallback garantit que le code s'exécute après
    // la fin de la première passe de build, ce qui est l'endroit le plus sûr.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // On déclenche l'écoute des changements d'authentification ici.
        Provider.of<ActiveJournalNotifier>(context, listen: false).listenToAuthChanges();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Pendant que le stream d'authentification est en attente, on affiche un loader.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text(l10n.authErrorPrefix(snapshot.error.toString()))),
          );
        }

        if (snapshot.hasData) {
          return const MainScreen();
        } else {
          return const SignInPage();
        }
      },
    );
  }
}

