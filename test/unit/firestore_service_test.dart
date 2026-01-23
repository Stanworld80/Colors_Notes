// test/unit/services/firestore_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:colors_notes/models/color_data.dart';
import 'package:colors_notes/models/palette_model.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/note.dart';
import 'package:uuid/uuid.dart';

import 'firestore_service_test.mocks.dart';

@GenerateMocks([fb_auth.User, Uuid])
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;
  late MockUser mockFbUser;

  ColorData createTestColorData(
      {String? id,
      required String title,
      required String hex,
      bool isDefault = false}) {
    return ColorData(
        paletteElementId: id ?? Uuid().v4(),
        title: title,
        hexCode: hex,
        isDefault: isDefault);
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    firestoreService = FirestoreService(fakeFirestore);
    mockFbUser = MockUser();

    when(mockFbUser.uid).thenReturn('defaultUserUid');
    when(mockFbUser.email).thenReturn('user@example.com');
    when(mockFbUser.displayName).thenReturn('Default User');
  });

  group('FirestoreService Tests', () {
    group('PaletteModel Management', () {
      final testUserId = 'paletteModelUser';
      final colorM1 =
          createTestColorData(title: 'ModelColor1', hex: '#ABCDEF', id: 'mc1');
      // Noms choisis pour tester le tri alphabétique
      final palettemodelB = PaletteModel(
          id: 'pmB',
          name: 'Modèle B - Beta',
          colors: [colorM1],
          userId: testUserId);
      final palettemodelA = PaletteModel(
          id: 'pmA',
          name: 'Modèle A - Alpha',
          colors: [colorM1],
          userId: testUserId);
      final palettemodelC = PaletteModel(
          id: 'pmC',
          name: 'Modèle C - Charlie',
          colors: [colorM1],
          userId: testUserId);

      // CORRECTION: Ajout du mot-clé 'async' car la fonction utilise 'await'.
      test(
          'getUserPaletteModelsStream devrait retourner les modèles de l\'utilisateur triés par nom',
          () async {
        // Ajouter dans un ordre non alphabétique pour vérifier le tri
        await firestoreService.createPaletteModel(palettemodelB);
        await firestoreService.createPaletteModel(palettemodelC);
        await firestoreService.createPaletteModel(palettemodelA);

        final stream = firestoreService.getUserPaletteModelsStream(testUserId);
        final models = await stream.first;

        expect(models.length, 3);
        // Vérifier l'ordre après le tri par nom attendu du service
        expect(
            models.map((m) => m.name).toList(),
            orderedEquals(
                ['Modèle A - Alpha', 'Modèle B - Beta', 'Modèle C - Charlie']));
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test(
          'getPredefinedPaletteModelsStream devrait retourner les modèles prédéfinis triés par nom',
          () async {
        final predefinedZ = PaletteModel(
            id: 'predefZ',
            name: 'Z Predefined',
            colors: [],
            isPredefined: true);
        final predefinedA = PaletteModel(
            id: 'predefA',
            name: 'A Predefined',
            colors: [],
            isPredefined: true);
        // Les modèles prédéfinis sont ajoutés directement à la fausse base de données pour le test.
        await fakeFirestore
            .collection('paletteModels')
            .doc(predefinedZ.id)
            .set(predefinedZ.toMap());
        await fakeFirestore
            .collection('paletteModels')
            .doc(predefinedA.id)
            .set(predefinedA.toMap());

        final stream = firestoreService.getPredefinedPaletteModelsStream();
        final models = await stream.first;

        expect(models.length, 2);
        expect(models.map((m) => m.name).toList(),
            orderedEquals(['A Predefined', 'Z Predefined']));
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('createPaletteModel devrait ajouter un modèle de palette', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        final doc = await fakeFirestore
            .collection('paletteModels')
            .doc(palettemodelA.id)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], palettemodelA.name);
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('updatePaletteModel devrait mettre à jour un modèle', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        final updatedName = 'Modèle A - Alpha Modifié';
        final updatedModel = palettemodelA.copyWith(name: updatedName);

        await firestoreService.updatePaletteModel(updatedModel);
        final doc = await fakeFirestore
            .collection('paletteModels')
            .doc(palettemodelA.id)
            .get();
        expect(doc.data()?['name'], updatedName);
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('deletePaletteModel devrait supprimer un modèle', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        await firestoreService.deletePaletteModel(palettemodelA.id);
        final doc = await fakeFirestore
            .collection('paletteModels')
            .doc(palettemodelA.id)
            .get();
        expect(doc.exists, isFalse);
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('checkPaletteModelNameExists devrait fonctionner correctement',
          () async {
        await firestoreService.createPaletteModel(palettemodelA);
        expect(
            await firestoreService.checkPaletteModelNameExists(
                palettemodelA.name, testUserId),
            isTrue);
        expect(
            await firestoreService.checkPaletteModelNameExists(
                palettemodelA.name, testUserId,
                excludeId: palettemodelA.id),
            isFalse);
        expect(
            await firestoreService.checkPaletteModelNameExists(
                'Nouveau Nom Inexistant', testUserId),
            isFalse);
      });
    });

    group('initializeNewUserData', () {
      // CORRECTION: Test réactivé et marqué comme 'async'.
      test(
          'devrait créer un journal par défaut avec des paletteElementId uniques pour les couleurs',
          () async {
        when(mockFbUser.uid).thenReturn('newUserWithPaletteCheck');
        when(mockFbUser.email).thenReturn('newpalette@example.com');
        when(mockFbUser.displayName).thenReturn('New Palette User');

        await firestoreService.initializeNewUserData(mockFbUser,
            displayName: 'New Palette User', email: 'newpalette@example.com');

        final journalQuery = await fakeFirestore
            .collection('journals')
            .where('userId', isEqualTo: 'newUserWithPaletteCheck')
            .limit(1)
            .get();
        expect(journalQuery.docs.isNotEmpty, isTrue);
        final journalData = journalQuery.docs.first.data();
        final paletteData = journalData['palette'] as Map<String, dynamic>;
        final colorsList = paletteData['colors'] as List<dynamic>;

        expect(colorsList.isNotEmpty, isTrue);
        final Set<String> paletteElementIds = {};
        for (var colorMap in colorsList) {
          final color = ColorData.fromMap(colorMap as Map<String, dynamic>);
          expect(color.paletteElementId, isNotEmpty);
          expect(paletteElementIds.contains(color.paletteElementId), isFalse,
              reason: "Les IDs des éléments de palette doivent être uniques.");
          paletteElementIds.add(color.paletteElementId);
        }
      });
    });

    group('Journal Management', () {
      final testUserId = 'journalUser';
      final palette = Palette(
          id: 'p1',
          name: 'P1',
          colors: [createTestColorData(title: 'C1', hex: 'FFFFF')],
          userId: testUserId);
      final journal = Journal(
          id: 'j1',
          userId: testUserId,
          name: 'Test Journal',
          palette: palette,
          createdAt: Timestamp.now(),
          lastUpdatedAt: Timestamp.now());

      test('createJournal should create a journal document', () async {
        await firestoreService.createJournal(journal);
        final doc =
            await fakeFirestore.collection('journals').doc(journal.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], journal.name);
      });

      test('checkJournalNameExists should return true if name exists',
          () async {
        await firestoreService.createJournal(journal);
        expect(
            await firestoreService.checkJournalNameExists(
                'Test Journal', testUserId),
            isTrue);
        expect(
            await firestoreService.checkJournalNameExists(
                'Other Name', testUserId),
            isFalse);
      });

      test('deleteJournal should delete journal and its notes', () async {
        await firestoreService.createJournal(journal);
        // Create a note in this journal
        final note = Note(
            id: 'n1',
            journalId: journal.id,
            userId: testUserId,
            content: 'Test Note',
            paletteElementId: 'c1',
            eventTimestamp: Timestamp.now(),
            createdAt: Timestamp.now(),
            lastUpdatedAt: Timestamp.now());
        await firestoreService.createNote(note);

        await firestoreService.deleteJournal(journal.id, testUserId);

        final journalDoc =
            await fakeFirestore.collection('journals').doc(journal.id).get();
        expect(journalDoc.exists, isFalse);

        final noteDoc =
            await fakeFirestore.collection('notes').doc(note.id).get();
        expect(noteDoc.exists, isFalse);
      });
    });

    group('Note Management', () {
      final testUserId = 'noteUser';
      final journalId = 'j_note_test';
      final note = Note(
          id: 'n1',
          journalId: journalId,
          userId: testUserId,
          content: 'My Note',
          paletteElementId: 'blue',
          eventTimestamp: Timestamp.now(),
          createdAt: Timestamp.now(),
          lastUpdatedAt: Timestamp.now());

      test('createNote should create a note document', () async {
        await firestoreService.createNote(note);
        final doc = await fakeFirestore.collection('notes').doc(note.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['content'], 'My Note');
      });

      test('updateNote should update content and lastUpdatedAt', () async {
        await firestoreService.createNote(note);
        final oldTime = note.lastUpdatedAt;
        await Future.delayed(Duration(milliseconds: 100)); // Ensure time diff

        final updatedNote = note.copyWith(content: 'New Content');
        await firestoreService.updateNote(updatedNote);

        final doc = await fakeFirestore.collection('notes').doc(note.id).get();
        expect(doc.data()?['content'], 'New Content');
        // Check timestamp updated
        final storedTimestamp = doc.data()?['lastUpdatedAt'] as Timestamp;
        expect(storedTimestamp.compareTo(oldTime) > 0, isTrue);
      });

      test('deleteNote should remove the document', () async {
        await firestoreService.createNote(note);
        await firestoreService.deleteNote(note.id);
        final doc = await fakeFirestore.collection('notes').doc(note.id).get();
        expect(doc.exists, isFalse);
      });
    });
  });
}
