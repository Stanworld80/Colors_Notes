// test/mocks.dart

import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/annotations.dart';

// Ce fichier centralise la génération de tous les mocks de l'application.
// C'est le "plan" que build_runner va lire.
// Exécutez `flutter pub run build_runner build --delete-conflicting-outputs`
// pour générer le fichier compagnon `mocks.mocks.dart`.
@GenerateMocks([
  // Services
  AuthService,
  FirestoreService,

  // Firebase & Google
  FirebaseAuth,
  GoogleSignIn,
  User,
  UserCredential,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  AdditionalUserInfo,
])
void main() {
  // Le contenu de ce fichier n'a pas d'importance,
  // seules les annotations comptent pour build_runner.
}
