// test/unit/services/firestore_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:colors_notes/models/color_data.dart';
import 'package:colors_notes/models/palette_model.dart';
import 'package:colors_notes/services/firestore_service.dart';
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
    group('PaletteModel Management', () {
      final testUserId = 'paletteModelUser';
      final colorM1 = createTestColorData(title: 'ModelColor1', hex: '#ABCDEF', id: 'mc1');
      // Noms choisis pour tester le tri alphabétique
      final palettemodelB = PaletteModel(id: 'pmB', name: 'Modèle B - Beta', colors: [colorM1], userId: testUserId);
      final palettemodelA = PaletteModel(id: 'pmA', name: 'Modèle A - Alpha', colors: [colorM1], userId: testUserId);
      final palettemodelC = PaletteModel(id: 'pmC', name: 'Modèle C - Charlie', colors: [colorM1], userId: testUserId);

      // CORRECTION: Ajout du mot-clé 'async' car la fonction utilise 'await'.
      test('getUserPaletteModelsStream devrait retourner les modèles de l\'utilisateur triés par nom', () async {
        // Ajouter dans un ordre non alphabétique pour vérifier le tri
        await firestoreService.createPaletteModel(palettemodelB);
        await firestoreService.createPaletteModel(palettemodelC);
        await firestoreService.createPaletteModel(palettemodelA);

        final stream = firestoreService.getUserPaletteModelsStream(testUserId);
        final models = await stream.first;

        expect(models.length, 3);
        // Vérifier l'ordre après le tri par nom attendu du service
        expect(models.map((m) => m.name).toList(), orderedEquals(['Modèle A - Alpha', 'Modèle B - Beta', 'Modèle C - Charlie']));
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('getPredefinedPaletteModelsStream devrait retourner les modèles prédéfinis triés par nom', () async {
        final predefinedZ = PaletteModel(id: 'predefZ', name: 'Z Predefined', colors: [], isPredefined: true);
        final predefinedA = PaletteModel(id: 'predefA', name: 'A Predefined', colors: [], isPredefined: true);
        // Les modèles prédéfinis sont ajoutés directement à la fausse base de données pour le test.
        await fakeFirestore.collection('paletteModels').doc(predefinedZ.id).set(predefinedZ.toMap());
        await fakeFirestore.collection('paletteModels').doc(predefinedA.id).set(predefinedA.toMap());

        final stream = firestoreService.getPredefinedPaletteModelsStream();
        final models = await stream.first;

        expect(models.length, 2);
        expect(models.map((m) => m.name).toList(), orderedEquals(['A Predefined', 'Z Predefined']));
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('createPaletteModel devrait ajouter un modèle de palette', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        final doc = await fakeFirestore.collection('paletteModels').doc(palettemodelA.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], palettemodelA.name);
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('updatePaletteModel devrait mettre à jour un modèle', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        final updatedName = 'Modèle A - Alpha Modifié';
        final updatedModel = palettemodelA.copyWith(name: updatedName);

        await firestoreService.updatePaletteModel(updatedModel);
        final doc = await fakeFirestore.collection('paletteModels').doc(palettemodelA.id).get();
        expect(doc.data()?['name'], updatedName);
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('deletePaletteModel devrait supprimer un modèle', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        await firestoreService.deletePaletteModel(palettemodelA.id);
        final doc = await fakeFirestore.collection('paletteModels').doc(palettemodelA.id).get();
        expect(doc.exists, isFalse);
      });

      // CORRECTION: Ajout du mot-clé 'async'.
      test('checkPaletteModelNameExists devrait fonctionner correctement', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        expect(await firestoreService.checkPaletteModelNameExists(palettemodelA.name, testUserId), isTrue);
        expect(await firestoreService.checkPaletteModelNameExists(palettemodelA.name, testUserId, excludeId: palettemodelA.id), isFalse);
        expect(await firestoreService.checkPaletteModelNameExists('Nouveau Nom Inexistant', testUserId), isFalse);
      });
    });

    group('initializeNewUserData', () {
      // CORRECTION: Test réactivé et marqué comme 'async'.
      test('devrait créer un journal par défaut avec des paletteElementId uniques pour les couleurs', () async {
        when(mockFbUser.uid).thenReturn('newUserWithPaletteCheck');
        when(mockFbUser.email).thenReturn('newpalette@example.com');
        when(mockFbUser.displayName).thenReturn('New Palette User');

        await firestoreService.initializeNewUserData(mockFbUser, displayName: 'New Palette User', email: 'newpalette@example.com');

        final journalQuery = await fakeFirestore.collection('journals').where('userId', isEqualTo: 'newUserWithPaletteCheck').limit(1).get();
        expect(journalQuery.docs.isNotEmpty, isTrue);
        final journalData = journalQuery.docs.first.data();
        final paletteData = journalData['palette'] as Map<String, dynamic>;
        final colorsList = paletteData['colors'] as List<dynamic>;

        expect(colorsList.isNotEmpty, isTrue);
        final Set<String> paletteElementIds = {};
        for (var colorMap in colorsList) {
          final color = ColorData.fromMap(colorMap as Map<String, dynamic>);
          expect(color.paletteElementId, isNotEmpty);
          expect(paletteElementIds.contains(color.paletteElementId), isFalse, reason: "Les IDs des éléments de palette doivent être uniques.");
          paletteElementIds.add(color.paletteElementId);
        }
      });
    });
  });
}