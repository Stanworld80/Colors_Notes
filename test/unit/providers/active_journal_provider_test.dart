// test/providers/active_journal_provider_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'active_journal_provider_test.mocks.dart';

@GenerateMocks([AuthService, FirestoreService, User])
void main() {
  late ActiveJournalNotifier notifier;
  late MockAuthService mockAuthService;
  late FirestoreService firestoreService; // Utilisation du vrai service avec FakeFirestore
  late MockUser mockUser;
  late StreamController<User?> userStreamController;
  late FakeFirebaseFirestore fakeFirestore;

  // Création de données de test réutilisables
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

  setUp(() async {
    mockAuthService = MockAuthService();
    mockUser = MockUser();
    userStreamController = StreamController<User?>.broadcast();
    fakeFirestore = FakeFirebaseFirestore();
    firestoreService = FirestoreService(fakeFirestore); // Utilise le vrai service

    when(mockUser.uid).thenReturn('user123');
    when(mockAuthService.userStream).thenAnswer((_) => userStreamController.stream);
    when(mockAuthService.currentUser).thenReturn(null);

    // Initialisation du notifier
    notifier = ActiveJournalNotifier(mockAuthService, firestoreService);
  });

  tearDown(() {
    userStreamController.close();
    notifier.dispose();
  });

  group('ActiveJournalNotifier Tests', () {

    test('L\'état initial est correct (pas d\'utilisateur)', () {
      expect(notifier.activeJournalId, isNull);
      expect(notifier.activeJournal, isNull);
      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
    });

    test('Charge le premier journal quand l\'utilisateur se connecte', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      await fakeFirestore.collection('journals').doc(journal2.id).set(journal2.toMap());

      when(mockAuthService.currentUser).thenReturn(mockUser);

      notifier.listenToAuthChanges(); // Démarre l'écoute
      userStreamController.add(mockUser); // Simule la connexion

      // Attendre que toutes les opérations asynchrones soient terminées
      await Future.delayed(Duration.zero);

      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal1.id);
      expect(notifier.activeJournal?.name, journal1.name);
      expect(notifier.errorMessage, isNull);
    });

    test('L\'état est effacé quand l\'utilisateur se déconnecte', () async {
      // Connexion initiale
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      when(mockAuthService.currentUser).thenReturn(mockUser);
      notifier.listenToAuthChanges();
      userStreamController.add(mockUser);
      await Future.delayed(Duration.zero);
      expect(notifier.activeJournalId, journal1.id);

      // Déconnexion
      when(mockAuthService.currentUser).thenReturn(null);
      userStreamController.add(null);
      await Future.delayed(Duration.zero);

      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, isNull);
      expect(notifier.activeJournal, isNull);
      expect(notifier.errorMessage, isNull);
    });

    test('setActiveJournal met à jour le journal actif', () async {
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      await fakeFirestore.collection('journals').doc(journal2.id).set(journal2.toMap());
      when(mockAuthService.currentUser).thenReturn(mockUser);
      notifier.listenToAuthChanges();
      userStreamController.add(mockUser);
      await Future.delayed(Duration.zero); // Attendre chargement initial
      expect(notifier.activeJournalId, journal1.id);

      // Changer de journal
      await notifier.setActiveJournal(journal2.id, 'user123');
      await Future.delayed(Duration.zero);

      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal2.id);
      expect(notifier.activeJournal?.name, journal2.name);
      expect(notifier.errorMessage, isNull);
    });

    test('setActiveJournal gère un journal inexistant et revient à un état valide', () async {
      // Configuration initiale avec un journal valide
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      when(mockAuthService.currentUser).thenReturn(mockUser);
      notifier.listenToAuthChanges();
      userStreamController.add(mockUser);
      await Future.delayed(Duration.zero); // Attendre le chargement
      expect(notifier.activeJournalId, journal1.id);

      // Tenter de charger un journal qui n'existe pas
      await notifier.setActiveJournal('nonExistentId', 'user123');
      await Future.delayed(Duration.zero);

      // CORRECTION DU TEST : Le comportement attendu est que le notifier
      // essaie de charger le journal, échoue, puis recharge un journal initial valide.
      // L'état final ne doit donc PAS contenir d'erreur.
      expect(notifier.isLoading, isFalse, reason: "Le chargement doit être terminé.");
      expect(notifier.activeJournalId, journal1.id, reason: "Doit revenir au premier journal valide.");
      expect(notifier.activeJournal?.name, journal1.name);
      expect(notifier.errorMessage, isNull, reason: "Le message d'erreur doit être effacé après avoir rechargé un état valide.");
    });

    test('setActiveJournal gère un journal n\'appartenant pas à l\'utilisateur et revient à un état valide', () async {
      final otherUserJournal = Journal(
          id: 'otherUserJournal', userId: 'otherUser456', name: 'Journal Secret',
          createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now(),
          palette: Palette(id: 'p3', name: 'P3', colors: [])
      );
      await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
      await fakeFirestore.collection('journals').doc(otherUserJournal.id).set(otherUserJournal.toMap());

      when(mockAuthService.currentUser).thenReturn(mockUser);
      notifier.listenToAuthChanges();
      userStreamController.add(mockUser);
      await Future.delayed(Duration.zero);
      expect(notifier.activeJournalId, journal1.id);

      // Tenter de charger un journal d'un autre utilisateur
      await notifier.setActiveJournal('otherUserJournal', 'user123');
      await Future.delayed(Duration.zero);

      // CORRECTION DU TEST : Comme pour le cas du journal inexistant, le notifier
      // doit se "réparer" en chargeant un journal valide.
      expect(notifier.isLoading, isFalse);
      expect(notifier.activeJournalId, journal1.id);
      expect(notifier.activeJournal?.name, journal1.name);
      expect(notifier.errorMessage, isNull);
    });

  });
}