// test/unit/models/palette_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Palette Model Tests', () {
    final testUserId = 'userPaletteTest';

    ColorData createTestColor(String id, String title, String hex) {
      return ColorData(paletteElementId: id, title: title, hexCode: hex);
    }

    test('Constructeur devrait assigner les valeurs et générer un ID si non fourni', () {
      final colors = [createTestColor('c1', 'Rouge', '#FF0000')];
      final palette = Palette(
        name: 'Ma Palette',
        colors: colors,
        userId: testUserId,
        isPredefined: false,
      );

      expect(palette.id, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: palette.id), isTrue);
      expect(palette.name, 'Ma Palette');
      expect(palette.colors.length, 1);
      expect(palette.colors.first.title, 'Rouge');
      expect(palette.userId, testUserId);
      expect(palette.isPredefined, isFalse);

      final paletteWithId = Palette(
        id: 'custom-palette-id',
        name: 'Autre Palette',
        colors: [],
      );
      expect(paletteWithId.id, 'custom-palette-id');
    });

    test('toMap devrait retourner une map correcte et inclure son propre ID', () {
      final colors = [
        createTestColor('c1', 'Rouge', '#FF0000'),
        createTestColor('c2', 'Bleu', '#0000FF')
      ];
      final palette = Palette(
        id: 'paletteX-ID', // L'ID de la palette elle-même
        name: 'Palette X',
        colors: colors,
        userId: testUserId,
        isPredefined: true,
      );
      final map = palette.toMap();

      // CORRECTION: S'attendre à ce que la clé 'id' SOIT présente
      expect(map.containsKey('id'), isTrue);
      expect(map['id'], 'paletteX-ID');
      expect(map['name'], 'Palette X');
      expect(map['userId'], testUserId);
      expect(map['isPredefined'], isTrue);

      final colorsMapList = map['colors'] as List<dynamic>;
      expect(colorsMapList.length, 2);
      expect(colorsMapList[0]['title'], 'Rouge');
      expect(colorsMapList[1]['paletteElementId'], 'c2');
    });

    test('fromMap (pour document Firestore) devrait créer une instance Palette correcte', () {
      final Map<String, dynamic> map = {
        'name': 'Palette de Map Doc',
        'colors': [
          {'paletteElementId': 'cd-map-1', 'title': 'Vert Map', 'hexCode': '#00FF00', 'isDefault': false}
        ],
        'userId': testUserId,
        'isPredefined': false,
      };
      final documentId = 'palette-from-map-doc-id';
      final palette = Palette.fromMap(map, documentId);

      expect(palette.id, documentId);
      expect(palette.name, 'Palette de Map Doc');
      expect(palette.userId, testUserId);
      expect(palette.isPredefined, false);
      expect(palette.colors.length, 1);
      expect(palette.colors.first.title, 'Vert Map');
    });

    test('fromEmbeddedMap (pour palette imbriquée) devrait créer une instance Palette correcte', () {
      final Map<String, dynamic> embeddedMap = {
        'id': 'embedded-palette-id',
        'name': 'Palette Imbriquée',
        'colors': [
          {'paletteElementId': 'cd-emb-1', 'title': 'Orange Emb', 'hexCode': '#FFA500', 'isDefault': true}
        ],
        'userId': testUserId,
        'isPredefined': true,
      };
      final palette = Palette.fromEmbeddedMap(embeddedMap);

      expect(palette.id, 'embedded-palette-id');
      expect(palette.name, 'Palette Imbriquée');
      expect(palette.userId, testUserId);
      expect(palette.isPredefined, true);
      expect(palette.colors.length, 1);
      expect(palette.colors.first.title, 'Orange Emb');
      expect(palette.colors.first.isDefault, isTrue);
    });

    test('fromMap/fromEmbeddedMap devraient gérer les champs nuls et fournir des valeurs par défaut', () {
      final Map<String, dynamic> mapNoName = { 'colors': [] };
      final palette1 = Palette.fromMap(mapNoName, 'p1-defaults');
      expect(palette1.name, 'Palette sans nom');
      expect(palette1.colors, isEmpty);
      expect(palette1.isPredefined, false);
      expect(palette1.userId, isNull);


      final Map<String, dynamic> embeddedMapNoIdOrName = { 'colors': null, 'userId': testUserId };
      final palette2 = Palette.fromEmbeddedMap(embeddedMapNoIdOrName);
      expect(palette2.id, isNotEmpty);
      expect(palette2.name, 'Palette sans nom');
      expect(palette2.colors, isEmpty);
      expect(palette2.userId, testUserId); // userId est passé, donc il est conservé
      expect(palette2.isPredefined, false);
    });

    test('copyWith devrait copier l\'instance avec/sans nouvelles valeurs', () {
      final colorOrig1 = createTestColor('co1', 'Orig1', '#111');
      final paletteOrig = Palette(
        id: 'orig-p',
        name: 'Palette Originale',
        colors: [colorOrig1],
        userId: testUserId,
      );

      final paletteCopiedIdentical = paletteOrig.copyWith();
      expect(paletteCopiedIdentical.id, paletteOrig.id);
      expect(paletteCopiedIdentical.name, paletteOrig.name);
      expect(paletteCopiedIdentical.colors.length, 1);
      expect(paletteCopiedIdentical.colors[0].title, 'Orig1');
      expect(identical(paletteCopiedIdentical.colors, paletteOrig.colors), isFalse);
      expect(identical(paletteCopiedIdentical.colors[0], paletteOrig.colors[0]), isFalse);


      final colorNew = createTestColor('cn1', 'Nouvelle Couleur', '#333');
      final paletteCopiedModified = paletteOrig.copyWith(
          name: 'Palette Modifiée',
          colors: [colorNew],
          userId: 'newUser',
          isPredefined: true
      );
      expect(paletteCopiedModified.name, 'Palette Modifiée');
      expect(paletteCopiedModified.colors.length, 1);
      expect(paletteCopiedModified.colors.first.title, 'Nouvelle Couleur');
      expect(paletteCopiedModified.userId, 'newUser');
      expect(paletteCopiedModified.isPredefined, isTrue);
    });

    test('copyWith avec clearUserId devrait mettre userId à null', () {
      final paletteWithUser = Palette(name: 'Test', colors: [], userId: 'user123');
      final paletteCleared = paletteWithUser.copyWith(clearUserId: true);
      expect(paletteCleared.userId, isNull);

      final paletteClearedDespiteNewId = paletteWithUser.copyWith(userId: 'newUser456', clearUserId: true);
      expect(paletteClearedDespiteNewId.userId, isNull);
    });
  });
}
