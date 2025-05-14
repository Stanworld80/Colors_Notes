
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
  final _formKey = GlobalKey<FormState>(); // Clé pour le Form qui contient InlinePaletteEditorWidget

  late String _currentPaletteName;
  late List<ColorData> _currentColors;

  late String _initialPaletteNameToCompare;
  late List<ColorData> _initialColorsToCompare;

  bool _isLoading = false;
  String? _userId;
  bool _isEditingModel = false; // True if editing/creating a PaletteModel
  String _pageTitle = "";
  bool _hasMadeChangesSinceLastSave = false;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false; // Editing a journal's palette instance
      final palette = widget.journalToUpdatePaletteFor!.palette;
      _currentPaletteName = palette.name;
      _currentColors = palette.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Palette: ${widget.journalToUpdatePaletteFor!.name}";
    } else if (widget.paletteModelToEdit != null) {
      _isEditingModel = true; // Editing an existing PaletteModel
      final model = widget.paletteModelToEdit!;
      _currentPaletteName = model.name;
      _currentColors = model.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Modèle: ${model.name}";
    } else {
      _isEditingModel = true; // Creating a new PaletteModel
      _currentPaletteName = "Nouveau Modèle de Palette";
      _currentColors = [];
      _pageTitle = "Nouveau Modèle de Palette";
      _hasMadeChangesSinceLastSave = true;
    }
    _initialPaletteNameToCompare = _currentPaletteName;
    _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
  }

  bool _checkForActualChanges() {
    if (_currentPaletteName != _initialPaletteNameToCompare) return true;
    if (_currentColors.length != _initialColorsToCompare.length) return true;
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
      // This should only be called when editing a journal palette,
      // but as a safeguard, allow deletion if context is unexpected.
      return true;
    }
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    if (mounted) setState(() { _isLoading = true; });
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
      return false; // Disallow deletion on error
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _triggerAutomaticSave() async {
    if (!_checkForActualChanges() && !_hasMadeChangesSinceLastSave) {
      _loggerPage.i("Aucun changement réel détecté, sauvegarde automatique annulée.");
      return;
    }

    // Validate the form which now contains the InlinePaletteEditorWidget's name field (if visible)
    if (_formKey.currentState?.validate() == false) { // Use ?. to safely access validate
      _loggerPage.w("Validation du formulaire (nom palette) échouée lors de la sauvegarde auto.");
      _hasMadeChangesSinceLastSave = true;
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
    PaletteModel? createdModel; // To hold the newly created model

    try {
      if (widget.journalToUpdatePaletteFor != null && !_isEditingModel) { // Editing journal instance palette
        List<String> attemptedDeletionsFailed = [];
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

      if (_isEditingModel) { // Creating or Editing a PaletteModel
        if (widget.paletteModelToEdit == null) { // Creating new model
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!);
          if (nameExists) throw Exception("Un modèle de palette avec ce nom existe déjà.");

          createdModel = PaletteModel( // Assign to createdModel
            id: _uuid.v4(),
            name: _currentPaletteName,
            colors: _currentColors,
            userId: _userId!,
            isPredefined: false,
          );
          await firestoreService.createPaletteModel(createdModel);
          _loggerPage.i("Nouveau modèle de palette créé: ${createdModel.name}");
          if (mounted && _pageTitle == "Nouveau Modèle de Palette") {
            setState(() {
              _pageTitle = "Modèle: ${createdModel!.name}"; // Use createdModel here
              // This is tricky: widget.paletteModelToEdit is final.
              // We can't update it directly. The page might need to be re-pushed or state managed differently
              // if we want to transition from "new" to "editing existing" without leaving the page.
              // For now, the title updates, and subsequent saves would be "updates" if we could set paletteModelToEdit.
              // A simple solution is that after a successful first save of a new model,
              // _initialPaletteNameToCompare and _initialColorsToCompare are updated,
              // and _hasMadeChangesSinceLastSave is set to false.
              // The widget.paletteModelToEdit effectively becomes this new model conceptually for this page instance.
            });
          }
        } else { // Editing existing model
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

      } else if (widget.journalToUpdatePaletteFor != null) { // Editing Journal's Palette Instance
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(
          name: _currentPaletteName, // Name comes from _currentPaletteName, which is managed by InlinePaletteEditor
          colors: _currentColors,
        );
        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

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
            _initialPaletteNameToCompare = _currentPaletteName;
            _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
            // If a new model was just created, update the reference for future saves on this page instance
            // This is a conceptual update, as widget.paletteModelToEdit is final.
            // This logic is more for _hasMadeChangesSinceLastSave and _checkForActualChanges.
            if (widget.paletteModelToEdit == null && createdModel != null) {
              // Conceptually, we are now "editing" the model that was just created.
              // This helps _checkForActualChanges and _initial states.
            }

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

  Future<bool> _onWillPop() async {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sauvegarde en cours, veuillez patienter..."), duration: Duration(seconds: 1)),
      );
      return false;
    }
    return true;
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
          actions: [
            if (_isLoading)
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
              child: Form( // Wrap InlinePaletteEditorWidget with a Form
                key: _formKey,
                child: InlinePaletteEditorWidget(
                  key: ValueKey(widget.journalToUpdatePaletteFor?.id ?? widget.paletteModelToEdit?.id ?? 'new_palette_editor_autosave_instance'),
                  initialPaletteName: _currentPaletteName,
                  initialColors: _currentColors,
                  isEditingJournalPalette: !_isEditingModel, // True if editing journal's palette
                  canDeleteColorCallback: !_isEditingModel ? _canDeleteColor : null,
                  onPaletteNameChanged: (newName) {
                    if (_currentPaletteName != newName) {
                      if (mounted) {
                        setState(() {
                          _currentPaletteName = newName;
                          _hasMadeChangesSinceLastSave = true;
                        });
                      }
                    }
                  },
                  onColorsChanged: (newColors) {
                    if (mounted) {
                      setState(() {
                        _currentColors = newColors;
                        _hasMadeChangesSinceLastSave = true;
                      });
                    }
                  },
                  onPaletteNeedsSave: _triggerAutomaticSave,
                  showNameEditor: _isEditingModel, // <<< ICI LA MODIFICATION IMPORTANTE
                ),
              ),
            ),
            if (_isLoading) const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
