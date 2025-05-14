// test/unit/models/journal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Journal Model Tests', () {
    final Timestamp now = Timestamp.now();
    final testUserId = 'userTest123';

    Palette createSamplePalette({String? id, String name = 'Sample Palette', List<ColorData>? colors}) {
      return Palette(
        id: id ?? Uuid().v4(),
        name: name,
        colors: colors ?? [ColorData(title: 'Default Color', hexCode: '#808080')],
        userId: testUserId,
      );
    }

    test('Constructeur devrait assigner les valeurs et générer un ID si non fourni', () {
      final palette = createSamplePalette();
      final journal = Journal(
        userId: testUserId,
        name: 'Mon Journal',
        palette: palette,
        createdAt: now,
        lastUpdatedAt: now,
      );

      expect(journal.id, isNotEmpty);
      expect(Uuid.isValidUUID(fromString: journal.id), isTrue);
      expect(journal.userId, testUserId);
      expect(journal.name, 'Mon Journal');
      expect(journal.palette.name, palette.name);
      expect(journal.createdAt, now);
      expect(journal.lastUpdatedAt, now);

      final journalWithId = Journal(
        id: 'custom-journal-id',
        userId: testUserId,
        name: 'Autre Journal',
        palette: palette,
        createdAt: now,
        lastUpdatedAt: now,
      );
      expect(journalWithId.id, 'custom-journal-id');
    });

    test('toMap devrait retourner une map correcte', () {
      final color1 = ColorData(paletteElementId: 'c1', title: 'Rouge', hexCode: '#FF0000');
      final palette = createSamplePalette(id: 'p1', colors: [color1]);
      final journal = Journal(
        id: 'journalX',
        userId: testUserId,
        name: 'Journal X',
        palette: palette,
        createdAt: now,
        lastUpdatedAt: now,
      );
      final map = journal.toMap();

      // L'ID du journal lui-même n'est pas dans la map, car il est l'ID du document
      expect(map['userId'], testUserId);
      expect(map['name'], 'Journal X');
      expect(map['createdAt'], now);
      expect(map['lastUpdatedAt'], now);

      final paletteMap = map['palette'] as Map<String, dynamic>;
      expect(paletteMap['id'], palette.id); // L'ID de la palette est dans la map de la palette
      expect(paletteMap['name'], palette.name);
      expect(paletteMap['colors'], isA<List>());
      expect((paletteMap['colors'] as List).length, 1);
      expect((paletteMap['colors'] as List)[0]['paletteElementId'], 'c1');
    });

    test('fromMap devrait créer une instance Journal correcte', () {
      final paletteMapData = {
        'id': 'palette-from-map',
        'name': 'Palette de la Map',
        'colors': [
          {'paletteElementId': 'color-fm-1', 'title': 'Bleu Map', 'hexCode': '#0000FF', 'isDefault': false}
        ],
        'userId': testUserId,
        'isPredefined': false,
      };
      final map = {
        'userId': testUserId,
        'name': 'Journal de la Map',
        'palette': paletteMapData,
        'createdAt': now,
        'lastUpdatedAt': now,
      };
      final documentId = 'journal-from-map-id';
      final journal = Journal.fromMap(map, documentId);

      expect(journal.id, documentId);
      expect(journal.userId, testUserId);
      expect(journal.name, 'Journal de la Map');
      expect(journal.createdAt, now);
      expect(journal.lastUpdatedAt, now);

      expect(journal.palette.id, 'palette-from-map');
      expect(journal.palette.name, 'Palette de la Map');
      expect(journal.palette.colors.length, 1);
      expect(journal.palette.colors.first.title, 'Bleu Map');
    });

    test('fromMap devrait gérer les champs optionnels/nuls et fournir des valeurs par défaut', () {
      final map = { // userId et name manquants, palette nulle
        'createdAt': null, // Sera remplacé par Timestamp.now()
        'lastUpdatedAt': now,
        'palette': null,
      };
      final documentId = 'journal-defaults';
      final journal = Journal.fromMap(map, documentId);

      expect(journal.id, documentId);
      expect(journal.userId, ''); // Valeur par défaut
      expect(journal.name, 'Journal sans nom'); // Valeur par défaut
      expect(journal.createdAt.toDate().difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      expect(journal.lastUpdatedAt, now);

      expect(journal.palette, isNotNull);
      expect(journal.palette.name, 'Palette par défaut'); // Nom par défaut pour palette nulle
      expect(journal.palette.colors, isEmpty);
      expect(journal.palette.userId, ''); // userId de la palette prend celui du journal
    });

    test('fromMap devrait gérer palette manquante mais userId présent pour la palette par défaut', () {
      final mapWithUserId = {
        'userId': testUserId,
        'name': 'Journal avec UserID',
        'palette': null, // Palette explicitement nulle
        'createdAt': now,
        'lastUpdatedAt': now,
      };
      final journal = Journal.fromMap(mapWithUserId, 'journal-with-uid');
      expect(journal.palette.userId, testUserId);
    });


    test('copyWith devrait copier l\'instance avec/sans nouvelles valeurs, y compris la palette en profondeur', () {
      final colorOrig = ColorData(paletteElementId: 'orig-c1', title: 'Couleur Originale', hexCode: '#111111');
      final paletteOrig = createSamplePalette(id: 'orig-p1', name: 'Palette Originale', colors: [colorOrig]);
      final journalOrig = Journal(
        id: 'orig-j1',
        userId: testUserId,
        name: 'Journal Original',
        palette: paletteOrig,
        createdAt: now,
        lastUpdatedAt: now,
      );

      final journalCopiedIdentical = journalOrig.copyWith();
      expect(journalCopiedIdentical.id, journalOrig.id);
      expect(journalCopiedIdentical.name, journalOrig.name);
      expect(journalCopiedIdentical.palette.id, journalOrig.palette.id);
      expect(journalCopiedIdentical.palette.colors.first.title, journalOrig.palette.colors.first.title);
      // S'assurer que ce n'est pas la même instance de liste de couleurs
      expect(identical(journalCopiedIdentical.palette.colors, journalOrig.palette.colors), isFalse);
      expect(identical(journalCopiedIdentical.palette, journalOrig.palette), isFalse);


      final colorNew = ColorData(paletteElementId: 'new-c1', title: 'Nouvelle Couleur', hexCode: '#222222');
      final paletteNew = createSamplePalette(id: 'new-p1', name: 'Nouvelle Palette', colors: [colorNew]);
      final journalCopiedModified = journalOrig.copyWith(
          name: 'Journal Modifié',
          palette: paletteNew,
          lastUpdatedAt: Timestamp.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch + 1000)
      );

      expect(journalCopiedModified.id, journalOrig.id); // ID reste le même par défaut
      expect(journalCopiedModified.name, 'Journal Modifié');
      expect(journalCopiedModified.palette.id, 'new-p1');
      expect(journalCopiedModified.palette.colors.first.title, 'Nouvelle Couleur');
      expect(journalCopiedModified.lastUpdatedAt.millisecondsSinceEpoch, greaterThan(now.millisecondsSinceEpoch));
    });
  });
}
