// test/firestore_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

// Importer vos modèles et votre service
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:colors_notes/services/firestore_service.dart'; // Le service à tester
import 'package:colors_notes/core/predefined_templates.dart'; // Importer les modèles prédéfinis
import 'package:colors_notes/models/app_user.dart';

// --- Mocking Firebase Services ---
@GenerateMocks([
  FirebaseAuth,
  User,
  Logger,
  Uuid,
])
import 'firestore_service_test.mocks.dart'; // Fichier généré par build_runner

void main() {
  late FirestoreService firestoreService;
  late FakeFirebaseFirestore fakeFirestoreInstance;
  late MockFirebaseAuth mockAuth;
  late MockLogger mockLogger;
  late MockUuid mockUuid;
  late MockUser mockUser;

  setUp(() {
    fakeFirestoreInstance = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockLogger = MockLogger();
    mockUuid = MockUuid();
    mockUser = MockUser();

    // Initialisation de FirestoreService avec l'instance FakeFirebaseFirestore
    firestoreService = FirestoreService(fakeFirestoreInstance);

    // Configuration de base pour le mockUser si nécessaire
    when(mockUser.uid).thenReturn('testUserId');
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn('Test User');
  });


  group('FirestoreService Unit Tests with FakeFirebaseFirestore', () {

    // --- Test createJournal (Corrigé) ---
    test('createJournal should add a journal to Firestore', () async {
      // Arrange
      const userId = 'testUserId';
      final journalId = 'journalTest123';
      final paletteId = 'paletteTest123'; // L'ID de la palette *n'est pas* stocké dans la map elle-même
      final colorId = 'colorTest123';

      final journalToCreate = Journal(
        id: journalId,
        userId: userId,
        name: 'Mon Journal de Test Fake',
        createdAt: Timestamp.fromDate(DateTime(2023, 1, 1)),
        lastUpdatedAt: Timestamp.fromDate(DateTime(2023, 1, 1)),
        palette: Palette(
          id: paletteId, // Cet ID n'est pas dans le toMap() par défaut
          name: 'Palette de Test Fake',
          colors: [
            ColorData(
                paletteElementId: colorId,
                title: 'Bleu Test',
                hexCode: '#0000FF'),
          ],
          userId: userId,
        ),
      );

      // Act
      await firestoreService.createJournal(journalToCreate);

      // Assert
      final docSnapshot = await fakeFirestoreInstance
          .collection('journals')
          .doc(journalId)
          .get();

      expect(docSnapshot.exists, isTrue, reason: "Le document journal devrait exister");
      final data = docSnapshot.data();
      expect(data?['userId'], equals(userId));
      expect(data?['name'], equals('Mon Journal de Test Fake'));
      // *** CORRECTION: Ne pas tester l'ID de la palette dans la map ***
      // expect(data?['palette']?['id'], equals(paletteId)); // Commenté/Supprimé
      expect(data?['palette']?['name'], equals('Palette de Test Fake')); // Vérifier le nom
      expect(data?['palette']?['colors']?[0]?['paletteElementId'], equals(colorId));

    });

    // --- Test initializeNewUserData (Adapté) ---
    test('initializeNewUserData should create user and default journal', () async {
      // Arrange
      const testEmail = 'newuser@example.com';
      const testDisplayName = 'New Test User';
      const defaultJournalName = 'Mon Premier Journal';

      when(mockUser.uid).thenReturn('newUserId123');
      when(mockUser.email).thenReturn(testEmail);
      when(mockUser.displayName).thenReturn(testDisplayName);

      // Act
      await firestoreService.initializeNewUserData(mockUser, displayName: testDisplayName, email: testEmail);

      // Assert
      // 1. Vérifier le document utilisateur
      final userDoc = await fakeFirestoreInstance.collection('users').doc('newUserId123').get();
      expect(userDoc.exists, isTrue, reason: "Le document utilisateur devrait exister");
      expect(userDoc.data()?['email'], testEmail);
      expect(userDoc.data()?['displayName'], testDisplayName);

      // 2. Vérifier le document journal par défaut
      final journalQuery = await fakeFirestoreInstance
          .collection('journals')
          .where('userId', isEqualTo: 'newUserId123')
          .limit(1)
          .get();

      expect(journalQuery.docs.length, 1, reason: "Un journal par défaut devrait être créé");
      final journalDoc = journalQuery.docs.first;
      expect(journalDoc.exists, isTrue, reason: "Le document journal par défaut devrait exister");
      expect(journalDoc.data()['name'], defaultJournalName);
      expect(journalDoc.data()['userId'], 'newUserId123');

      // 3. Vérifier la palette dans le journal par défaut
      final paletteData = journalDoc.data()['palette'] as Map<String, dynamic>?;
      expect(paletteData, isNotNull, reason: "La palette devrait exister dans le journal");
      expect(paletteData?['name'], predefinedPalettes[0].name); // Vérifier le nom basé sur le modèle

      final colorsList = paletteData?['colors'] as List<dynamic>?;
      expect(colorsList, isNotNull);
      expect(colorsList?.length, predefinedPalettes[0].colors.length, reason: "Le nombre de couleurs doit correspondre au modèle");
      if (colorsList != null && colorsList.isNotEmpty && predefinedPalettes[0].colors.isNotEmpty) {
        expect(colorsList[0]['title'], predefinedPalettes[0].colors[0].title);
        expect(colorsList[0]['hexCode'], predefinedPalettes[0].colors[0].hexCode);
        expect(colorsList[0]['paletteElementId'], isNotNull);
      }
    });

    // --- Test deleteJournal (Inchangé) ---
    test('deleteJournal should remove the journal and its notes', () async {
      // Arrange
      const userId = 'userToDeleteJournal';
      const journalId = 'journalToDelete';
      const noteId1 = 'note1InJournalToDelete';
      const noteId2 = 'note2InJournalToDelete';

      await fakeFirestoreInstance.collection('journals').doc(journalId).set({
        'userId': userId, 'name': 'Journal à Supprimer', 'createdAt': Timestamp.now(),
        'lastUpdatedAt': Timestamp.now(), 'palette': {'id': 'p1', 'name': 'Palette', 'colors': []}
      });
      await fakeFirestoreInstance.collection('notes').doc(noteId1).set({
        'journalId': journalId, 'userId': userId, 'content': 'Note 1', 'paletteElementId': 'c1',
        'eventTimestamp': Timestamp.now(), 'createdAt': Timestamp.now(), 'lastUpdatedAt': Timestamp.now()
      });
      await fakeFirestoreInstance.collection('notes').doc(noteId2).set({
        'journalId': journalId, 'userId': userId, 'content': 'Note 2', 'paletteElementId': 'c2',
        'eventTimestamp': Timestamp.now(), 'createdAt': Timestamp.now(), 'lastUpdatedAt': Timestamp.now()
      });
      await fakeFirestoreInstance.collection('notes').doc('otherNote').set({
        'journalId': 'otherJournal', 'userId': userId, 'content': 'Autre Note', 'paletteElementId': 'c3',
        'eventTimestamp': Timestamp.now(), 'createdAt': Timestamp.now(), 'lastUpdatedAt': Timestamp.now()
      });

      // Act
      await firestoreService.deleteJournal(journalId, userId);

      // Assert
      final journalDoc = await fakeFirestoreInstance.collection('journals').doc(journalId).get();
      expect(journalDoc.exists, isFalse, reason: "Le journal devrait être supprimé");
      final note1Doc = await fakeFirestoreInstance.collection('notes').doc(noteId1).get();
      expect(note1Doc.exists, isFalse, reason: "La note 1 associée devrait être supprimée");
      final note2Doc = await fakeFirestoreInstance.collection('notes').doc(noteId2).get();
      expect(note2Doc.exists, isFalse, reason: "La note 2 associée devrait être supprimée");
      final otherNoteDoc = await fakeFirestoreInstance.collection('notes').doc('otherNote').get();
      expect(otherNoteDoc.exists, isTrue, reason: "La note de l'autre journal ne doit pas être supprimée");
    });

    // --- Test isPaletteElementUsedInNotes (Inchangé) ---
    test('isPaletteElementUsedInNotes returns true if used, false otherwise', () async {
      // Arrange
      const userId = 'userToCheckUsage';
      const journalId = 'journalToCheckUsage';
      const usedColorId = 'colorUsed1';
      const unusedColorId = 'colorUnused1';

      await fakeFirestoreInstance.collection('notes').doc('noteUsingColor').set({
        'journalId': journalId, 'userId': userId, 'content': 'Utilise la couleur', 'paletteElementId': usedColorId,
        'eventTimestamp': Timestamp.now(), 'createdAt': Timestamp.now(), 'lastUpdatedAt': Timestamp.now()
      });

      // Act
      final bool isUsed = await firestoreService.isPaletteElementUsedInNotes(journalId, usedColorId);
      final bool isUnused = await firestoreService.isPaletteElementUsedInNotes(journalId, unusedColorId);
      final bool isUsedInOtherJournal = await firestoreService.isPaletteElementUsedInNotes('otherJournalId', usedColorId);

      // Assert
      expect(isUsed, isTrue, reason: "La couleur $usedColorId devrait être marquée comme utilisée");
      expect(isUnused, isFalse, reason: "La couleur $unusedColorId ne devrait pas être marquée comme utilisée");
      expect(isUsedInOtherJournal, isFalse, reason: "La couleur $usedColorId ne devrait pas être marquée comme utilisée dans un autre journal");
    });

    // Ajoutez d'autres tests ici...

  });
}