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
      final model = PaletteModel(name: 'Mon Modèle', colors: colors, userId: testUserId, isPredefined: false);

      expect(model.id, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: model.id), isTrue);
      expect(model.name, 'Mon Modèle');
      expect(model.colors.length, 1);
      expect(model.colors.first.title, 'Modèle Rouge');
      expect(model.userId, testUserId);
      expect(model.isPredefined, isFalse);

      final modelWithId = PaletteModel(id: 'custom-model-id', name: 'Autre Modèle', colors: [], isPredefined: true);
      expect(modelWithId.id, 'custom-model-id');
      expect(modelWithId.userId, isNull);
      expect(modelWithId.isPredefined, isTrue);
    });

    test('toMap devrait retourner une map correcte', () {
      final colors = [createTestColor('mc1', 'Modèle Couleur 1', '#ABCDEF')];
      final model = PaletteModel(id: 'modelX', name: 'Modèle X', colors: colors, userId: testUserId, isPredefined: false);
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
      final Map<String, dynamic> map = {
        'name': 'Modèle de Map',
        'colors': [
          {'paletteElementId': 'cmd-1', 'title': 'Couleur de Modèle Map', 'hexCode': '#123456', 'isDefault': false},
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
      final Map<String, dynamic> mapNoName = {'colors': [], 'userId': testUserId};
      final model1 = PaletteModel.fromMap(mapNoName, 'model1-defaults');
      expect(model1.name, 'Modèle sans nom');
      expect(model1.userId, testUserId);
      expect(model1.isPredefined, false);

      final Map<String, dynamic> mapNoUserId = {'name': 'Modèle Prédéfini Test', 'colors': [], 'isPredefined': true};
      final model2 = PaletteModel.fromMap(mapNoUserId, 'model2-predefined');
      expect(model2.name, 'Modèle Prédéfini Test');
      expect(model2.userId, isNull);
      expect(model2.isPredefined, isTrue);

      final Map<String, dynamic> mapAllNull = {'name': null, 'colors': null, 'userId': null, 'isPredefined': null};
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
        // userId initial
        isPredefined: false,
      );

      final modelCopiedIdentical = modelOrig.copyWith();
      expect(modelCopiedIdentical.id, modelOrig.id);
      expect(modelCopiedIdentical.name, modelOrig.name);
      expect(modelCopiedIdentical.colors.length, 1);
      expect(modelCopiedIdentical.colors.first.title, 'Couleur Modèle Orig');
      expect(modelCopiedIdentical.userId, testUserId); // Doit conserver l'userId original
      expect(identical(modelCopiedIdentical.colors, modelOrig.colors), isFalse);
      expect(identical(modelCopiedIdentical.colors[0], modelOrig.colors[0]), isFalse);

      final colorNew = createTestColor('mcn1', 'Nouvelle Couleur Modèle', '#FFF');
      // Test de la modification de userId vers une nouvelle valeur
      final modelCopiedModifiedUser = modelOrig.copyWith(userId: 'newUser');
      expect(modelCopiedModifiedUser.userId, 'newUser');

      // Test de la suppression de userId en utilisant clearUserId
      final modelCopiedClearedUser = modelOrig.copyWith(
        name: 'Modèle Modifié',
        colors: [colorNew],
        clearUserId: true, // Explicitement pour mettre userId à null
        isPredefined: true,
      );
      expect(modelCopiedClearedUser.id, modelOrig.id);
      expect(modelCopiedClearedUser.name, 'Modèle Modifié');
      expect(modelCopiedClearedUser.colors.first.title, 'Nouvelle Couleur Modèle');
      expect(modelCopiedClearedUser.userId, isNull); // Attendu null à cause de clearUserId: true
      expect(modelCopiedClearedUser.isPredefined, isTrue);

      // Test où userId est fourni mais clearUserId est aussi true (clearUserId doit l'emporter)
      final modelCopiedClearedUserDespiteNew = modelOrig.copyWith(userId: 'anotherUser', clearUserId: true);
      expect(modelCopiedClearedUserDespiteNew.userId, isNull);
    });
  });
}
