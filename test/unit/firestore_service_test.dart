// test/unit/services/firestore_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Alias pour éviter conflit
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/models/app_user.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:colors_notes/models/note.dart';
import 'package:colors_notes/models/palette_model.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/core/predefined_templates.dart';
import 'package:uuid/uuid.dart';

import 'firestore_service_test.mocks.dart';

@GenerateMocks([fb_auth.User, Uuid])
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;
  late MockUser mockFbUser;

  ColorData createTestColorData({String? id, required String title, required String hex, bool isDefault = false}) {
    return ColorData(paletteElementId: id ?? Uuid().v4(), title: title, hexCode: hex, isDefault: isDefault);
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
    group('User Management', () {
      test('getUser devrait retourner AppUser si l\'utilisateur existe', () async {
        final userData = AppUser(id: 'user1', email: 'user1@example.com', displayName: 'User One', registrationDate: Timestamp.now());
        await fakeFirestore.collection('users').doc('user1').set(userData.toMap());

        final result = await firestoreService.getUser('user1');
        expect(result, isA<AppUser>());
        expect(result?.email, 'user1@example.com');
      });

      test('getUser devrait retourner null si l\'utilisateur n\'existe pas', () async {
        final result = await firestoreService.getUser('nonExistentUser');
        expect(result, isNull);
      });
    });

    group('Journal Management', () {
      final testUserId = 'journalUser';
      final color1 = createTestColorData(title: 'Red', hex: '#FF0000', id: 'c1');
      final color2 = createTestColorData(title: 'Blue', hex: '#0000FF', id: 'c2');
      final testPalette = Palette(id: 'palette1', name: 'Test Palette', colors: [color1, color2], userId: testUserId);
      final journal1 = Journal(id: 'journal1', userId: testUserId, name: 'My First Journal', palette: testPalette, createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now());
      final journal2 = Journal(id: 'journal2', userId: testUserId, name: 'My Second Journal', palette: testPalette, createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now());


      test('createJournal devrait ajouter un journal', () async {
        await firestoreService.createJournal(journal1);
        final doc = await fakeFirestore.collection('journals').doc(journal1.id).get();
        expect(doc.exists, isTrue);
        final data = doc.data(); // Pas besoin de caster ici si on vérifie juste l'existence et le nom
        expect(data?['name'], journal1.name);
        final paletteData = data?['palette'] as Map<String, dynamic>?;
        expect(paletteData?['id'], journal1.palette.id);
      });

      test('getJournalsStream devrait retourner les journaux de l\'utilisateur', () async {
        await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
        await fakeFirestore.collection('journals').doc(journal2.id).set(journal2.toMap());
        await fakeFirestore.collection('journals').doc('otherUserJournal').set(
            Journal(id: 'otherUserJournal', userId: 'otherUser', name: 'Other', palette: testPalette, createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now()).toMap()
        );

        final stream = firestoreService.getJournalsStream(testUserId);
        final journals = await stream.first;

        expect(journals.length, 2);
        expect(journals.any((j) => j.id == journal1.id), isTrue);
        expect(journals.any((j) => j.id == journal2.id), isTrue);
      });

      test('getJournalStream devrait retourner un journal spécifique', () async {
        await fakeFirestore.collection('journals').doc(journal1.id).set(journal1.toMap());
        final stream = firestoreService.getJournalStream(journal1.id);
        final snapshot = await stream.first;
        expect(snapshot.exists, isTrue);
        // CORRECTION: Caster snapshot.data() en Map<String, dynamic>?
        final data = snapshot.data() as Map<String, dynamic>?;
        expect(data?['name'], journal1.name);
      });

      test('checkJournalNameExists devrait fonctionner correctement', () async {
        await firestoreService.createJournal(journal1);
        expect(await firestoreService.checkJournalNameExists(journal1.name, testUserId), isTrue);
        expect(await firestoreService.checkJournalNameExists('Non Existent Journal', testUserId), isFalse);
      });

      test('updateJournalName devrait mettre à jour le nom du journal et lastUpdatedAt', () async {
        await firestoreService.createJournal(journal1);
        final initialTimestamp = journal1.lastUpdatedAt;
        await Future.delayed(const Duration(milliseconds: 10));

        await firestoreService.updateJournalName(journal1.id, 'Nouveau Nom Journal');
        final updatedDocSnap = await fakeFirestore.collection('journals').doc(journal1.id).get();
        final updatedDoc = updatedDocSnap.data() as Map<String, dynamic>?;
        expect(updatedDoc?['name'], 'Nouveau Nom Journal');
        expect((updatedDoc?['lastUpdatedAt'] as Timestamp).microsecondsSinceEpoch, greaterThan(initialTimestamp.microsecondsSinceEpoch));
      });

      test('updateJournalPaletteInstance devrait mettre à jour la palette du journal et lastUpdatedAt', () async {
        await firestoreService.createJournal(journal1);
        final initialTimestamp = journal1.lastUpdatedAt;
        await Future.delayed(const Duration(milliseconds: 10));

        final newColor = createTestColorData(title: 'Green', hex: '#00FF00', id: 'c3');
        final updatedPalette = journal1.palette.copyWith(colors: [...journal1.palette.colors, newColor], name: "Palette Mise à Jour");

        await firestoreService.updateJournalPaletteInstance(journal1.id, updatedPalette);
        final updatedDocSnap = await fakeFirestore.collection('journals').doc(journal1.id).get();
        final updatedDoc = updatedDocSnap.data() as Map<String, dynamic>?;
        final paletteData = updatedDoc?['palette'] as Map<String, dynamic>?;
        expect(paletteData?['name'], "Palette Mise à Jour");
        expect(paletteData?['colors'].length, 3);
        expect(paletteData?['id'], updatedPalette.id);
        expect((updatedDoc?['lastUpdatedAt'] as Timestamp).microsecondsSinceEpoch, greaterThan(initialTimestamp.microsecondsSinceEpoch));
      });
    });

    group('Note Management', () {
      final testUserId = 'noteUser';
      final testJournalId = 'journalForNotes';
      final colorForNote = createTestColorData(id: 'colorForNote1', title: 'TestColor', hex: '#123456');
      final note1 = Note(id: 'note1', journalId: testJournalId, userId: testUserId, content: 'Contenu Note 1', paletteElementId: colorForNote.paletteElementId, eventTimestamp: Timestamp.now(), createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now());
      final note2 = Note(id: 'note2', journalId: testJournalId, userId: testUserId, content: 'Contenu Note 2 Alpha', paletteElementId: colorForNote.paletteElementId, eventTimestamp: Timestamp.fromMillisecondsSinceEpoch(Timestamp.now().millisecondsSinceEpoch + 1000), createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now());

      setUp(() async {
        final journalForNotes = Journal(
            id: testJournalId,
            userId: testUserId,
            name: "Journal des Notes",
            palette: Palette(id: 'pNote', name: 'Palette Notes', colors: [colorForNote], userId: testUserId),
            createdAt: Timestamp.now(),
            lastUpdatedAt: Timestamp.now()
        );
        await fakeFirestore.collection('journals').doc(testJournalId).set(journalForNotes.toMap());
      });

      test('createNote devrait ajouter une note', () async {
        await firestoreService.createNote(note1);
        final doc = await fakeFirestore.collection('notes').doc(note1.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['content'], note1.content);
      });

      test('getJournalNotesStream devrait retourner les notes du journal triées par eventTimestamp descendant par défaut', () async {
        await firestoreService.createNote(note1);
        await Future.delayed(const Duration(milliseconds: 5));
        await firestoreService.createNote(note2);

        final stream = firestoreService.getJournalNotesStream(testJournalId);
        final notes = await stream.first;

        expect(notes.length, 2);
        if (notes.isNotEmpty) {
          expect(notes[0].id, note2.id);
          if (notes.length > 1) {
            expect(notes[1].id, note1.id);
          }
        }
      });

      test('updateNote devrait mettre à jour une note', () async {
        await firestoreService.createNote(note1);
        final updatedContent = 'Contenu mis à jour';
        final newTimestamp = Timestamp.fromMillisecondsSinceEpoch(Timestamp.now().millisecondsSinceEpoch + 5000);
        final noteToUpdate = note1.copyWith(content: updatedContent, eventTimestamp: newTimestamp);

        await firestoreService.updateNote(noteToUpdate);
        final docSnap = await fakeFirestore.collection('notes').doc(note1.id).get();
        final doc = docSnap.data() as Map<String, dynamic>?;
        expect(doc?['content'], updatedContent);
        expect(doc?['eventTimestamp'], newTimestamp);
        expect((doc?['lastUpdatedAt'] as Timestamp).microsecondsSinceEpoch, greaterThan(note1.lastUpdatedAt.microsecondsSinceEpoch));
      });

      test('deleteNote devrait supprimer une note', () async {
        await firestoreService.createNote(note1);
        await firestoreService.deleteNote(note1.id);
        final doc = await fakeFirestore.collection('notes').doc(note1.id).get();
        expect(doc.exists, isFalse);
      });
    });

    group('PaletteModel Management', () {
      final testUserId = 'paletteModelUser';
      final colorM1 = createTestColorData(title: 'ModelColor1', hex: '#ABCDEF', id: 'mc1');
      final paletteModel1 = PaletteModel(id: 'pm1', name: 'Mon Modèle 1', colors: [colorM1], userId: testUserId);
      final paletteModel2 = PaletteModel(id: 'pm2', name: 'Mon Modèle Alpha', colors: [colorM1], userId: testUserId);

      test('createPaletteModel devrait ajouter un modèle de palette', () async {
        await firestoreService.createPaletteModel(paletteModel1);
        final doc = await fakeFirestore.collection('paletteModels').doc(paletteModel1.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], paletteModel1.name);
        expect(doc.data()?['userId'], testUserId);
      });

      test('getUserPaletteModelsStream devrait retourner les modèles de l\'utilisateur triés par nom', () async {
        await firestoreService.createPaletteModel(paletteModel1);
        await firestoreService.createPaletteModel(paletteModel2);

        final stream = firestoreService.getUserPaletteModelsStream(testUserId);
        final models = await stream.first;

        expect(models.length, 2);
        expect(models[0].name, 'Mon Modèle Alpha');
        expect(models[1].name, 'Mon Modèle 1');
      });

      test('getPredefinedPaletteModelsStream devrait retourner les modèles prédéfinis (simulés dans Firestore)', () async {
        final predefined1 = PaletteModel(id: 'predef1', name: 'A Predefined', colors: [], isPredefined: true);
        final predefined2 = PaletteModel(id: 'predef2', name: 'Z Predefined', colors: [], isPredefined: true);
        await fakeFirestore.collection('paletteModels').doc(predefined1.id).set(predefined1.toMap());
        await fakeFirestore.collection('paletteModels').doc(predefined2.id).set(predefined2.toMap());

        final stream = firestoreService.getPredefinedPaletteModelsStream();
        final models = await stream.first;

        expect(models.length, 2);
        expect(models.any((m) => m.id == 'predef1'), isTrue);
        expect(models.any((m) => m.id == 'predef2'), isTrue);
        if (models.isNotEmpty) expect(models[0].name, 'A Predefined');
      });

      test('updatePaletteModel devrait mettre à jour un modèle', () async {
        await firestoreService.createPaletteModel(paletteModel1);
        final updatedName = 'Mon Modèle 1 Modifié';
        final updatedModel = paletteModel1.copyWith(name: updatedName);

        await firestoreService.updatePaletteModel(updatedModel);
        final doc = await fakeFirestore.collection('paletteModels').doc(paletteModel1.id).get();
        expect(doc.data()?['name'], updatedName);
      });

      test('deletePaletteModel devrait supprimer un modèle', () async {
        await firestoreService.createPaletteModel(paletteModel1);
        await firestoreService.deletePaletteModel(paletteModel1.id);
        final doc = await fakeFirestore.collection('paletteModels').doc(paletteModel1.id).get();
        expect(doc.exists, isFalse);
      });

      test('checkPaletteModelNameExists devrait fonctionner correctement', () async {
        await firestoreService.createPaletteModel(paletteModel1);
        expect(await firestoreService.checkPaletteModelNameExists(paletteModel1.name, testUserId), isTrue);
        expect(await firestoreService.checkPaletteModelNameExists(paletteModel1.name, testUserId, excludeId: paletteModel1.id), isFalse);
        expect(await firestoreService.checkPaletteModelNameExists('Nouveau Nom Modèle', testUserId), isFalse);

        final paletteModelSameNameOtherUser = PaletteModel(id: 'pmOther', name: paletteModel1.name, colors: [], userId: 'otherUser123');
        await firestoreService.createPaletteModel(paletteModelSameNameOtherUser);
        expect(await firestoreService.checkPaletteModelNameExists(paletteModel1.name, testUserId), isTrue);
      });
    });

    group('initializeNewUserData', () {
      test('initializeNewUserData devrait créer un journal par défaut avec des paletteElementId uniques pour les couleurs', () async {
        when(mockFbUser.uid).thenReturn('newUserWithPaletteCheck');
        when(mockFbUser.email).thenReturn('newpalette@example.com');
        when(mockFbUser.displayName).thenReturn('New Palette User');

        await firestoreService.initializeNewUserData(mockFbUser, displayName: 'New Palette User', email: 'newpalette@example.com');

        final journalQuery = await fakeFirestore.collection('journals')
            .where('userId', isEqualTo: 'newUserWithPaletteCheck').limit(1).get();
        expect(journalQuery.docs.isNotEmpty, isTrue);
        final journalData = journalQuery.docs.first.data();
        final paletteData = journalData['palette'] as Map<String, dynamic>;
        final colorsList = paletteData['colors'] as List<dynamic>;

        expect(colorsList.isNotEmpty, isTrue);
        final Set<String> paletteElementIds = {};
        for (var colorMap in colorsList) {
          final color = ColorData.fromMap(colorMap as Map<String, dynamic>);
          expect(color.paletteElementId, isNotEmpty);
          expect(paletteElementIds.contains(color.paletteElementId), isFalse);
          paletteElementIds.add(color.paletteElementId);
        }
      });
    });
  });
}
