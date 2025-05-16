import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'firestore_service.dart'; // Required for initializing user data.

/// Logger instance for this service.
final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1, // Number of method calls to be displayed in the stack trace.
    errorMethodCount: 8, // Number of method calls if stacktrace is provided.
    lineLength: 120, // Width of the log print.
    colors: true, // Use colors for different log levels.
    printEmojis: true, // Print an emoji for each log message.
    printTime: true, // Should each log print contain a timestamp.
  ),
);

/// Provides authentication functionalities using Firebase Authentication.
///
/// This service handles user registration, sign-in (email/password and Google),
/// sign-out, and provides a stream for authentication state changes.
/// It also interacts with [FirestoreService] to initialize data for new users.
class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirestoreService _firestoreService; // Service to manage user data in Firestore.

  /// Creates an instance of [AuthService].
  ///
  /// Requires instances of [FirebaseAuth], [GoogleSignIn], and [FirestoreService].
  AuthService(this._firebaseAuth, this._googleSignIn, this._firestoreService);

  /// A stream that emits the current authenticated [User] or `null` if not authenticated.
  ///
  /// Listen to this stream to react to authentication state changes (sign-in, sign-out).
  Stream<User?> get userStream => _firebaseAuth.authStateChanges();

  /// Gets the currently authenticated [User].
  ///
  /// Returns the [User] object if a user is signed in, otherwise `null`.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs up a new user with the given email, password, and display name.
  ///
  /// If successful, it also updates the user's display name in Firebase Auth
  /// and initializes their data in Firestore via [FirestoreService].
  ///
  /// [email] The user's email address.
  /// [password] The user's chosen password.
  /// [displayName] The user's chosen display name.
  /// Returns the created [User] object if successful, otherwise `null`.
  /// Throws a custom error message string on failure, derived from [FirebaseAuthException].
  Future<User?> signUpWithEmailAndPassword(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        // Initialize user-specific data in Firestore.
        await _firestoreService.initializeNewUserData(user, displayName: displayName, email: email);
        _logger.i('Utilisateur inscrit et données initialisées: ${user.uid}'); // Log message in French
        return user;
      }
      _logger.w('Inscription: UserCredential.user est null après la création.'); // Log message in French
      return null;
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('FirebaseAuthException lors de l\'inscription', error: e, stackTrace: stackTrace); // Log message in French
      throw _handleAuthException(e); // Convert Firebase exception to a user-friendly message.
    } catch (e, stackTrace) {
      _logger.e('Erreur générique lors de l\'inscription', error: e, stackTrace: stackTrace); // Log message in French
      throw 'Une erreur inconnue est survenue lors de l\'inscription. Veuillez réessayer.'; // UI Text in French
    }
  }

  /// Signs in an existing user with their email and password.
  ///
  /// [email] The user's email address.
  /// [password] The user's password.
  /// Returns the signed-in [User] object if successful.
  /// Throws a custom error message string on failure, derived from [FirebaseAuthException].
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('Utilisateur connecté avec email: ${userCredential.user?.uid}'); // Log message in French
      return userCredential.user;
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('FirebaseAuthException lors de la connexion', error: e, stackTrace: stackTrace); // Log message in French
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Erreur générique lors de la connexion', error: e, stackTrace: stackTrace); // Log message in French
      throw 'Une erreur inconnue est survenue lors de la connexion. Veuillez réessayer.'; // UI Text in French
    }
  }

  /// Signs in a user using Google Sign-In.
  ///
  /// Initiates the Google Sign-In flow. If successful and the user is new,
  /// it initializes their data in Firestore via [FirestoreService].
  /// Returns the signed-in [User] object if successful, or `null` if the user cancels.
  /// Throws a custom error message string on failure.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the Google Sign-In flow.
        _logger.i('Connexion Google annulée par l\'utilisateur.'); // Log message in French
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
          _logger.i('Nouvel utilisateur Google détecté: ${user.uid}. Initialisation des données.'); // Log message in French
          // Initialize data for new Google user in Firestore.
          await _firestoreService.initializeNewUserData(user, displayName: user.displayName, email: user.email);
        } else {
          _logger.i('Utilisateur Google existant connecté: ${user.uid}'); // Log message in French
        }
        return user;
      }
      _logger.w('Connexion Google: UserCredential.user est null après la connexion.'); // Log message in French
      return null;
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('FirebaseAuthException lors de la connexion Google', error: e, stackTrace: stackTrace); // Log message in French
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Erreur générique lors de la connexion Google', error: e, stackTrace: stackTrace); // Log message in French
      throw 'Une erreur est survenue lors de la connexion avec Google. Veuillez réessayer.'; // UI Text in French
    }
  }

  /// Signs out the current user from Firebase and Google Sign-In (if applicable).
  ///
  /// Throws an error message string if sign-out fails.
  Future<void> signOut() async {
    try {
      // Sign out from Google if the user was signed in with Google.
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
        _logger.i('Google Sign-In déconnecté.'); // Log message in French
      }
      // Sign out from Firebase.
      await _firebaseAuth.signOut();
      _logger.i('Utilisateur Firebase déconnecté.'); // Log message in French
    } catch (e, stackTrace) {
      _logger.e('Erreur lors de la déconnexion', error: e, stackTrace: stackTrace); // Log message in French
      throw 'Une erreur est survenue lors de la déconnexion.'; // UI Text in French
    }
  }

  /// Handles [FirebaseAuthException] and converts them into user-friendly error messages.
  ///
  /// [e] The [FirebaseAuthException] to handle.
  /// Returns a string containing a user-friendly error message in French.
  String _handleAuthException(FirebaseAuthException e) {
    _logger.w("Auth Exception Code: ${e.code}, Message: ${e.message}");
    String message = "Une erreur d'authentification est survenue. (${e.code})"; // Default message in French
    // Switch on error codes to provide specific messages.
    // All messages are in French as per the original code.
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
      case 'INVALID_LOGIN_CREDENTIALS': // Common code for invalid email or password from Firebase
        message = 'Aucun utilisateur trouvé ou mot de passe incorrect.';
        break;
      case 'wrong-password': // This code might be redundant if INVALID_LOGIN_CREDENTIALS is used more often
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
      // Use Firebase's message if available and no specific case matches,
      // otherwise use the default initialized message.
        message = e.message ?? message;
    }
    return message;
  }
}
