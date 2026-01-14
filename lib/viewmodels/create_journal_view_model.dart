import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../core/app_constants.dart';
import '../core/predefined_templates.dart';
import '../l10n/app_localizations.dart';

enum JournalCreationMode {
  emptyPalette,
  fromPaletteModel,
  fromExistingJournal
}

enum PaletteSourceType {
  empty,
  model,
  existingJournal
}

class CreateJournalViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final String _userId;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
  final Uuid _uuid = const Uuid();

  // State
  JournalCreationMode _creationMode = JournalCreationMode.emptyPalette;
  PaletteSourceType _selectedSourceType = PaletteSourceType.empty;
  
  PaletteModel? _selectedPaletteModel;
  List<PaletteModel> _availablePaletteModels = [];
  
  Journal? _selectedExistingJournal;
  List<Journal> _availableUserJournals = [];
  
  List<ColorData> _preparedColors = [];
  String _preparedPaletteName = "";
  
  bool _isLoading = true;
  String? _errorMessage;

  // Getters
  JournalCreationMode get creationMode => _creationMode;
  PaletteSourceType get selectedSourceType => _selectedSourceType;
  PaletteModel? get selectedPaletteModel => _selectedPaletteModel;
  List<PaletteModel> get availablePaletteModels => _availablePaletteModels;
  Journal? get selectedExistingJournal => _selectedExistingJournal;
  List<Journal> get availableUserJournals => _availableUserJournals;
  List<ColorData> get preparedColors => _preparedColors;
  String get preparedPaletteName => _preparedPaletteName;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Key to force refresh of palette editor widget if needed
  Key _paletteEditorKey = UniqueKey();
  Key get paletteEditorKey => _paletteEditorKey;

  CreateJournalViewModel(this._firestoreService, this._userId) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<PaletteModel> predefinedPalettesList = predefinedPalettes;
      
      // Using .first to get the current snapshot data once. 
      // In a real reactive flows might listen, but for a creation form, one-time fetch is often sufficient.
      final List<PaletteModel> userModels = await _firestoreService.getUserPaletteModelsStream(_userId).first;
      _availablePaletteModels = [...predefinedPalettesList, ...userModels];
      
      final List<Journal> journals = await _firestoreService.getJournalsStream(_userId).first;
      _availableUserJournals = journals;

      // Initialize default state
      _updatePaletteBasedOnMode(null);
    } catch (e) {
      _logger.e("Error loading initial data: $e");
      _errorMessage = "Impossible de charger les données: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setJournalName(String name, AppLocalizations l10n) {
    // When journal name changes, we might want to update the default palette name suggestion
    _updatePaletteBasedOnMode(l10n, journalName: name);
  }

  void setSourceType(PaletteSourceType type, AppLocalizations l10n) {
    _selectedSourceType = type;
    switch (type) {
      case PaletteSourceType.empty:
        _creationMode = JournalCreationMode.emptyPalette;
        break;
      case PaletteSourceType.model:
        _creationMode = JournalCreationMode.fromPaletteModel;
        break;
      case PaletteSourceType.existingJournal:
        _creationMode = JournalCreationMode.fromExistingJournal;
        break;
    }
    _updatePaletteBasedOnMode(l10n);
  }

  void setSelectedPaletteModel(PaletteModel? model, AppLocalizations l10n) {
    _selectedPaletteModel = model;
    _updatePaletteBasedOnMode(l10n);
  }

  void setSelectedExistingJournal(Journal? journal, AppLocalizations l10n) {
    _selectedExistingJournal = journal;
    _updatePaletteBasedOnMode(l10n);
  }

  void setPreparedColors(List<ColorData> colors) {
    _preparedColors = colors;
    notifyListeners();
  }

  void setPreparedPaletteName(String name) {
    _preparedPaletteName = name;
    notifyListeners();
  }
  
  void forcePaletteEditorRefresh() {
     _paletteEditorKey = UniqueKey();
     notifyListeners();
  }

  void _updatePaletteBasedOnMode(AppLocalizations? l10n, {String journalName = ""}) {
    if (l10n == null) {
      // If we don't have localization yet, we can't generate localized strings.
      // We'll wait for the UI to call with l10n or just update internal state without text.
      // But typically, we need l10n.
      // For now, we'll try to proceed or skip text update if l10n is missing.
      return; 
    }

    String defaultPaletteName = journalName.isNotEmpty 
        ? l10n.paletteOfJournalName(journalName) 
        : l10n.newPaletteDefaultName;

    // Reset selections if mode changes away from them (implied by setSourceType logic, but good to ensure)
    if (_creationMode != JournalCreationMode.fromPaletteModel) {
      _selectedPaletteModel = null;
    }
    if (_creationMode != JournalCreationMode.fromExistingJournal) {
      _selectedExistingJournal = null;
    }

    // Don't wipe color list if we are just typing title in empty mode
    // Only wipe/replace if we are switching sources or initialized
    
    // Logic from original file adapted:
    List<ColorData> newColors = [];
    String newPaletteName = _preparedPaletteName; // keep current by default

    switch (_creationMode) {
      case JournalCreationMode.fromPaletteModel:
        if (_availablePaletteModels.isNotEmpty) {
          _selectedPaletteModel ??= _availablePaletteModels.first;
          newPaletteName = journalName.isNotEmpty
              ? l10n.paletteFromModelName(journalName, _selectedPaletteModel!.name)
              : l10n.paletteFromModelNameNoJournal(_selectedPaletteModel!.name);
          newColors = _selectedPaletteModel!.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
        } else {
          // Fallback
          _selectedSourceType = PaletteSourceType.empty;
          _creationMode = JournalCreationMode.emptyPalette;
          // recursive call or fallthrough? Fallthrough to empty case logic below
          newPaletteName = defaultPaletteName;
          newColors = [];
        }
        break;
      case JournalCreationMode.fromExistingJournal:
        if (_availableUserJournals.isNotEmpty) {
          _selectedExistingJournal ??= _availableUserJournals.first;
          newPaletteName = journalName.isNotEmpty
              ? l10n.paletteCopiedFromName(journalName, _selectedExistingJournal!.name)
              : l10n.paletteCopiedFromNameNoJournal(_selectedExistingJournal!.name);
          newColors = _selectedExistingJournal!.palette.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
        } else {
           // Fallback
          _selectedSourceType = PaletteSourceType.empty;
          _creationMode = JournalCreationMode.emptyPalette;
          newPaletteName = defaultPaletteName;
          newColors = [];
        }
        break;
      case JournalCreationMode.emptyPalette:
        newPaletteName = defaultPaletteName;
        // In empty mode, we usually start empty. 
        // Note: The original code resets `_preparedColors = []` every time `_updatePaletteBasedOnMode` is called.
        // This means typing the journal name resets the colors if we are in empty mode? 
        // Let's check original logic: 
        // `_journalNameController.addListener(_updatePaletteNameOnJournalNameChange);` calls `_updatePaletteBasedOnMode`.
        // `case JournalCreationMode.emptyPalette: _preparedColors = [];` 
        // Yes, it seems typing the name wipes the colors in the original code! That seems like a bug or rigid design.
        // We will keep faithful to original behavior for now or improve it?
        // Let's improve it: don't wipe colors if we are just updating the name in empty mode.
        // But the original code explicitely did `_preparedColors = [];`. 
        // I will replicate original intent but maybe we should flag this. 
        // Actually, for "Empty Palette", maybe it's intended provided we haven't added colors yet.
        // But if user added 5 colors, then changed journal name, they lose colors? That's bad.
        // I will preserve `_preparedColors` if they are not empty in Empty Mode?
        // To be safe and stick to "refactor without feature change" I should stick to original behavior, 
        // BUT "improve code" allows fixing bad UX bugs. 
        // I'll stick to original logic: if we are in empty mode, it implies starting fresh. 
        // Actually, looking closely: `_preparedColors = []` is inside `case JournalCreationMode.emptyPalette`.
        // So yes, changing name resets colors. I will fix this improvement.
        if (_preparedColors.isEmpty) {
             newColors = []; 
        } else {
             newColors = _preparedColors; // Keep existing if user started editing
        }
        break;
    }
    
    _preparedColors = newColors;
    _preparedPaletteName = newPaletteName;
    _paletteEditorKey = UniqueKey(); // Force widget rebuild to reflect new initial values
    
    notifyListeners();
  }

  Future<Journal?> createJournal({
    required String journalName,
    required AppLocalizations l10n,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Validation Logic
      
      // Name existing check
      bool nameExists = await _firestoreService.checkJournalNameExists(journalName, _userId);
      if (nameExists) {
        _errorMessage = l10n.journalNameExistsSnackbar(journalName);
        return null;
      }

      // Palette size check
      if (_preparedColors.isEmpty) {
        _errorMessage = l10n.paletteMinColorError;
        return null;
      }
      if (_preparedColors.length < MIN_COLORS_IN_PALETTE_EDITOR) {
         _errorMessage = l10n.paletteMinColorsError(MIN_COLORS_IN_PALETTE_EDITOR);
         return null;
      }
      if (_preparedColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
        _errorMessage = l10n.paletteMaxColorsError(MAX_COLORS_IN_PALETTE_EDITOR);
        return null;
      }

      // 2. Construction
      final String finalPaletteName = _preparedPaletteName.isNotEmpty 
          ? _preparedPaletteName 
          : l10n.paletteOfJournalName(journalName);

      final Palette newPaletteInstance = Palette(
          id: _uuid.v4(),
          name: finalPaletteName,
          colors: _preparedColors, 
          isPredefined: false,
          userId: _userId
      );

      final Journal newJournal = Journal(
        id: _uuid.v4(),
        userId: _userId,
        name: journalName,
        palette: newPaletteInstance,
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );

      // 3. Execution
      await _firestoreService.createJournal(newJournal);
      _logger.i('Journal created: ${newJournal.name} with palette: ${newPaletteInstance.name}');
      
      return newJournal; // Return success

    } catch (e) {
      _logger.e('Error creating journal: ${e.toString()}');
      _errorMessage = l10n.entryPageGenericSaveError(e.toString());
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
