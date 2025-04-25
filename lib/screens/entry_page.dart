import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soa_starter/screens/auth_gate.dart';
import 'logged_homepage.dart';

class EntryPage extends StatelessWidget {
  const EntryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Utilisez un StreamBuilder pour écouter les changements d'état d'authentification
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Snapshot contient l'état actuel de l'utilisateur
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Afficher un indicateur de chargement pendant la vérification initiale
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // L'utilisateur est connecté
          print("User is logged in: ${snapshot.data!.uid}"); // Debug
          return const LoggedHomepage();
        } else {
          // L'utilisateur n'est PAS connecté
          print("User is not logged in"); // Debug
          return const AuthGate(); // Rediriger vers la page d'authentification (qui peut contenir les boutons signin/register)
        }
      },
    );
  }
}