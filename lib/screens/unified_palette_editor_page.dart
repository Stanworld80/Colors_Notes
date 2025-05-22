import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../widgets/inline_palette_editor.dart';
import '../widgets/loading_indicator.dart';

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
/// A global Uuid instance for generating unique IDs.
const _uuid = Uuid();

/// A StatefulWidget screen for unified editing of a [Journal]'s [Palette] instance
/// or a [PaletteModel].
///
/// This page can operate in three modes:
/// 1. Editing the palette instance of an existing [Journal] (passed via [journalToUpdatePaletteFor]).
/// 2. Editing an existing [PaletteModel] (passed via [paletteModelToEdit]).
/// 3. Creating a new [PaletteModel] (if both constructor parameters are null).
///
/// It uses [InlinePaletteEditorWidget] for the actual palette manipulation and
/// implements an automatic save mechanism when changes are detected.
class UnifiedPaletteEditorPage extends StatefulWidget {
  /// The [Journal] whose palette instance is to be updated.
  /// If provided, the page edits this journal's specific palette.
  final Journal? journalToUpdatePaletteFor;

  /// The [PaletteModel] to be edited.
  /// If provided and [journalToUpdatePaletteFor] is null, the page edits this model.
  final PaletteModel? paletteModelToEdit;

  /// Creates an instance of [UnifiedPaletteEditorPage].
  ///
  /// At most one of [journalToUpdatePaletteFor] or [paletteModelToEdit] should be non-null
  /// to define the editing context. If both are null, the page defaults to creating a new [PaletteModel].
  const UnifiedPaletteEditorPage({
    super.key,
    this.journalToUpdatePaletteFor,
    this.paletteModelToEdit,
  });

  @override
  _UnifiedPaletteEditorPageState createState() => _UnifiedPaletteEditorPageState();
}

/// The state for the [UnifiedPaletteEditorPage].
///
/// Manages the palette's current name and colors, handles loading states,
/// determines the editing mode (journal palette vs. palette model),
/// and orchestrates the automatic saving of changes.
class _UnifiedPaletteEditorPageState extends State<UnifiedPaletteEditorPage> {
  /// Global key for the Form that wraps the [InlinePaletteEditorWidget],
  /// used for validating the palette name when it's editable.
  final _formKey = GlobalKey<FormState>();

  /// The current name of the palette or palette model being edited.
  late String _currentPaletteName;
  /// The current list of [ColorData] objects in the palette being edited.
  late List<ColorData> _currentColors;

  /// The initial name of the palette/model, used to detect changes for saving.
  late String _initialPaletteNameToCompare;
  /// The initial list of colors, used to detect changes for saving.
  late List<ColorData> _initialColorsToCompare;

  /// Flag to indicate if a save operation is currently in progress.
  bool _isLoading = false;
  /// The ID of the current authenticated user.
  String? _userId;
  /// `true` if editing a [PaletteModel] (either new or existing), `false` if editing a [Journal]'s palette instance.
  bool _isEditingModel = false;
  /// The title displayed in the AppBar, dynamically set based on the editing context.
  String _pageTitle = "";
  /// Flag to track if any changes have been made since the last successful save.
  /// This helps trigger saves even if the user reverts to the initial state after making a change.
  bool _hasMadeChangesSinceLastSave = false;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    // Page title will be set in didChangeDependencies or build, as l10n is not available yet.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;

    // Initialize states that depend on l10n or widget properties
    if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false;
      final palette = widget.journalToUpdatePaletteFor!.palette;
      _currentPaletteName = palette.name;
      _currentColors = palette.colors.map((c) => c.copyWith()).toList();
      _pageTitle = l10n.pageTitlePalettePrefix + widget.journalToUpdatePaletteFor!.name;
    } else if (widget.paletteModelToEdit != null) {
      _isEditingModel = true;
      final model = widget.paletteModelToEdit!;
      _currentPaletteName = model.name;
      _currentColors = model.colors.map((c) => c.copyWith()).toList();
      _pageTitle = l10n.pageTitleModelPrefix + model.name;
    } else {
      _isEditingModel = true;
      _currentPaletteName = l10n.newPaletteDefaultName; // Default name for a new model
      _currentColors = [];
      _pageTitle = l10n.pageTitleNewPaletteModel;
      _hasMadeChangesSinceLastSave = true;
    }
    _initialPaletteNameToCompare = _currentPaletteName;
    _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
  }

  /// Checks if there are actual differences between the current palette state
  /// and its state at the last save.
  ///
  /// Compares name, number of colors, and individual color properties (ID, title, hexCode).
  /// Returns `true` if changes are detected, `false` otherwise.
  bool _checkForActualChanges() {
    if (_currentPaletteName != _initialPaletteNameToCompare) return true;
    if (_currentColors.length != _initialColorsToCompare.length) return true;
    for (int i = 0; i < _currentColors.length; i++) {
      // Compare relevant properties of ColorData
      if (_currentColors[i].paletteElementId != _initialColorsToCompare[i].paletteElementId ||
          _currentColors[i].title != _initialColorsToCompare[i].title ||
          _currentColors[i].hexCode != _initialColorsToCompare[i].hexCode) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a specific color element from a journal's palette can be deleted.
  ///
  /// A color cannot be deleted if it's currently used by any [Note] within the journal.
  /// This check is only relevant when editing a journal's palette instance.
  /// [paletteElementId] The ID of the [ColorData] to check.
  /// Returns `true` if the color can be deleted, `false` otherwise or on error.
  Future<bool> _canDeleteColor(String paletteElementId) async {
    if (widget.journalToUpdatePaletteFor == null || _userId == null) {
      // This should only be called when editing a journal palette.
      // As a safeguard, allow deletion if context is unexpected or not applicable.
      _loggerPage.w("_canDeleteColor called in unexpected context or with null userId/journal."); // Log in English
      return true;
    }
    final l10n = AppLocalizations.of(context)!;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    if (mounted) setState(() { _isLoading = true; });
    try {
      final isUsed = await firestoreService.isPaletteElementUsedInNotes(
        widget.journalToUpdatePaletteFor!.id,
        paletteElementId,
      );
      return !isUsed;
    } catch (e) {
      _loggerPage.e("Error checking color usage: $e"); // Log in English
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorCheckingColorUsageSnackbar(e.toString())), backgroundColor: Colors.red),
        );
      }
      return false; // Disallow deletion on error to be safe
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Triggers an automatic save of the palette if changes are detected.
  ///
  /// This method is typically called by the [InlinePaletteEditorWidget] when
  /// the user interacts with the palette (e.g., adds/removes/edits a color, or changes name).
  /// It validates the palette name (if applicable) and color counts, then proceeds
  /// to either create/update a [PaletteModel] or update a [Journal]'s palette instance.
  Future<void> _triggerAutomaticSave() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_checkForActualChanges() && !_hasMadeChangesSinceLastSave) {
      _loggerPage.i("No real changes detected, automatic save cancelled."); // Log in English
      return;
    }

    // Validate the form, which includes the palette name editor if visible (i.e., when _isEditingModel is true)
    if (_formKey.currentState?.validate() == false) {
      _loggerPage.w("Form validation (palette name) failed during auto-save."); // Log in English
      _hasMadeChangesSinceLastSave = true; // Keep flag true if validation fails, to retry save later
      return;
    }

    // Validate color counts (constants like MIN_COLORS_IN_PALETTE_EDITOR are from InlinePaletteEditorWidget or its imports)
    if (_currentColors.length < MIN_COLORS_IN_PALETTE_EDITOR && _isEditingModel) { // Min colors check only for models
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.modelMinColorsErrorSnackbar(MIN_COLORS_IN_PALETTE_EDITOR)), backgroundColor: Colors.orange));
      _hasMadeChangesSinceLastSave = true;
      return;
    }
    if (_currentColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paletteMaxColorsErrorSnackbar(MAX_COLORS_IN_PALETTE_EDITOR)), backgroundColor: Colors.orange));
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userNotIdentifiedSnackbar), backgroundColor: Colors.red));
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (mounted) setState(() { _isLoading = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    bool saveSucceeded = false;
    PaletteModel? createdModel; // To hold the newly created model if applicable

    try {
      // If editing a journal's palette, check if any deleted colors were in use.
      if (widget.journalToUpdatePaletteFor != null && !_isEditingModel) {
        List<String> attemptedDeletionsFailedTitles = [];
        for (var initialColor in _initialColorsToCompare) {
          if (!_currentColors.any((currentColor) => currentColor.paletteElementId == initialColor.paletteElementId)) {
            final bool canActuallyDelete = await _canDeleteColor(initialColor.paletteElementId);
            if (!canActuallyDelete) {
              attemptedDeletionsFailedTitles.add(initialColor.title);
            }
          }
        }
        if (attemptedDeletionsFailedTitles.isNotEmpty) {
          throw Exception(l10n.saveBlockedColorInUseError(attemptedDeletionsFailedTitles.join(', ')));
        }
      }

      if (_isEditingModel) { // Creating or Editing a PaletteModel
        if (widget.paletteModelToEdit == null) { // Creating a new model
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!);
          if (nameExists) throw Exception(l10n.paletteModelNameExistsError);

          createdModel = PaletteModel(
            id: _uuid.v4(),
            name: _currentPaletteName,
            colors: _currentColors,
            userId: _userId!,
            isPredefined: false,
          );
          await firestoreService.createPaletteModel(createdModel);
          _loggerPage.i("New palette model created: ${createdModel.name}"); // Log in English
          if (mounted && _pageTitle == l10n.pageTitleNewPaletteModel) {
            setState(() {
              _pageTitle = l10n.pageTitleModelPrefix + createdModel!.name;
            });
          }
        } else { // Editing an existing model
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!, excludeId: widget.paletteModelToEdit!.id);
          if (nameExists) throw Exception(l10n.paletteModelNameExistsError);

          final updatedModel = widget.paletteModelToEdit!.copyWith(
            name: _currentPaletteName,
            colors: _currentColors,
          );
          await firestoreService.updatePaletteModel(updatedModel);
          _loggerPage.i("Palette model updated: ${updatedModel.name}"); // Log in English
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paletteModelSavedSnackbar), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        saveSucceeded = true;

      } else if (widget.journalToUpdatePaletteFor != null) { // Editing a Journal's Palette Instance
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(
          name: _currentPaletteName,
          colors: _currentColors,
        );
        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Journal palette ${currentJournal.name} updated."); // Log in English

        final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
        if (activeJournalNotifier.activeJournalId == currentJournal.id) {
          await activeJournalNotifier.setActiveJournal(currentJournal.id, _userId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.journalPaletteSavedSnackbar), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        saveSucceeded = true;
      }

      if (saveSucceeded) {
        if (mounted) {
          setState(() {
            _hasMadeChangesSinceLastSave = false;
            // Update initial state to reflect the successful save
            _initialPaletteNameToCompare = _currentPaletteName;
            _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
            // If a new model was just created, this conceptually "transitions" the page
            // from "creating new" to "editing existing" for the purpose of change detection.
            // The actual widget.paletteModelToEdit remains null, but the _initial* states are updated.
          });
        }
      } else {
        _hasMadeChangesSinceLastSave = true; // If save didn't happen for some reason, ensure flag is true
      }

    } catch (e) {
      _loggerPage.e("Error saving palette: $e"); // Log in English
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorSavingPaletteSnackbar(e.toString())), backgroundColor: Colors.red));
      _hasMadeChangesSinceLastSave = true; // Mark changes as pending if save failed
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }


  Future<bool> _handleDeleteAllColorsRequested() async {
    final l10n = AppLocalizations.of(context)!;
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userNotIdentifiedSnackbar)));
      return false;
    }

    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteAllColorsDialogTitle),
          content: Text(
            !_isEditingModel && widget.journalToUpdatePaletteFor != null
                ? l10n.deleteAllColorsJournalWarning(widget.journalToUpdatePaletteFor!.name)
                : l10n.deleteAllColorsModelWarning,
          ),
          actions: <Widget>[
            TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.deleteAllButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (firstConfirm != true) return false;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(!_isEditingModel ? l10n.finalDeleteAllConfirmationDialogTitle : l10n.confirmDeletionDialogTitle),
          content: Text(
            !_isEditingModel
                ? l10n.finalDeleteAllConfirmationJournalWarning
                : l10n.finalDeleteAllConfirmationModelWarning,
          ),
          actions: <Widget>[
            TextButton(child: Text(l10n.noCancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(l10n.yesDeleteAllButtonLabel),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (secondConfirm != true) return false;

    if (mounted)
      setState(() {
        _isLoading = true;
      });
    try {
      if (!_isEditingModel && widget.journalToUpdatePaletteFor != null) {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        await firestoreService.deleteAllNotesInJournal(widget.journalToUpdatePaletteFor!.id, _userId!);
        _loggerPage.i("All notes in journal ${widget.journalToUpdatePaletteFor!.id} were deleted before emptying the palette."); // Log in English
      }
      return true;
    } catch (e) {
      _loggerPage.e("Error deleting all colors/notes: $e"); // Log in English
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.genericErrorSnackbar(e.toString())), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }
  /// Handles the `onWillPop` event to prevent navigation while saving.
  ///
  /// Returns `false` to block navigation if [_isLoading] is true, otherwise `true`.
  Future<bool> _onWillPop() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savingInProgressSnackbar), duration: const Duration(seconds: 1)),
      );
      return false; // Prevent popping
    }
    return true; // Allow popping
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
          actions: [
            // Show a small loading indicator in the AppBar if saving
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0), // Adjust padding as needed
                child: SizedBox(
                    width: 20, height: 20, // Adjust size as needed
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
                ),
              )
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form( // Form to enable validation of palette name if shown
                key: _formKey,
                child: InlinePaletteEditorWidget(
                  // Use a ValueKey to ensure the editor widget rebuilds if the entity being edited changes.
                  // This is important if navigating directly between editing different palettes/models.
                  key: ValueKey(widget.journalToUpdatePaletteFor?.id ?? widget.paletteModelToEdit?.id ?? 'new_palette_editor_autosave_instance'),
                  initialPaletteName: _currentPaletteName,
                  initialColors: _currentColors,
                  isEditingJournalPalette: !_isEditingModel, // True if editing a journal's palette, false for models
                  canDeleteColorCallback: !_isEditingModel ? _canDeleteColor : null, // Only for journal palettes
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
                    // Check for actual changes before setting state to avoid unnecessary rebuilds/saves
                    // This basic check might not be sufficient if order matters and IDs are stable.
                    // The _checkForActualChanges method is more robust for save decisions.
                    if (mounted) {
                      setState(() {
                        _currentColors = newColors;
                        _hasMadeChangesSinceLastSave = true;
                      });
                    }
                  },
                  onPaletteNeedsSave: _triggerAutomaticSave, // Callback for automatic saving
                  showNameEditor: _isEditingModel, // Show name editor only when editing/creating a PaletteModel
                  onDeleteAllColorsRequested: _handleDeleteAllColorsRequested,
                ),
              ),
            ),
            // Full-screen loading indicator if _isLoading is true
            if (_isLoading) const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
