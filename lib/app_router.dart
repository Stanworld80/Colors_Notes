// lib/app_router.dart
import 'package:flutter/material.dart';

import 'package:colors_notes/screens/auth_gate.dart';
import 'package:colors_notes/screens/help_page.dart';
import 'package:colors_notes/screens/main_screen.dart';
import 'package:colors_notes/screens/privacy_policy_page.dart';
import 'package:colors_notes/screens/register_page.dart';
import 'package:colors_notes/screens/settings_page.dart';
import 'package:colors_notes/screens/sign_in_page.dart';

/// Centralise la logique de routage pour l'application.
class AppRouter {
  // Une fonction statique pour générer les routes.
  // Elle est appelée par MaterialApp pour toute navigation nommée.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case '/':
        page = const AuthGate();
        break;
      case '/signin':
        page = const SignInPage();
        break;
      case '/register':
        page = const RegisterPage();
        break;
      case '/main':
        page = const MainScreen();
        break;
      case '/settings':
        page = const SettingsPage();
        break;
      case '/help':
        page = const HelpPage();
        break;
      case '/privacy':
        page = const PrivacyPolicyPage();
        break;
      default:
      // Si la route est inconnue, affiche une page d'erreur simple
      // ou redirige vers la page d'accueil.
        page = Scaffold(
          body: Center(
            child: Text('Page non trouvée: ${settings.name}'),
          ),
        );
        break;
    }

    return MaterialPageRoute(
      builder: (context) => page,
      settings: settings,
    );
  }
}
