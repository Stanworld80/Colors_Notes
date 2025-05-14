// test/unit/models/palette_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:colors_notes/models/palette_model.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('PaletteModel Model Tests', () {
    final testUserId = 'userModelTest';

    ColorData createTestColor(String id, String title, String hex) {
      return ColorData(paletteElementId: id, title: title, hexCode: hex);
    }

    test('Constructeur devrait assigner les valeurs et générer un ID si non fourni', () {
      final colors = [createTestColor('c1', 'Modèle Rouge', '#FF0000')];
      final model = PaletteModel(
        name: 'Mon Modèle',
        colors: colors,
        userId: testUserId, // Un modèle personnel
        isPredefined: false,
      );

      expect(model.id, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: model.id), isTrue);
      expect(model.name, 'Mon Modèle');
      expect(model.colors.length, 1);
      expect(model.colors.first.title, 'Modèle Rouge');
      expect(model.userId, testUserId);
      expect(model.isPredefined, isFalse);

      final modelWithId = PaletteModel(
        id: 'custom-model-id',
        name: 'Autre Modèle',
        colors: [],
        isPredefined: true, // Un modèle prédéfini (userId peut être null)
      );
      expect(modelWithId.id, 'custom-model-id');
      expect(modelWithId.userId, isNull);
      expect(modelWithId.isPredefined, isTrue);
    });

    test('toMap devrait retourner une map correcte', () {
      final colors = [
        createTestColor('mc1', 'Modèle Couleur 1', '#ABCDEF'),
      ];
      final model = PaletteModel(
        id: 'modelX', // L'ID du modèle lui-même n'est pas dans toMap
        name: 'Modèle X',
        colors: colors,
        userId: testUserId,
        isPredefined: false,
      );
      final map = model.toMap();

      expect(map['name'], 'Modèle X');
      expect(map['userId'], testUserId);
      expect(map['isPredefined'], isFalse);
      expect(map.containsKey('id'), isFalse);

      final colorsMapList = map['colors'] as List<dynamic>;
      expect(colorsMapList.length, 1);
      expect(colorsMapList[0]['title'], 'Modèle Couleur 1');
    });

    test('fromMap devrait créer une instance PaletteModel correcte', () {
      final map = {
        'name': 'Modèle de Map',
        'colors': [
          {'paletteElementId': 'cmd-1', 'title': 'Couleur de Modèle Map', 'hexCode': '#123456', 'isDefault': false}
        ],
        'userId': testUserId,
        'isPredefined': false,
      };
      final documentId = 'model-from-map-id';
      final model = PaletteModel.fromMap(map, documentId);

      expect(model.id, documentId);
      expect(model.name, 'Modèle de Map');
      expect(model.userId, testUserId);
      expect(model.isPredefined, false);
      expect(model.colors.length, 1);
      expect(model.colors.first.title, 'Couleur de Modèle Map');
    });

    test('fromMap devrait gérer les champs nuls et fournir des valeurs par défaut', () {
      final mapNoName = { 'colors': [], 'userId': testUserId }; // name manquant
      final model1 = PaletteModel.fromMap(mapNoName, 'model1-defaults');
      expect(model1.name, 'Modèle sans nom'); // Valeur par défaut
      expect(model1.userId, testUserId);
      expect(model1.isPredefined, false); // Valeur par défaut

      final mapNoUserId = { 'name': 'Modèle Prédéfini Test', 'colors': [], 'isPredefined': true };
      final model2 = PaletteModel.fromMap(mapNoUserId, 'model2-predefined');
      expect(model2.name, 'Modèle Prédéfini Test');
      expect(model2.userId, isNull); // userId peut être null pour les prédéfinis
      expect(model2.isPredefined, isTrue);

      final mapAllNull = { 'name': null, 'colors': null, 'userId': null, 'isPredefined': null };
      final model3 = PaletteModel.fromMap(mapAllNull, 'model3-all-null');
      expect(model3.name, 'Modèle sans nom');
      expect(model3.colors, isEmpty);
      expect(model3.userId, isNull);
      expect(model3.isPredefined, isFalse);
    });


    test('copyWith devrait copier l\'instance avec/sans nouvelles valeurs', () {
      final colorOrig = createTestColor('mco1', 'Couleur Modèle Orig', '#EEE');
      final modelOrig = PaletteModel(
        id: 'orig-m',
        name: 'Modèle Original',
        colors: [colorOrig],
        userId: testUserId,
        isPredefined: false,
      );

      final modelCopiedIdentical = modelOrig.copyWith();
      expect(modelCopiedIdentical.id, modelOrig.id);
      expect(modelCopiedIdentical.name, modelOrig.name);
      expect(modelCopiedIdentical.colors.length, 1);
      expect(modelCopiedIdentical.colors.first.title, 'Couleur Modèle Orig');
      expect(identical(modelCopiedIdentical.colors, modelOrig.colors), isFalse);
      expect(identical(modelCopiedIdentical.colors[0], modelOrig.colors[0]), isFalse);


      final colorNew = createTestColor('mcn1', 'Nouvelle Couleur Modèle', '#FFF');
      final modelCopiedModified = modelOrig.copyWith(
        name: 'Modèle Modifié',
        colors: [colorNew],
        userId: null, // Peut devenir un modèle prédéfini
        isPredefined: true,
      );

      expect(modelCopiedModified.id, modelOrig.id);
      expect(modelCopiedModified.name, 'Modèle Modifié');
      expect(modelCopiedModified.colors.first.title, 'Nouvelle Couleur Modèle');
      expect(modelCopiedModified.userId, isNull);
      expect(modelCopiedModified.isPredefined, isTrue);
    });
  });
}
