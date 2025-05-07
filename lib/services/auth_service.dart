import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'firestore_service.dart';

final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1, errorMethodCount: 8, lineLength: 120,
    colors: true, printEmojis: true, printTime: true,
  ),
);

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirestoreService _firestoreService;

  AuthService(this._firebaseAuth, this._googleSignIn, this._firestoreService);

  Stream<User?> get userStream => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signUpWithEmailAndPassword(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await _firestoreService.initializeNewUserData(user, displayName: displayName, email: email);
        _logger.i('Utilisateur inscrit et données initialisées: ${user.uid}');
        return user;
      }
      _logger.w('Inscription: UserCredential.user est null après la création.');
      return null;
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('FirebaseAuthException lors de l\'inscription', error: e, stackTrace: stackTrace);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Erreur générique lors de l\'inscription', error: e, stackTrace: stackTrace);
      throw 'Une erreur inconnue est survenue lors de l\'inscription. Veuillez réessayer.';
    }
  }

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('Utilisateur connecté avec email: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('FirebaseAuthException lors de la connexion', error: e, stackTrace: stackTrace);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Erreur générique lors de la connexion', error: e, stackTrace: stackTrace);
      throw 'Une erreur inconnue est survenue lors de la connexion. Veuillez réessayer.';
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.i('Connexion Google annulée par l\'utilisateur.');
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          _logger.i('Nouvel utilisateur Google détecté: ${user.uid}. Initialisation des données.');
          await _firestoreService.initializeNewUserData(user, displayName: user.displayName, email: user.email);
        } else {
          _logger.i('Utilisateur Google existant connecté: ${user.uid}');
        }
        return user;
      }
      _logger.w('Connexion Google: UserCredential.user est null après la connexion.');
      return null;
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('FirebaseAuthException lors de la connexion Google', error: e, stackTrace: stackTrace);
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Erreur générique lors de la connexion Google', error: e, stackTrace: stackTrace);
      throw 'Une erreur est survenue lors de la connexion avec Google. Veuillez réessayer.';
    }
  }

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        _logger.i('Google Sign-In déconnecté.');
      }
      await _firebaseAuth.signOut();
      _logger.i('Utilisateur Firebase déconnecté.');
    } catch (e, stackTrace) {
      _logger.e('Erreur lors de la déconnexion', error: e, stackTrace: stackTrace);
      throw 'Une erreur est survenue lors de la déconnexion.';
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    _logger.w("Auth Exception Code: ${e.code}, Message: ${e.message}");
    String message = "Une erreur d'authentification est survenue. (${e.code})";
    switch (e.code) {
      case 'weak-password':
        message = 'Le mot de passe fourni est trop faible.';
        break;
      case 'email-already-in-use':
        message = 'Un compte existe déjà pour cette adresse e-mail.';
        break;
      case 'invalid-email':
        message = 'L\'adresse e-mail n\'est pas valide.';
        break;
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        message = 'Aucun utilisateur trouvé ou mot de passe incorrect.';
        break;
      case 'wrong-password':
        message = 'Mot de passe incorrect.';
        break;
      case 'user-disabled':
        message = 'Ce compte utilisateur a été désactivé.';
        break;
      case 'too-many-requests':
        message = 'Trop de tentatives. Veuillez réessayer plus tard.';
        break;
      case 'operation-not-allowed':
        message = 'L\'authentification par e-mail et mot de passe n\'est pas activée.';
        break;
      case 'network-request-failed':
        message = 'Erreur de réseau. Vérifiez votre connexion internet.';
        break;
      default:
        message = e.message ?? message;
    }
    return message;
  }
}
