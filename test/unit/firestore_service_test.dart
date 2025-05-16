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

  // ... (autres groupes de tests)

  group('FirestoreService Tests', () {
    // ... (autres sous-groupes de tests pour User, Journal, Note)

    group('PaletteModel Management', () {
      final testUserId = 'paletteModelUser';
      final colorM1 = createTestColorData(title: 'ModelColor1', hex: '#ABCDEF', id: 'mc1');
      // Noms choisis pour tester le tri alphabétique
      final palettemodelB = PaletteModel(id: 'pmB', name: 'Modèle B - Beta', colors: [colorM1], userId: testUserId);
      final palettemodelA = PaletteModel(id: 'pmA', name: 'Modèle A - Alpha', colors: [colorM1], userId: testUserId);
      final palettemodelC = PaletteModel(id: 'pmC', name: 'Modèle C - Charlie', colors: [colorM1], userId: testUserId);

      test('getUserPaletteModelsStream devrait retourner les modèles de l\'utilisateur triés par nom', () async {
        // Ajouter dans un ordre non alphabétique pour vérifier le tri
        await firestoreService.createPaletteModel(palettemodelB);
        await firestoreService.createPaletteModel(palettemodelC);
        await firestoreService.createPaletteModel(palettemodelA);

        await Future.delayed(Duration.zero); // Permettre à FakeFirestore de traiter

        final stream = firestoreService.getUserPaletteModelsStream(testUserId);
        final models = await stream.first;

        expect(models.length, 3);
        // Vérifier l'ordre après le tri par nom attendu du service
        if (models.length == 3) {
          expect(models[0].name, 'Modèle A - Alpha', reason: "Devrait être trié par nom ascendant.");
          expect(models[1].name, 'Modèle B - Beta');
          expect(models[2].name, 'Modèle C - Charlie');
        }
      });

      test('getPredefinedPaletteModelsStream devrait retourner les modèles prédéfinis triés par nom', () async {
        final predefinedZ = PaletteModel(id: 'predefZ', name: 'Z Predefined', colors: [], isPredefined: true);
        final predefinedA = PaletteModel(id: 'predefA', name: 'A Predefined', colors: [], isPredefined: true);
        await fakeFirestore.collection('paletteModels').doc(predefinedZ.id).set(predefinedZ.toMap());
        await fakeFirestore.collection('paletteModels').doc(predefinedA.id).set(predefinedA.toMap());

        await Future.delayed(Duration.zero);

        final stream = firestoreService.getPredefinedPaletteModelsStream();
        final models = await stream.first;

        expect(models.length, 2);
        if (models.length == 2) {
          expect(models[0].name, 'A Predefined', reason: "Les modèles prédéfinis doivent être triés par nom.");
          expect(models[1].name, 'Z Predefined');
        }
      });

      // ... autres tests pour PaletteModel Management (create, update, delete, checkNameExists)
      test('createPaletteModel devrait ajouter un modèle de palette', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        final doc = await fakeFirestore.collection('paletteModels').doc(palettemodelA.id).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], palettemodelA.name);
      });

      test('updatePaletteModel devrait mettre à jour un modèle', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        final updatedName = 'Modèle A - Alpha Modifié';
        final updatedModel = palettemodelA.copyWith(name: updatedName);

        await firestoreService.updatePaletteModel(updatedModel);
        final doc = await fakeFirestore.collection('paletteModels').doc(palettemodelA.id).get();
        expect(doc.data()?['name'], updatedName);
      });

      test('deletePaletteModel devrait supprimer un modèle', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        await firestoreService.deletePaletteModel(palettemodelA.id);
        final doc = await fakeFirestore.collection('paletteModels').doc(palettemodelA.id).get();
        expect(doc.exists, isFalse);
      });

      test('checkPaletteModelNameExists devrait fonctionner correctement', () async {
        await firestoreService.createPaletteModel(palettemodelA);
        expect(await firestoreService.checkPaletteModelNameExists(palettemodelA.name, testUserId), isTrue);
        expect(await firestoreService.checkPaletteModelNameExists(palettemodelA.name, testUserId, excludeId: palettemodelA.id), isFalse);
        expect(await firestoreService.checkPaletteModelNameExists('Nouveau Nom Inexistant', testUserId), isFalse);
      });
    });

    group('initializeNewUserData', () {
      test('initializeNewUserData devrait créer un journal par défaut avec des paletteElementId uniques pour les couleurs', () async {
        when(mockFbUser.uid).thenReturn('newUserWithPaletteCheck');
        when(mockFbUser.email).thenReturn('newpalette@example.com');
        when(mockFbUser.displayName).thenReturn('New Palette User');

        await firestoreService.initializeNewUserData(mockFbUser, displayName: 'New Palette User', email: 'newpalette@example.com');

        final journalQuery = await fakeFirestore.collection('journals').where('userId', isEqualTo: 'newUserWithPaletteCheck').limit(1).get();
        expect(journalQuery.docs.isNotEmpty, isTrue);
        final journalData = journalQuery.docs.first.data();
        final paletteData = journalData['palette'] as Map<String, dynamic>; // data ne sera pas null ici
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
    // ... (autres groupes de tests pour User, Journal, Note)
  });
}
