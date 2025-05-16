// test/unit/models/color_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('ColorData Model Tests', () {
    const defaultGreyColor = Color(0xFF808080);

    test('Constructeur devrait assigner les valeurs et générer un paletteElementId si non fourni', () {
      final colorData = ColorData(title: 'Rouge', hexCode: '#FF0000');
      expect(colorData.title, 'Rouge');
      expect(colorData.hexCode, '#FF0000');
      expect(colorData.isDefault, isFalse);
      expect(colorData.paletteElementId, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: colorData.paletteElementId), isTrue);

      final colorDataWithId = ColorData(paletteElementId: 'custom-id-123', title: 'Bleu', hexCode: '#0000FF');
      expect(colorDataWithId.paletteElementId, 'custom-id-123');
    });

    test('toMap devrait retourner une map correcte', () {
      final colorData = ColorData(paletteElementId: 'id1', title: 'Vert', hexCode: '#00FF00', isDefault: true);
      final map = colorData.toMap();

      expect(map['paletteElementId'], 'id1');
      expect(map['title'], 'Vert');
      expect(map['hexCode'], '#00FF00');
      expect(map['isDefault'], isTrue);
    });

    test('fromMap devrait créer une instance ColorData correcte', () {
      final map = {'paletteElementId': 'id2', 'title': 'Jaune', 'hexCode': '#FFFF00', 'isDefault': false};
      final colorData = ColorData.fromMap(map);

      expect(colorData.paletteElementId, 'id2');
      expect(colorData.title, 'Jaune');
      expect(colorData.hexCode, '#FFFF00');
      expect(colorData.isDefault, isFalse);
    });

    test('fromMap devrait utiliser des valeurs par défaut si des champs sont manquants ou nuls', () {
      final mapWithoutOptionalFields = {'hexCode': '#123456'}; // title, paletteElementId, isDefault manquants
      final colorData1 = ColorData.fromMap(mapWithoutOptionalFields);
      expect(colorData1.paletteElementId, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: colorData1.paletteElementId), isTrue);
      expect(colorData1.title, 'Sans titre');
      expect(colorData1.isDefault, isFalse);

      final mapWithNulls = {'paletteElementId': null, 'title': null, 'hexCode': null, 'isDefault': null};
      final colorData2 = ColorData.fromMap(mapWithNulls);
      expect(colorData2.paletteElementId, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: colorData2.paletteElementId), isTrue);
      expect(colorData2.title, 'Sans titre');
      expect(colorData2.hexCode, '808080'); // Default hex
      expect(colorData2.isDefault, isFalse);
    });

    test('copyWith devrait copier l\'instance avec/sans nouvelles valeurs', () {
      final original = ColorData(paletteElementId: 'orig-id', title: 'Original', hexCode: '#AAAAAA', isDefault: true);

      final copiedIdentical = original.copyWith();
      expect(copiedIdentical.paletteElementId, original.paletteElementId);
      expect(copiedIdentical.title, original.title);
      expect(copiedIdentical.hexCode, original.hexCode);
      expect(copiedIdentical.isDefault, original.isDefault);

      final copiedModified = original.copyWith(title: 'Modifié', hexCode: '#BBBBBB', isDefault: false, paletteElementId: 'new-id-for-copy');
      expect(copiedModified.paletteElementId, 'new-id-for-copy');
      expect(copiedModified.title, 'Modifié');
      expect(copiedModified.hexCode, '#BBBBBB');
      expect(copiedModified.isDefault, false);
    });

    test('getter color devrait convertir hexCode en Color et gérer les erreurs', () {
      final colorDataRed = ColorData(title: 'Rouge', hexCode: '#FF0000');
      expect(colorDataRed.color, const Color(0xFFFF0000));

      final colorDataGreenNoHash = ColorData(title: 'Vert', hexCode: '00FF00');
      expect(colorDataGreenNoHash.color, const Color(0xFF00FF00));

      final colorDataAlpha = ColorData(title: 'Bleu Alpha', hexCode: '#800000FF');
      expect(colorDataAlpha.color, const Color(0x800000FF));

      final colorDataInvalidHex = ColorData(title: 'Invalide', hexCode: 'XYZ123');
      expect(colorDataInvalidHex.color, defaultGreyColor);

      final colorDataEmptyHex = ColorData(title: 'Vide', hexCode: '');
      expect(colorDataEmptyHex.color, defaultGreyColor);

      final colorDataShortHex = ColorData(title: 'Court', hexCode: '#123'); // Format court non géré par la logique actuelle
      expect(colorDataShortHex.color, defaultGreyColor);

      final colorDataTooLong = ColorData(title: 'Trop Long', hexCode: '#123456789');
      expect(colorDataTooLong.color, defaultGreyColor);
    });
  });
}
