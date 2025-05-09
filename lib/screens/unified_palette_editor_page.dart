// lib/screens/unified_palette_editor_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../widgets/inline_palette_editor.dart';
import '../widgets/loading_indicator.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
const _uuid = Uuid();

// Constants for palette editor defined in inline_palette_editor.dart
// const int MIN_COLORS_IN_PALETTE_EDITOR = 1;
// const int MAX_COLORS_IN_PALETTE_EDITOR = 48;

class UnifiedPaletteEditorPage extends StatefulWidget {
  final Journal? journalToUpdatePaletteFor;
  final PaletteModel? paletteModelToEdit;

  const UnifiedPaletteEditorPage({
    Key? key,
    this.journalToUpdatePaletteFor,
    this.paletteModelToEdit,
  }) : super(key: key);

  @override
  _UnifiedPaletteEditorPageState createState() => _UnifiedPaletteEditorPageState();
}

class _UnifiedPaletteEditorPageState extends State<UnifiedPaletteEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late String _currentPaletteName;
  late List<ColorData> _currentColors;

  // Store initial state for comparison to detect actual changes
  late String _initialPaletteNameToCompare;
  late List<ColorData> _initialColorsToCompare;

  bool _isLoading = false;
  String? _userId;
  bool _isEditingModel = false;
  String _pageTitle = "";
  bool _hasMadeChangesSinceLastSave = false; // Tracks if changes occurred since the last successful save

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false;
      final palette = widget.journalToUpdatePaletteFor!.palette;
      _currentPaletteName = palette.name;
      _currentColors = palette.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Palette: ${widget.journalToUpdatePaletteFor!.name}";
    } else if (widget.paletteModelToEdit != null) {
      _isEditingModel = true;
      final model = widget.paletteModelToEdit!;
      _currentPaletteName = model.name;
      _currentColors = model.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Modèle: ${model.name}";
    } else {
      _isEditingModel = true;
      _currentPaletteName = "Nouvelle Palette"; // Default name for new model
      _currentColors = [];
      _pageTitle = "Nouveau Modèle de Palette";
      _hasMadeChangesSinceLastSave = true; // New model implies changes to be saved
    }
    // Initialize comparison states
    _initialPaletteNameToCompare = _currentPaletteName;
    _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
  }

  /// Checks if there are actual differences between current and last saved state.
  bool _checkForActualChanges() {
    if (_currentPaletteName != _initialPaletteNameToCompare) {
      return true;
    }
    if (_currentColors.length != _initialColorsToCompare.length) {
      return true;
    }
    for (int i = 0; i < _currentColors.length; i++) {
      if (_currentColors[i].paletteElementId != _initialColorsToCompare[i].paletteElementId ||
          _currentColors[i].title != _initialColorsToCompare[i].title ||
          _currentColors[i].hexCode != _initialColorsToCompare[i].hexCode) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _canDeleteColor(String paletteElementId) async {
    if (widget.journalToUpdatePaletteFor == null || _userId == null) {
      return true;
    }
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    try {
      final isUsed = await firestoreService.isPaletteElementUsedInNotes(
        widget.journalToUpdatePaletteFor!.id,
        paletteElementId,
      );
      return !isUsed;
    } catch (e) {
      _loggerPage.e("Erreur vérification utilisation couleur: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vérification utilisation couleur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Triggers an automatic save if actual changes are detected.
  Future<void> _triggerAutomaticSave() async {
    if (!_checkForActualChanges() && !_hasMadeChangesSinceLastSave) { // Also check _hasMadeChangesSinceLastSave for new models
      _loggerPage.i("Aucun changement réel détecté, sauvegarde automatique annulée.");
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _loggerPage.w("Validation du formulaire (nom palette) échouée lors de la sauvegarde auto.");
      _hasMadeChangesSinceLastSave = true; // Mark as dirty if validation fails
      return;
    }

    if (_currentColors.length < MIN_COLORS_IN_PALETTE_EDITOR && _isEditingModel) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle doit avoir au moins $MIN_COLORS_IN_PALETTE_EDITOR couleurs."), backgroundColor: Colors.orange));
      _hasMadeChangesSinceLastSave = true;
      return;
    }
    if (_currentColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Une palette ne peut pas avoir plus de $MAX_COLORS_IN_PALETTE_EDITOR couleurs."), backgroundColor: Colors.orange));
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié."), backgroundColor: Colors.red));
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (mounted) setState(() { _isLoading = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    bool saveSucceeded = false;

    try {
      if (widget.journalToUpdatePaletteFor != null) {
        List<String> attemptedDeletionsFailed = [];
        // Compare _currentColors with _initialColorsToCompare to find deleted colors
        for (var initialColor in _initialColorsToCompare) {
          if (!_currentColors.any((currentColor) => currentColor.paletteElementId == initialColor.paletteElementId)) {
            final bool canActuallyDelete = await _canDeleteColor(initialColor.paletteElementId);
            if (!canActuallyDelete) {
              attemptedDeletionsFailed.add(initialColor.title);
            }
          }
        }
        if (attemptedDeletionsFailed.isNotEmpty) {
          throw Exception("Sauvegarde bloquée : La/les couleur(s) '${attemptedDeletionsFailed.join(', ')}' est/sont utilisée(s) et ne peuvent être supprimées.");
        }
      }

      if (_isEditingModel) {
        if (widget.paletteModelToEdit == null) {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!);
          if (nameExists) throw Exception("Un modèle de palette avec ce nom existe déjà.");

          final newModel = PaletteModel(
            id: _uuid.v4(),
            name: _currentPaletteName,
            colors: _currentColors,
            userId: _userId!,
            isPredefined: false,
          );
          await firestoreService.createPaletteModel(newModel);
          _loggerPage.i("Nouveau modèle de palette créé: ${newModel.name}");
          // If it's a new model, we might need to update widget.paletteModelToEdit if the page stays open
          // For now, we assume navigation or state management handles this.
          // Or, more simply, update the _pageTitle if it was "Nouveau Modèle de Palette"
          if (mounted && _pageTitle == "Nouveau Modèle de Palette") {
            setState(() {
              _pageTitle = "Modèle: ${newModel.name}";
              // Potentially update widget.paletteModelToEdit if the instance is passed around,
              // but this page doesn't directly modify its own widget parameters.
            });
          }
        } else {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!, excludeId: widget.paletteModelToEdit!.id);
          if (nameExists) throw Exception("Un autre modèle de palette avec ce nom existe déjà.");

          final updatedModel = widget.paletteModelToEdit!.copyWith(
            name: _currentPaletteName,
            colors: _currentColors,
          );
          await firestoreService.updatePaletteModel(updatedModel);
          _loggerPage.i("Modèle de palette mis à jour: ${updatedModel.name}");
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modèle de palette sauvegardé."), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        saveSucceeded = true;

      } else if (widget.journalToUpdatePaletteFor != null) {
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(
          name: _currentPaletteName,
          colors: _currentColors,
        );
        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

        // ignore: use_build_context_synchronously
        final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
        if (activeJournalNotifier.activeJournalId == currentJournal.id) {
          await activeJournalNotifier.setActiveJournal(currentJournal.id, _userId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Palette du journal sauvegardée."), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        saveSucceeded = true;
      }

      if (saveSucceeded) {
        if (mounted) {
          setState(() {
            _hasMadeChangesSinceLastSave = false;
            _initialPaletteNameToCompare = _currentPaletteName; // Update comparison baseline
            _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
          });
        }
      } else {
        _hasMadeChangesSinceLastSave = true;
      }

    } catch (e) {
      _loggerPage.e("Erreur sauvegarde palette: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur de sauvegarde: ${e.toString()}"), backgroundColor: Colors.red));
      _hasMadeChangesSinceLastSave = true;
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Handles the back button press.
  /// Allows popping if no save operation is in progress.
  Future<bool> _onWillPop() async {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sauvegarde en cours, veuillez patienter..."), duration: Duration(seconds: 1)),
      );
      return false; // Prevent popping if loading
    }
    // If there were changes that failed to save, _hasMadeChangesSinceLastSave would be true.
    // The user has already been notified of the error. Allow exit.
    return true;
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
          // actions list is now empty as the save button is removed
          actions: [
            if (_isLoading) // Still show loading indicator in AppBar if a save is in progress
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
                ),
              )
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: InlinePaletteEditorWidget(
                  // Use a key that changes if the source (journal/model) changes, to force re-init
                  key: ValueKey(widget.journalToUpdatePaletteFor?.id ?? widget.paletteModelToEdit?.id ?? 'new_palette_editor_autosave_instance'),
                  initialPaletteName: _currentPaletteName,
                  initialColors: _currentColors,
                  isEditingJournalPalette: widget.journalToUpdatePaletteFor != null,
                  canDeleteColorCallback: widget.journalToUpdatePaletteFor != null ? _canDeleteColor : null,
                  onPaletteNameChanged: (newName) {
                    if (_currentPaletteName != newName) { // Check if name actually changed
                      if (mounted) {
                        setState(() {
                          _currentPaletteName = newName;
                          _hasMadeChangesSinceLastSave = true; // Mark dirty
                        });
                      }
                    }
                  },
                  onColorsChanged: (newColors) {
                    // A more robust list comparison might be needed if ColorData objects are mutated directly
                    // For now, assume newColors is a new list or its content differs significantly
                    if (mounted) {
                      setState(() {
                        _currentColors = newColors;
                        _hasMadeChangesSinceLastSave = true; // Mark dirty
                      });
                    }
                  },
                  onPaletteNeedsSave: _triggerAutomaticSave, // Pass the automatic save trigger
                ),
              ),
            ),
            if (_isLoading) const LoadingIndicator(), // Full screen loading indicator
          ],
        ),
      ),
    );
  }
}
