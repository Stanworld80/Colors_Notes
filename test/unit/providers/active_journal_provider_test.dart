// test/unit/providers/active_journal_provider_test.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:colors_notes/services/auth_service.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';



// Import du fichier de mocks centralisé
import '../../mocks.mocks.dart' hide MockUser;


void main() {
  // Déclaration des mocks
  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late ActiveJournalNotifier notifier;

  // Contrôleur de stream pour simuler les changements d'utilisateur
  late StreamController<User?> userStreamController;

  // Utilisation de MockUser de firebase_auth_mocks
  final mockUser = MockUser(
    isAnonymous: false,
    uid: 'user123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();
    userStreamController = StreamController<User?>.broadcast();

    // Comportement par défaut des mocks
    when(mockAuthService.userStream).thenAnswer((_) => userStreamController.stream);
    when(mockAuthService.currentUser).thenReturn(null); // Par défaut, non connecté

    // Instanciation du notifier
    notifier = ActiveJournalNotifier(mockAuthService, mockFirestoreService);
  });

  tearDown(() {
    userStreamController.close();
    notifier.dispose();
  });

  test('devrait être initialement inactif et sans journal', () {
    expect(notifier.activeJournal, isNull);
    expect(notifier.isLoading, isFalse);
  });

  test('devrait charger le premier journal quand un utilisateur se connecte', () async {
    // 1. Préparation des données simulées
    final now = DateTime.now();
    // CORRECTION : Firestore utilise des Timestamps, pas des DateTimes.
    final timestamp = Timestamp.fromDate(now);

    final journals = [
      Journal(
        id: 'journal1',
        name: 'Mon journal',
        userId: 'user123',
        palette: Palette(name: 'Défaut', colors: []),
        createdAt: timestamp,       // CORRECTION : Utilisation du Timestamp
        lastUpdatedAt: timestamp,   // CORRECTION : Utilisation du Timestamp
      )
    ];

    // Simuler le retour du flux de la liste des journaux
    when(mockFirestoreService.getJournalsStream('user123'))
        .thenAnswer((_) => Stream.value(journals));

    // Simuler le retour du document pour le journal spécifique
    final fakeFirestore = FakeFirebaseFirestore();
    final journalData = journals.first.toMap(); // Utiliser toMap pour la cohérence
    await fakeFirestore.collection('journals').doc('journal1').set(journalData);

    when(mockFirestoreService.getJournalStream('journal1'))
        .thenAnswer((_) => fakeFirestore.collection('journals').doc('journal1').snapshots());

    // 2. Lancement de l'écoute des changements d'authentification
    notifier.listenToAuthChanges();

    // 3. Simulation de la connexion de l'utilisateur
    userStreamController.add(mockUser);

    // 4. Attendre que toutes les opérations asynchrones soient terminées
    await Future.delayed(Duration.zero);

    // 5. Vérification du résultat final
    expect(notifier.activeJournal, isNotNull);
    expect(notifier.activeJournal?.id, 'journal1');
    expect(notifier.isLoading, isFalse);
  });
}
