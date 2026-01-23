import 'dart:async'; // Added for StreamController
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:colors_notes/models/journal.dart';
import 'package:colors_notes/models/palette.dart';
import 'package:colors_notes/models/palette_model.dart';
import 'package:colors_notes/models/color_data.dart';
import 'package:colors_notes/services/firestore_service.dart';
import 'package:colors_notes/core/predefined_templates.dart';
import 'package:colors_notes/viewmodels/create_journal_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'create_journal_view_model_test.mocks.dart';

// Mock AppLocalizations
class MockAppLocalizations extends Mock implements AppLocalizations {
  @override
  String paletteOfJournalName(String journalName) => 'Palette of $journalName';
  @override
  String get newPaletteDefaultName => 'New Palette';
  @override
  String paletteFromModelName(String journalName, String modelName) =>
      'Palette from $modelName for $journalName';
  @override
  String paletteFromModelNameNoJournal(String modelName) =>
      'Palette from $modelName';
  @override
  String paletteCopiedFromName(String journalName, String sourceName) =>
      'Copy of $sourceName for $journalName';
  @override
  String paletteCopiedFromNameNoJournal(String sourceName) =>
      'Copy of $sourceName';
}

// ... existing imports ...

@GenerateMocks([FirestoreService])
void main() {
  late MockFirestoreService mockFirestoreService;
  late CreateJournalViewModel viewModel;
  late MockAppLocalizations mockL10n;
  late StreamController<List<PaletteModel>> paletteStreamController;
  late StreamController<List<Journal>> journalStreamController;
  const userId = 'test_user_id';

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    mockL10n = MockAppLocalizations();

    // Initialize controllers
    paletteStreamController = StreamController<List<PaletteModel>>();
    journalStreamController = StreamController<List<Journal>>();

    // Mock initial data streams/futures
    when(mockFirestoreService.getUserPaletteModelsStream(any))
        .thenAnswer((_) => paletteStreamController.stream);
    when(mockFirestoreService.getJournalsStream(any))
        .thenAnswer((_) => journalStreamController.stream);

    addTearDown(() {
      paletteStreamController.close();
      journalStreamController.close();
    });

    viewModel = CreateJournalViewModel(mockFirestoreService, userId);
  });

  group('CreateJournalViewModel', () {
    test('initial state is correct', () {
      expect(viewModel.isLoading, true);
      expect(viewModel.creationMode, JournalCreationMode.emptyPalette);
    });

    test('loadInitialData populates models and journals', () async {
      final palettes = [
        PaletteModel(
            id: '1',
            name: 'P1',
            colors: <ColorData>[],
            isPredefined: false,
            userId: userId)
      ];
      final journals = [
        Journal(
            id: 'j1',
            userId: userId,
            name: 'J1',
            palette: Palette(
                id: 'p1',
                name: 'PP1',
                colors: <ColorData>[],
                isPredefined: false,
                userId: userId),
            createdAt: Timestamp.now(),
            lastUpdatedAt: Timestamp.now())
      ];

      paletteStreamController.add(palettes);
      journalStreamController.add(journals);

      // Wait for stream events to be processed
      await Future.delayed(Duration.zero);

      expect(viewModel.isLoading, false);
      expect(viewModel.availablePaletteModels.length,
          predefinedPalettes.length + 1);
      expect(viewModel.availableUserJournals.length, 1);
    });

    // Since constructor async calls are hard to test without exposing them or using a factory/init method,
    // I will checking updating state manually.

    test('setJournalName updates palette name', () {
      viewModel.setJournalName('My Journal', mockL10n);
      expect(viewModel.preparedPaletteName, 'Palette of My Journal');
    });

    test('setSourceType changes mode', () async {
      // We need models to be available to switch to fromPaletteModel mode
      paletteStreamController.add([
        PaletteModel(
            id: '1',
            name: 'P1',
            colors: [],
            isPredefined: false,
            userId: userId)
      ]);
      journalStreamController.add([]);

      // Wait for data to load
      await Future.delayed(Duration.zero);

      viewModel.setSourceType(PaletteSourceType.model, mockL10n);
      expect(viewModel.creationMode, JournalCreationMode.fromPaletteModel);
    });
  });
}
