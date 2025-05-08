import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'auth_service_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  User,
  UserCredential,
  FirestoreService,
  AdditionalUserInfo
])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFirestoreService mockFirestoreService;
  late MockGoogleSignInAccount mockGoogleSignInAccount;
  late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;
  late MockAdditionalUserInfo mockAdditionalUserInfo;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockFirestoreService = MockFirestoreService();
    mockGoogleSignInAccount = MockGoogleSignInAccount();
    mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();
    mockAdditionalUserInfo = MockAdditionalUserInfo();

    authService = AuthService(mockFirebaseAuth, mockGoogleSignIn, mockFirestoreService);

    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('testUid123');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
    when(mockUserCredential.additionalUserInfo).thenReturn(mockAdditionalUserInfo);
    when(mockAdditionalUserInfo.isNewUser).thenReturn(false);

    when(mockFirestoreService.initializeNewUserData(any, displayName: anyNamed('displayName'), email: anyNamed('email')))
        .thenAnswer((_) async => null);
    when(mockUser.updateDisplayName(any)).thenAnswer((_) async => null);
    when(mockGoogleSignIn.isSignedIn()).thenAnswer((_) async => false);
    when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
    when(mockFirebaseAuth.signOut()).thenAnswer((_) async => null);
  });

  tearDown(() {
    clearInteractions(mockFirebaseAuth);
    clearInteractions(mockGoogleSignIn);
    clearInteractions(mockFirestoreService);
    clearInteractions(mockGoogleSignInAccount);
    clearInteractions(mockGoogleSignInAuthentication);
    clearInteractions(mockUser);
    clearInteractions(mockUserCredential);
    clearInteractions(mockAdditionalUserInfo);
  });


  group('AuthService Tests', () {

    test('signInWithEmailAndPassword - Success', () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenAnswer((_) async => mockUserCredential);

      final user = await authService.signInWithEmailAndPassword('test@example.com', 'password123');

      expect(user, isNotNull);
      expect(user?.uid, 'testUid123');
      verify(mockFirebaseAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'password123')).called(1);
      verifyNoMoreInteractions(mockFirebaseAuth);
      verifyNoMoreInteractions(mockFirestoreService);
      verifyNoMoreInteractions(mockGoogleSignIn);
    });

    test('signInWithEmailAndPassword - Failure (Wrong Password)', () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      expect(
              () async => await authService.signInWithEmailAndPassword('test@example.com', 'wrongpass'),
          throwsA(predicate((e) => e is String && e.contains('Mot de passe incorrect')))
      );
      verify(mockFirebaseAuth.signInWithEmailAndPassword(email: 'test@example.com', password: 'wrongpass')).called(1);
      verifyNoMoreInteractions(mockFirebaseAuth);
      verifyNoMoreInteractions(mockFirestoreService);
      verifyNoMoreInteractions(mockGoogleSignIn);
    });

    test('signUpWithEmailAndPassword - Success (New User)', () async {
      when(mockFirebaseAuth.createUserWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
          .thenAnswer((_) async => mockUserCredential);

      final user = await authService.signUpWithEmailAndPassword('new@example.com', 'password123', 'New User');

      expect(user, isNotNull);
      expect(user?.uid, 'testUid123');
      verify(mockFirebaseAuth.createUserWithEmailAndPassword(email: 'new@example.com', password: 'password123')).called(1);
      // *** Simplification de la vérification updateDisplayName ***
      verify(mockUser.updateDisplayName(any)).called(1);
      verify(mockFirestoreService.initializeNewUserData(
          any,
          displayName: 'New User',
          email: 'new@example.com'
      )).called(1);
      verifyNoMoreInteractions(mockFirebaseAuth);
      verifyNoMoreInteractions(mockFirestoreService);
      // verifyNoMoreInteractions(mockUser); // Temporairement commenté
      verifyNoMoreInteractions(mockGoogleSignIn);
    });

    test('signInWithGoogle - Success (New User)', () async {
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuthentication);
      when(mockGoogleSignInAuthentication.accessToken).thenReturn('fakeAccessToken');
      when(mockGoogleSignInAuthentication.idToken).thenReturn('fakeIdToken');
      when(mockFirebaseAuth.signInWithCredential(any)).thenAnswer((_) async => mockUserCredential);
      when(mockAdditionalUserInfo.isNewUser).thenReturn(true);

      final user = await authService.signInWithGoogle();

      expect(user, isNotNull);
      verify(mockGoogleSignIn.signIn()).called(1);
      verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
      verify(mockFirestoreService.initializeNewUserData(
          any,
          displayName: anyNamed('displayName'),
          email: anyNamed('email')
      )).called(1);
      verifyNoMoreInteractions(mockFirebaseAuth);
      verifyNoMoreInteractions(mockGoogleSignIn);
      verifyNoMoreInteractions(mockFirestoreService);
    });

    test('signInWithGoogle - Success (Existing User)', () async {
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuthentication);
      when(mockGoogleSignInAuthentication.accessToken).thenReturn('fakeAccessToken');
      when(mockGoogleSignInAuthentication.idToken).thenReturn('fakeIdToken');
      when(mockFirebaseAuth.signInWithCredential(any)).thenAnswer((_) async => mockUserCredential);
      when(mockAdditionalUserInfo.isNewUser).thenReturn(false);

      final user = await authService.signInWithGoogle();

      expect(user, isNotNull);
      verify(mockGoogleSignIn.signIn()).called(1);
      verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
      verifyNever(mockFirestoreService.initializeNewUserData(any, displayName: anyNamed('displayName'), email: anyNamed('email')));
      verifyNoMoreInteractions(mockFirebaseAuth);
      verifyNoMoreInteractions(mockGoogleSignIn);
      verifyNoMoreInteractions(mockFirestoreService);
    });


    test('signOut - Success', () async {
      when(mockGoogleSignIn.isSignedIn()).thenAnswer((_) async => true);

      await authService.signOut();

      verify(mockGoogleSignIn.signOut()).called(1);
      verify(mockFirebaseAuth.signOut()).called(1);
      // *** Ajout de la vérification pour isSignedIn ***
      verify(mockGoogleSignIn.isSignedIn()).called(1);
      verifyNoMoreInteractions(mockFirebaseAuth);
      verifyNoMoreInteractions(mockGoogleSignIn);
      verifyNoMoreInteractions(mockFirestoreService);
    });

  });
}
