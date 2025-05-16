// test/providers/active_journal_provider_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// Importer vos classes et mocks générés
import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'active_journal_provider_test.mocks.dart'; // Fichier généré

// Générer les mocks pour les dépendances
@GenerateMocks([AuthService, FirestoreService, User, StreamController])
void main() {
  late ActiveJournalNotifier notifier;
  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late MockUser mockUser;
  late StreamController<User?> userStreamController;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();
    mockUser = MockUser();
    userStreamController = StreamController<User?>.broadcast();
    fakeFirestore = FakeFirebaseFirestore();

    when(mockUser.uid).thenReturn('user123');
    when(mockAuthService.userStream).thenAnswer((_) => userStreamController.stream);
    when(mockAuthService.currentUser).thenReturn(null);

    when(mockFirestoreService.getJournalStream(any)).thenAnswer((invocation) => fakeFirestore.collection('journals').doc(invocation.positionalArguments[0]).snapshots());

    notifier = ActiveJournalNotifier(mockAuthService, mockFirestoreService);
  });

  tearDown(() {
    userStreamController.close();
    clearInteractions(mockAuthService);
    clearInteractions(mockFirestoreService);
  });

  group('ActiveJournalNotifier Tests', () {
    final journal1 = Journal(
      id: 'journal1',
      userId: 'user123',
      name: 'Journal 1',
      createdAt: Timestamp.now(),
      lastUpdatedAt: Timestamp.now(),
      palette: Palette(id: 'p1', name: 'Palette 1', colors: [ColorData(paletteElementId: 'c1', title: 'Red', hexCode: 'FF0000')]),
    );
    final journal2 = Journal(
      id: 'journal2',
      userId: 'user123',
      name: 'Journal 2',
      createdAt: Timestamp.now(),
      lastUpdatedAt: Timestamp.now(),
      palette: Palette(id: 'p2', name: 'Palette 2', colors: [ColorData(paletteElementId: 'c2', title: 'Blue', hexCode: '0000FF')]),
    );

    test('Initial state is correct (no user)', () {
      expect(notifier.activeJournalId, isNull);
      expect(notifier.activeJournal, isNull);
      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
    });

    test('Loads first journal when user logs in', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      await fakeFirestore.collection('journals').doc(journal2.id).set(journal2.toMap());
      when(mockFirestoreService.getJournalsStream('user123')).thenAnswer((_) => Stream.value([journal1, journal2]));
      when(mockAuthService.currentUser).thenReturn(mockUser);
      userStreamController.add(mockUser);
      await Future.delayed(Duration(milliseconds: 10));

      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal1.id);
      expect(notifier.activeJournal?.name, journal1.name);
      expect(notifier.errorMessage, isNull);
      verify(mockFirestoreService.getJournalStream(journal1.id)).called(1);
    });

    test('Clears state when user logs out', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      when(mockFirestoreService.getJournalsStream('user123')).thenAnswer((_) => Stream.value([journal1]));
      when(mockAuthService.currentUser).thenReturn(mockUser);
      userStreamController.add(mockUser);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notifier.activeJournalId, journal1.id);

      when(mockAuthService.currentUser).thenReturn(null);
      userStreamController.add(null);
      await Future.delayed(Duration.zero);

      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, isNull);
      expect(notifier.activeJournal, isNull);
      expect(notifier.errorMessage, isNull);
    });

    test('setActiveJournal updates the active journal', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      await fakeFirestore.collection('journals').doc(journal2.id).set(journal2.toMap());
      when(mockFirestoreService.getJournalsStream('user123')).thenAnswer((_) => Stream.value([journal1, journal2]));
      when(mockAuthService.currentUser).thenReturn(mockUser);
      userStreamController.add(mockUser);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notifier.activeJournalId, journal1.id);

      await notifier.setActiveJournal(journal2.id, 'user123');
      await Future.delayed(Duration(milliseconds: 10));

      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal2.id);
      expect(notifier.activeJournal?.name, journal2.name);
      expect(notifier.errorMessage, isNull);
      verify(mockFirestoreService.getJournalStream(journal2.id)).called(1);
    });

    test('setActiveJournal handles non-existent journal', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      when(mockFirestoreService.getJournalsStream('user123')).thenAnswer((_) => Stream.value([journal1]));
      when(mockAuthService.currentUser).thenReturn(mockUser);
      userStreamController.add(mockUser);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notifier.activeJournalId, journal1.id);

      await notifier.setActiveJournal('nonExistentId', 'user123');
      await Future.delayed(Duration(milliseconds: 20));

      // Assert: Vérifier l'état FINAL après la tentative de rechargement
      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal1.id); // Doit revenir à journal1
      expect(notifier.activeJournal?.name, journal1.name);
      // *** CORRECTION: Le message d'erreur devrait être null dans l'état final stable ***
      expect(notifier.errorMessage, isNull);
      verify(mockFirestoreService.getJournalStream('nonExistentId')).called(1);
      verify(mockFirestoreService.getJournalsStream('user123')).called(2);
    });

    test('setActiveJournal handles journal not belonging to user', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      await fakeFirestore.collection('journals').doc('otherUserJournal').set({
        'userId': 'otherUser',
        'name': 'Autre Journal',
        'createdAt': Timestamp.now(),
        'lastUpdatedAt': Timestamp.now(),
        'palette': {'id': 'p3', 'name': 'Palette 3', 'colors': []},
      });
      when(mockFirestoreService.getJournalsStream('user123')).thenAnswer((_) => Stream.value([journal1]));
      when(mockAuthService.currentUser).thenReturn(mockUser);
      userStreamController.add(mockUser);
      await Future.delayed(Duration(milliseconds: 10));
      expect(notifier.activeJournalId, journal1.id);

      await notifier.setActiveJournal('otherUserJournal', 'user123');
      await Future.delayed(Duration(milliseconds: 20));

      // Assert: Vérifier l'état FINAL après la tentative de rechargement
      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal1.id); // Doit revenir à journal1
      expect(notifier.activeJournal?.name, journal1.name);
      // *** CORRECTION: Le message d'erreur devrait être null dans l'état final stable ***
      expect(notifier.errorMessage, isNull);
      verify(mockFirestoreService.getJournalStream('otherUserJournal')).called(1);
      verify(mockFirestoreService.getJournalsStream('user123')).called(2);
    });
  });
}
