// lib/services/auth_service.dart
import 'package:colors_notes/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart'; // Importer FirestoreService
import '../models/journal.dart'; // Importer les modèles nécessaires
import '../models/palette.dart';
import '../models/color_data.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(clientId: "523869870608-c167do1sb6lfrhcg8tsgughi6gcckcdi.apps.googleusercontent.com");

  // Ajouter une instance de FirestoreService
  final FirestoreService _firestoreService = FirestoreService();

  // Ajouter ce getter :
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ... (currentUser, isUserLoggedIn restent inchangés)

  // --- Modification de l'inscription Email/Password ---
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;

      if (user != null) {
        print(">>> AUTH SUCCEEDED for ${user.uid}. Attempting Firestore writes..."); // DEBUG

        // --- Bloc try-catch pour l'écriture Firestore ---
        try {
          print(">>> Calling createUserDocument..."); // DEBUG
          await _firestoreService.createUserDocument(user);
          print(">>> DONE createUserDocument."); // DEBUG

          print(">>> Calling _createDefaultJournalForUser..."); // DEBUG
          await _createDefaultJournalForUser(user.uid);
          print(">>> DONE _createDefaultJournalForUser."); // DEBUG

          print("Firestore user document and default journal potentially created for new user ${user.uid}");
        } catch (e) {
          // Attraper et afficher les erreurs spécifiques à Firestore
          print(">>> !!! ERROR during Firestore document creation: $e"); // DEBUG
          // Optionnel: vous pourriez vouloir propager cette erreur
          // ou la logger plus formellement.
        }
        // ------------------------------------------------
      } else {
        print(">>> AUTH SUCCEEDED but user object is null."); // DEBUG (ne devrait pas arriver)
      }
      return user; // Retourne l'utilisateur même si Firestore a échoué pour l'instant
    } on FirebaseAuthException catch (e) {
      print(">>> !!! FirebaseAuthException during signUp: ${e.code} - ${e.message}"); // DEBUG
      rethrow;
    } catch (e) {
      print(">>> !!! UNEXPECTED ERROR during signUp: $e"); // DEBUG - Autre erreur ?
      rethrow;
    }
  }

  // --- Modification de la connexion Google ---
  Future<User?> signInWithGoogle() async {
    try {
      // ... (processus Google Sign In jusqu'à obtenir le credential)
      GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // L'utilisateur a annulé
      }
      GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      OAuthCredential credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);

      // Utiliser le credential pour se connecter ou s'inscrire à Firebase
      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // <<< NOUVEAU: Vérifier si c'est la première connexion/inscription via Google >>>
        // On vérifie si le document Firestore existe DEJA
        AppUser? existingAppUser = await _firestoreService.getAppUser(user.uid);

        if (existingAppUser == null) {
          // Si le document n'existe pas, c'est une "nouvelle" inscription Firestore
          print("First time Firestore setup for Google user ${user.uid}");
          await _firestoreService.createUserDocument(user);
          await _createDefaultJournalForUser(user.uid);
          print("Firestore user document and default journal created for Google user ${user.uid}");
        } else {
          print("Google user ${user.uid} already exists in Firestore.");
          // Optionnel : vérifier si l'journal par défaut existe, au cas où le processus
          // aurait échoué la première fois (moins prioritaire pour le MVP)
        }
      }
      return user;
    } catch (e) {
      print("Error signing in with Google: $e");
      rethrow;
    }
  }

  // --- Connexion Email/Password (Pas besoin de créer l'journal ici) ---
  Future<User?> signInWithEmailPassword(String email, String password) async {
    // Pas de changement ici, on ne crée le document/journal qu'à l'inscription
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error signing in with email and password: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Se déconnecter de Firebase Auth
      await _firebaseAuth.signOut();
      // Tenter aussi de se déconnecter de Google Sign In au cas où
      await _googleSignIn.signOut();
    } catch (e) {
      print("Error signing out: $e");
      // Optionnel: ne pas relancer l'erreur pour ne pas bloquer l'UI
      // rethrow;
    }
  }

  // --- Méthode privée pour créer l'journal par défaut ---
  Future<void> _createDefaultJournalForUser(String userId) async {
    print(">>> ENTERED _createDefaultJournalForUser for $userId"); // DEBUG
    try {
      // 1. Définir la palette par défaut
      Palette defaultPalette = Palette(
        name: "Palette par défaut", // Ou un nom plus générique
        colors: [
          ColorData(title: "Important", hexValue: "#FF0000"), // Rouge
          ColorData(title: "Travail", hexValue: "#0000FF"), // Bleu
          ColorData(title: "Personnel", hexValue: "#00FF00"), // Vert
          ColorData(title: "Idée", hexValue: "#FFFF00"), // Jaune
        ],
      );

      // 2. Créer l'objet Journal
      // Note: L'ID de l'journal sera généré par Firestore lors de l'appel à .add()
      // Nous créons un objet "modèle" sans ID ici.
      // Ajustez la classe Journal et FirestoreService.createJournal si nécessaire.
      // Supposons que createJournal prend un objet Journal sans ID et le userId séparément
      Journal defaultJournal = Journal(
        id: '', // Laissé vide, Firestore générera l'ID
        name: "Journal par défaut",
        userId: userId,
        embeddedPaletteInstance: defaultPalette,
      );

      // 3. Appeler FirestoreService pour créer l'journal
      // Assurez-vous que votre méthode createJournal dans FirestoreService
      // gère bien l'ajout et retourne l'ID si besoin.
      print(">>> Attempting to add default journal to Firestore for $userId"); // DEBUG
      await _firestoreService.createJournal(userId, defaultJournal);
      print(">>> Default journal potentially added to Firestore for $userId"); // DEBUG
    } catch (e) {
      print("Error creating default journal for user $userId: $e");
      print(">>> !!! ERROR in _createDefaultJournalForUser for $userId: $e"); // DEBUG
      // Gérer l'erreur (peut-être logger ou afficher un message)
    }
  }

  // ... (signOut, isGoogleUserLoggedIn restent inchangés)
}
