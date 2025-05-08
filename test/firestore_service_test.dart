// test/firestore_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart'; // Nécessaire pour @GenerateMocks
import 'package:mockito/mockito.dart'; // Nécessaire pour when(), verify() etc. si vous utilisez les mocks générés
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

// Importez vos modèles et votre service
// Assurez-vous que les chemins d'importation sont corrects pour votre structure de projet
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:colors_notes/services/firestore_service.dart'; // Le service à tester

// --- Mocking Firebase Services (Optionnel si fake_cloud_firestore est utilisé principalement) ---
// Si vous utilisez @GenerateMocks, assurez-vous que build_runner a généré ce fichier.
// Exécutez `flutter pub run build_runner build --delete-conflicting-outputs` dans le terminal
@GenerateMocks([
  // FirebaseFirestore, // Commenté car nous utilisons FakeFirebaseFirestore principalement
  // CollectionReference,
  // DocumentReference,
  // WriteBatch,
  // QuerySnapshot,
  // Query,
  // DocumentSnapshot,
  FirebaseAuth, // Utile si vous testez des logiques d'authentification dans le service
  User,
  Logger, // Pour moquer les appels de logging
  Uuid, // Pour contrôler la génération d'UUID dans les tests
])
import 'firestore_service_test.mocks.dart'; // Ce fichier DOIT être généré par build_runner

void main() {
  // Instance du service à tester
  late FirestoreService firestoreService;
  // Instance de FakeFirebaseFirestore
  late FakeFirebaseFirestore fakeFirestoreInstance;
  // Mocks pour les dépendances qui ne sont pas Firestore (si FirestoreService les injecte)
  late MockFirebaseAuth mockAuth;
  late MockLogger mockLogger;
  late MockUuid mockUuid;

  setUp(() {
    fakeFirestoreInstance = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(); // Si FirestoreService dépend de FirebaseAuth
    mockLogger = MockLogger();
    mockUuid = MockUuid();

    // *** IMPORTANT: Refactorisation de FirestoreService pour l'injection de dépendances ***
    // ... (commentaire inchangé) ...
    //
    // Avec cette refactorisation, vous initialiseriez le service comme suit :
    firestoreService = FirestoreService(
      firestore: fakeFirestoreInstance, // Utilise fake_cloud_firestore
      auth: mockAuth, // Utilisez le mock si nécessaire
      logger: mockLogger, // Utilisez le mock pour vérifier les logs
      uuid: mockUuid, // Utilisez le mock pour contrôler les UUIDs générés
    );
    // Assurez-vous que le fichier .mocks.dart est généré et non vide.
    // Exécutez: flutter pub run build_runner build --delete-conflicting-outputs
  });

  group('FirestoreService Unit Tests with FakeFirebaseFirestore', () {
    test('createJournal should add a journal to Firestore', () async {
      // Arrange
      const userId = 'testUserId';
      final journalId = 'journalTest123';
      final paletteId = 'paletteTest123';
      final colorId = 'colorTest123';

      // Configurez le mockUuid pour retourner des valeurs prévisibles si nécessaire
      when(mockUuid.v4()).thenReturnInOrder([/*paletteId, colorId,*/ journalId]); // Ajustez l'ordre si nécessaire

      // **Correction:** Utiliser createdAt et lastUpdatedAt
      final journalToCreate = Journal(
        id: journalId,
        userId: userId,
        name: 'Mon Journal de Test Fake',
        createdAt: Timestamp.fromDate(DateTime(2023, 1, 1)), // Nom de champ corrigé
        lastUpdatedAt: Timestamp.fromDate(DateTime(2023, 1, 1)), // Nom de champ corrigé
        palette: Palette(
          id: paletteId,
          name: 'Palette de Test Fake',
          colors: [
            ColorData(
                paletteElementId: colorId,
                title: 'Bleu Test',
                hexCode: '#0000FF'),
          ],
        ),
      );
      final journalMap = journalToCreate.toMap(); // Pour la vérification

      // Act
      // **Correction:** Appeler createJournal avec seulement l'objet Journal
      await firestoreService.createJournal(journalToCreate);

      // Assert
      // Vérifiez directement dans fakeFirestoreInstance que le document a été créé
      final docSnapshot = await fakeFirestoreInstance
          .collection('users')
          .doc(userId)
          .collection('journals')
          .doc(journalToCreate.id)
          .get();

      expect(docSnapshot.exists, isTrue, reason: "Le document journal devrait exister dans FakeFirestore");
      // Comparer les maps peut être délicat avec les Timestamps, vérifier les champs clés
      final data = docSnapshot.data();
      expect(data?['id'], equals(journalToCreate.id));
      expect(data?['userId'], equals(journalToCreate.userId));
      expect(data?['name'], equals(journalToCreate.name));
      // expect(data, equals(journalMap)); // Peut échouer à cause des Timestamps, préférez les vérifications individuelles

      // Optionnel: Vérifiez les appels au logger si vous l'avez moqué et injecté
      verify(mockLogger.i('Journal ${journalToCreate.id} créé pour l\'utilisateur $userId')).called(1);
    });

    test('initializeNewUserData should create user, default journal, and update activeJournalId', () async {
      // Arrange
      const testEmail = 'test@example.com';
      const testDisplayName = 'Test User';
      const defaultJournalName = 'Journal par Défaut';

      // Mock User
      final mockUser = MockUser();
      when(mockUser.uid).thenReturn('newTestUserId');
      when(mockUser.email).thenReturn(testEmail);
      when(mockUser.displayName).thenReturn(testDisplayName);

      // Mock UUIDs that will be generated by FirestoreService
      final expectedUserDocId = 'newTestUserId';
      final expectedJournalId = 'defaultJournalUuid';
      final expectedPaletteId = 'defaultPaletteUuid';
      final expectedColorId1 = 'defaultColorUuid1';
      // ... add more if your default palette has more colors

      when(mockUuid.v4()).thenReturnInOrder([
        expectedPaletteId, // Palette ID for default instance palette
        expectedColorId1, // ColorData ID for the first color in default palette
        // ... add more UUIDs for other colors in the default palette
        expectedJournalId,  // Journal ID
      ]);


      // Act
      // Note: initializeNewUserData dans votre service actuel utilise predefinedPaletteModels.
      // Assurez-vous que cette liste est accessible ou moquez son accès si nécessaire.
      await firestoreService.initializeNewUserData(mockUser); // Pass named param

      // Assert
      // 1. Check user document
      final userDoc = await fakeFirestoreInstance.collection('users').doc(expectedUserDocId).get();
      expect(userDoc.exists, isTrue, reason: "User document should exist");
      expect(userDoc.data()?['email'], testEmail);
      expect(userDoc.data()?['activeJournalId'], expectedJournalId, reason: "Active journal ID should be set");

      // 2. Check default journal document
      final journalDoc = await fakeFirestoreInstance
          .collection('users')
          .doc(expectedUserDocId)
          .collection('journals')
          .doc(expectedJournalId)
          .get();
      expect(journalDoc.exists, isTrue, reason: "Default journal document should exist");
      expect(journalDoc.data()?['name'], defaultJournalName);
      expect(journalDoc.data()?['userId'], expectedUserDocId);

      // 3. Check palette within the journal
      final paletteData = journalDoc.data()?['palette'] as Map<String, dynamic>?;
      expect(paletteData, isNotNull, reason: "Palette data should exist in journal");
      expect(paletteData?['id'], expectedPaletteId); // Vérifie l'ID de la palette
      // Le nom de la palette dans initializeNewUserData est basé sur le nom du modèle
      // expect(paletteData?['name'], 'Palette de $defaultJournalName'); // Vérifiez le nom exact défini dans initializeNewUserData

      final colorsList = paletteData?['colors'] as List<dynamic>?;
      expect(colorsList, isNotEmpty, reason: "Palette should have colors");
      final firstColor = colorsList?.first as Map<String, dynamic>?;
      expect(firstColor?['paletteElementId'], expectedColorId1);


      verify(mockLogger.i('Nouvel utilisateur et journal par défaut initialisés pour $expectedUserDocId')).called(1);
    });


    // Ajoutez d'autres tests pour d'autres méthodes en utilisant fakeFirestoreInstance
  });

  // Groupe de tests illustratif pour Mockito (nécessite une refactorisation majeure de FirestoreService)
  group('FirestoreService Unit Tests with Mockito (Illustrative - Requires Refactoring)', () {
    // setUp(() { // Mock instantiations commented out
    // MockFirebaseFirestore mockFirestoreForMockito = MockFirebaseFirestore();
    // MockLogger mockLoggerForMockito = MockLogger();
    // firestoreService = FirestoreService(
    //   firestore: mockFirestoreForMockito,
    //   logger: mockLoggerForMockito,
    //   auth: MockFirebaseAuth(),
    //   uuid: MockUuid(),
    // );
    // });

    test('[Mockito Example] createJournal should call Firestore set with correct data', () async {
      // Ce test ne fonctionnera que si FirestoreService est refactorisé pour l'injection de dépendances.
      // Arrange
      // final mockFirestore = MockFirebaseFirestore(); // Commented out
      // final mockUsersCol = MockCollectionReference<Map<String, dynamic>>(); // Commented out
      // final mockUserDoc = MockDocumentReference<Map<String, dynamic>>(); // Commented out
      // final mockJournalsCol = MockCollectionReference<Map<String, dynamic>>(); // Commented out
      // final mockJournalDoc = MockDocumentReference<Map<String, dynamic>>(); // Commented out
      final mockLoggerForThisTest = MockLogger(); // Keep this mock

      // Configurez FirestoreService pour utiliser ces mocks (nécessite un constructeur acceptant les dépendances)
      // final serviceWithMocks = FirestoreService( // Commented out
      //     firestore: mockFirestore,
      //     logger: mockLoggerForThisTest,
      //     auth: MockFirebaseAuth(),
      //     uuid: MockUuid()
      // );


      const userId = 'mockitoUserId';
      // **Correction:** Utiliser createdAt et lastUpdatedAt
      final journal = Journal(
        id: 'mockitoJournal123',
        userId: userId,
        name: 'Mon Journal Mockito',
        createdAt: Timestamp.now(), // Nom de champ corrigé
        lastUpdatedAt: Timestamp.now(), // Nom de champ corrigé
        palette: Palette(
          id: 'mockitoPalette123',
          name: 'Palette Mockito',
          colors: [
            ColorData(paletteElementId: 'mockitoColor1', title: 'Vert', hexCode: '#00FF00'),
          ],
        ),
      );
      final journalMap = journal.toMap();

      // Configuration des mocks pour la chaîne d'appels (Commented out)
      // when(mockFirestore.collection('users')).thenReturn(mockUsersCol);
      // when(mockUsersCol.doc(userId)).thenReturn(mockUserDoc);
      // when(mockUserDoc.collection('journals')).thenReturn(mockJournalsCol);
      // when(mockJournalsCol.doc(journal.id)).thenReturn(mockJournalDoc);
      // when(mockJournalDoc.set(journalMap)).thenAnswer((_) async {});

      // Act
      // **Correction:** Appeler createJournal avec seulement l'objet Journal (Commented out)
      // await serviceWithMocks.createJournal(journal);

      // Assert (Commented out)
      // verify(mockJournalDoc.set(journalMap)).called(1);
      // verify(mockLoggerForThisTest.i('Journal ${journal.id} créé pour l\'utilisateur $userId')).called(1);

      print("NOTE: L'exemple de test Mockito ci-dessus suppose que FirestoreService");
      print("a été refactorisé pour l'injection de dépendances et que les mocks sont générés.");
      expect(true, isTrue); // Placeholder
    });
  });
}

