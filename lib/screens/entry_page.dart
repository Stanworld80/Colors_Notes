// lib/screens/entry_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'auth_gate.dart';
// import 'logged_homepage.dart'; // Plus la destination directe
import 'main_screen.dart'; // Importer le nouvel écran principal

class EntryPage extends StatelessWidget {
  const EntryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();
    print("EntryPage build: firebaseUser is ${firebaseUser?.uid ?? 'null'}");

    if (firebaseUser != null) {
      // NAVIGUER VERS MainScreen MAINTENANT
      return const MainScreen();
    } else {
      return const AuthGate();
    }
  }
}