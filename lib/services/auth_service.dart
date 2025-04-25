import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(clientId: '603607348131-pm95a1rg19a856a5mg95c2v94s9gr48o.apps.googleusercontent.com');

  // Retourne l'utilisateur actuellement connecté
  User? get currentUser => _firebaseAuth.currentUser;

  // Vérifie si un utilisateur est connecté
  bool get isUserLoggedIn => _firebaseAuth.currentUser != null;

  // Connexion via Email et mot de passe
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in with email and password: $e");
      rethrow; // Propager l'erreur
    }
  }

  // Inscription via Email et mot de passe
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing up with email and password: $e");
      rethrow; // Propager l'erreur
    }
  }

  // Déconnexion de l'utilisateur
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut(); // Si l'utilisateur est connecté via Google
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }

  // Connexion via Google
  Future<User?> signInWithGoogle() async {
    try {
      // Commencer le processus de connexion Google
      GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // L'utilisateur a annulé la connexion
      }

      GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Créer un credential avec le token d'accès de Google
      OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Utiliser le credential pour se connecter à Firebase
      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("Error signing in with Google: $e");
      rethrow; // Propager l'erreur
    }
  }

  // Vérifie si un utilisateur est connecté via Google
  Future<bool> isGoogleUserLoggedIn() async {
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    return googleUser != null;
  }
}
