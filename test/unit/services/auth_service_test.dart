// test/unit/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'auth_service_test.mocks.dart';

// Génération des mocks
@GenerateMocks([FirebaseAuth, GoogleSignIn, GoogleSignInAccount, GoogleSignInAuthentication, User, UserCredential, FirestoreService, AdditionalUserInfo])
void main() {
  // Déclarations des mocks et de l'instance du service
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFirestoreService mockFirestoreService;
  late MockGoogleSignInAccount mockGoogleSignInAccount;
  late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;
  late MockAdditionalUserInfo mockAdditionalUserInfo;

  // Configuration initiale avant chaque test
  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockFirestoreService = MockFirestoreService();
    mockGoogleSignInAccount = MockGoogleSignInAccount();
    mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();
    mockAdditionalUserInfo = MockAdditionalUserInfo();

    // Instanciation du service avec les mocks
    authService = AuthService(mockFirebaseAuth, mockGoogleSignIn, mockFirestoreService);

    // Comportement par défaut des mocks
    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('testUid123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUserCredential.additionalUserInfo).thenReturn(mockAdditionalUserInfo);
    when(mockAdditionalUserInfo.isNewUser).thenReturn(false); // Par défaut, l'utilisateur n'est pas nouveau

    // Comportement par défaut pour les méthodes asynchrones
    when(mockFirestoreService.initializeNewUserData(any, displayName: anyNamed('displayName'), email: anyNamed('email'))).thenAnswer((_) async {});
    when(mockUser.updateDisplayName(any)).thenAnswer((_) async {});
    when(mockGoogleSignIn.isSignedIn()).thenAnswer((_) async => false);
    when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
    when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});
  });

  group('AuthService Tests', () {
    test('signInWithEmailAndPassword - Succès', () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password'))).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signInWithEmailAndPassword('test@example.com', 'password123');

      expect(user, isNotNull);
      expect(user?.uid, 'testUid123');
      verify(mockFirebaseAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password123')).called(1);
    });

    test('signInWithEmailAndPassword - Échec (mauvais mot de passe)', () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      expect(
              () async => await authService.signInWithEmailAndPassword('test@example.com', 'wrongpass'),
          throwsA(predicate((e) => e is String && e.contains('Mot de passe incorrect'))));
      verify(mockFirebaseAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'wrongpass')).called(1);
    });

    test('signUpWithEmailAndPassword - Succès (nouvel utilisateur)', () async {
      when(mockFirebaseAuth.createUserWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password'))).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signUpWithEmailAndPassword('new@example.com', 'password123', 'New User');

      expect(user, isNotNull);
      expect(user?.uid, 'testUid123');
      verify(mockFirebaseAuth.createUserWithEmailAndPassword(email: 'new@example.com', password: 'password123')).called(1);
      verify(mockUser.updateDisplayName('New User')).called(1);
      verify(mockFirestoreService.initializeNewUserData(any, displayName: 'New User', email: 'new@example.com')).called(1);
    });

    test('signInWithGoogle - Succès (nouvel utilisateur)', () async {
      // Configuration pour un nouvel utilisateur
      when(mockAdditionalUserInfo.isNewUser).thenReturn(true);
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuthentication);
      when(mockGoogleSignInAuthentication.accessToken).thenReturn('fakeAccessToken');
      when(mockGoogleSignInAuthentication.idToken).thenReturn('fakeIdToken');
      when(mockFirebaseAuth.signInWithCredential(any)).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signInWithGoogle();

      expect(user, isNotNull);
      verify(mockGoogleSignIn.signIn()).called(1);
      verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
      // Doit initialiser les données pour un nouvel utilisateur
      verify(mockFirestoreService.initializeNewUserData(any, displayName: anyNamed('displayName'), email: anyNamed('email'))).called(1);
    });

    test('signInWithGoogle - Succès (utilisateur existant)', () async {
      // isNewUser est 'false' par défaut dans le setUp
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuthentication);
      when(mockGoogleSignInAuthentication.accessToken).thenReturn('fakeAccessToken');
      when(mockGoogleSignInAuthentication.idToken).thenReturn('fakeIdToken');
      when(mockFirebaseAuth.signInWithCredential(any)).thenAnswer((_) async => mockUserCredential);

      final user = await authService.signInWithGoogle();

      expect(user, isNotNull);
      verify(mockGoogleSignIn.signIn()).called(1);
      verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
      // Ne doit PAS initialiser les données pour un utilisateur existant
      verifyNever(mockFirestoreService.initializeNewUserData(any, displayName: anyNamed('displayName'), email: anyNamed('email')));
    });

    test('signInWithGoogle - Annulation par l\'utilisateur', () async {
      // Simule l'annulation par l'utilisateur (signIn retourne null)
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final user = await authService.signInWithGoogle();

      expect(user, isNull);
      verify(mockGoogleSignIn.signIn()).called(1);
      // Les autres services ne doivent pas être appelés
      verifyNever(mockFirebaseAuth.signInWithCredential(any));
      verifyNever(mockFirestoreService.initializeNewUserData(any, displayName: anyNamed('displayName'), email: anyNamed('email')));
    });

    test('signOut - Succès (avec Google Sign-In)', () async {
      when(mockGoogleSignIn.isSignedIn()).thenAnswer((_) async => true);

      await authService.signOut();

      verify(mockGoogleSignIn.isSignedIn()).called(1);
      verify(mockGoogleSignIn.signOut()).called(1);
      verify(mockFirebaseAuth.signOut()).called(1);
    });

    test('signOut - Succès (sans Google Sign-In)', () async {
      // isSignedIn est false par défaut dans le setUp
      await authService.signOut();

      verify(mockGoogleSignIn.isSignedIn()).called(1);
      // Ne doit pas appeler signOut de Google si l'utilisateur n'est pas connecté via Google
      verifyNever(mockGoogleSignIn.signOut());
      verify(mockFirebaseAuth.signOut()).called(1);
    });
  });
}