import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/color_data.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/inline_palette_editor.dart';
import '../core/predefined_templates.dart';

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
/// A global Uuid instance for generating unique IDs.
const _uuid = Uuid();

/// Defines the different ways a new journal's palette can be initialized.
enum JournalCreationMode {
  /// The journal will start with an empty palette, to be composed by the user.
  emptyPalette,
  /// The journal's palette will be based on a selected [PaletteModel].
  fromPaletteModel,
  /// The journal's palette will be a copy of an existing journal's palette.
  fromExistingJournal
}

/// Defines the source type for the palette being configured.
enum PaletteSourceType {
  /// Palette is created from scratch.
  empty,
  /// Palette is based on a [PaletteModel].
  model,
  /// Palette is copied from an existing [Journal].
  existingJournal
}

/// A StatefulWidget screen for creating a new journal.
///
/// This page allows users to name their new journal and configure its initial
/// color palette. The palette can be created from scratch, based on a predefined
/// or user-created [PaletteModel], or by copying the palette from an existing journal.
class CreateJournalPage extends StatefulWidget {
  /// Creates an instance of [CreateJournalPage].
  const CreateJournalPage({super.key});

  @override
  _CreateJournalPageState createState() => _CreateJournalPageState();
}

/// The state for the [CreateJournalPage].
///
/// Manages the form input, selected creation mode, palette configuration,
/// and the overall process of creating a new journal.
class _CreateJournalPageState extends State<CreateJournalPage> {
  /// Global key for the form to manage validation and state.
  final _formKey = GlobalKey<FormState>();
  /// Controller for the journal name input field.
  final _journalNameController = TextEditingController();

  /// The current mode for creating the journal's palette.
  JournalCreationMode _creationMode = JournalCreationMode.emptyPalette;
  /// The selected source type for the palette (empty, model, or existing journal).
  PaletteSourceType _selectedSourceType = PaletteSourceType.empty;

  /// The currently selected [PaletteModel] if [_creationMode] is [JournalCreationMode.fromPaletteModel].
  PaletteModel? _selectedPaletteModel;
  /// List of available palette models (predefined and user-created).
  List<PaletteModel> _availablePaletteModels = [];

  /// The currently selected existing [Journal] to copy the palette from.
  Journal? _selectedExistingJournal;
  /// List of the current user's existing journals.
  List<Journal> _availableUserJournals = [];

  /// The list of [ColorData] that will form the new journal's palette.
  List<ColorData> _preparedColors = [];
  /// The name for the new journal's palette.
  String _preparedPaletteName = "";

  /// A key for the [InlinePaletteEditorWidget] to force re-initialization when palette source changes.
  Key _paletteEditorKey = UniqueKey();

  /// Flag to indicate if data is currently being loaded.
  bool _isLoading = true;
  /// The ID of the current authenticated user.
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    _journalNameController.addListener(_updatePaletteNameOnJournalNameChange);
    _loadInitialData();
  }

  /// Updates the prepared palette name when the journal name changes.
  ///
  /// This ensures the palette name suggestion reflects the current journal name,
  /// especially for empty palettes or when deriving from models/existing journals.
  void _updatePaletteNameOnJournalNameChange() {
    if (mounted) {
      setState(() {
        _updatePaletteBasedOnMode();
      });
    }
  }

  /// Loads initial data required for the page.
  ///
  /// Fetches available palette models (predefined and user-specific) and
  /// existing user journals to populate selection options.
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    if (!mounted) return;
    // It's safer to get l10n here if needed for initial error messages,
    // or pass it down if _loadInitialData itself might show UI before build context is fully available for it.
    // For now, assuming l10n will be available in build or passed to methods that show UI.
    setState(() {
      _isLoading = true;
    });

    if (_userId == null) {
      if (mounted) {
        // Assuming l10n is accessible here or using a predefined error string if not.
        // For simplicity, direct string usage here, will be replaced by l10n in build context dependent parts.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: User not identified."))); // Placeholder, to be localized
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final FirestoreService firestoreService = Provider.of<FirestoreService>(context, listen: false);

      final List<PaletteModel> predefinedPalettesList = predefinedPalettes;
      final List<PaletteModel> userModels = await firestoreService.getUserPaletteModelsStream(_userId!).first;
      _availablePaletteModels = [...predefinedPalettesList, ...userModels];
      _availableUserJournals = await firestoreService.getJournalsStream(_userId!).first;

      // Initial call to _updatePaletteBasedOnMode might need l10n if it sets text directly
      // For now, assuming it prepares data and text is set in build or later method calls with context
      _updatePaletteBasedOnMode();
    } catch (e) {
      _loggerPage.e("Error loading initial data: $e"); // Placeholder
      if (mounted) {
        // Placeholder, to be localized
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading options: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Updates the [_preparedColors] and [_preparedPaletteName] based on the current [_creationMode].
  ///
  /// This method is called when the creation mode changes or when initial data is loaded.
  /// It sets up the palette editor with the appropriate colors and name.
  void _updatePaletteBasedOnMode([AppLocalizations? l10nInstance]) {
    final l10n = l10nInstance ?? AppLocalizations.of(context)!;
    final journalName = _journalNameController.text.trim();
    String defaultPaletteName = journalName.isNotEmpty ? l10n.paletteOfJournalName(journalName) : l10n.newPaletteDefaultName;

    // Reset selections if mode changes away from them
    if (_creationMode != JournalCreationMode.fromPaletteModel) {
      _selectedPaletteModel = null;
    }
    if (_creationMode != JournalCreationMode.fromExistingJournal) {
      _selectedExistingJournal = null;
    }

    _preparedColors = []; // Reset prepared colors

    switch (_creationMode) {
      case JournalCreationMode.fromPaletteModel:
        if (_availablePaletteModels.isNotEmpty) {
          _selectedPaletteModel ??= _availablePaletteModels.first; // Default to first model if none selected
          _preparedPaletteName = journalName.isNotEmpty
              ? l10n.paletteFromModelName(journalName, _selectedPaletteModel!.name)
              : l10n.paletteFromModelNameNoJournal(_selectedPaletteModel!.name);
          _preparedColors = _selectedPaletteModel!.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
        } else {
          // If no models available, switch to empty palette mode
          _selectedSourceType = PaletteSourceType.empty;
          _creationMode = JournalCreationMode.emptyPalette;
          _updatePaletteBasedOnMode(l10n); // Recurse to update based on new mode
          return;
        }
        break;
      case JournalCreationMode.fromExistingJournal:
        if (_availableUserJournals.isNotEmpty) {
          _selectedExistingJournal ??= _availableUserJournals.first; // Default to first journal
          _preparedPaletteName = journalName.isNotEmpty
              ? l10n.paletteCopiedFromName(journalName, _selectedExistingJournal!.name)
              : l10n.paletteCopiedFromNameNoJournal(_selectedExistingJournal!.name);
          _preparedColors = _selectedExistingJournal!.palette.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
        } else {
          // If no journals available to copy, switch to empty palette mode
          _selectedSourceType = PaletteSourceType.empty;
          _creationMode = JournalCreationMode.emptyPalette;
          _updatePaletteBasedOnMode(l10n); // Recurse to update based on new mode
          return;
        }
        break;
      case JournalCreationMode.emptyPalette:
        _preparedPaletteName = defaultPaletteName;
        _preparedColors = []; // Start with an empty list for the user to add colors
        break;
    }
    _paletteEditorKey = UniqueKey(); // Re-key the editor to force rebuild with new initial values
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _journalNameController.removeListener(_updatePaletteNameOnJournalNameChange);
    _journalNameController.dispose();
    super.dispose();
  }

  /// Handles the request to delete all colors from the palette being created.
  ///
  /// Shows a confirmation dialog to the user.
  /// Returns `true` if the user confirms deletion, `false` otherwise.
  Future<bool> _handleDeleteAllColorsInCreation() async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.emptyPaletteDialogTitle),
          content: Text(l10n.emptyPaletteDialogContent),
          actions: <Widget>[
            TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.emptyButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  /// Creates the new journal with the specified name and prepared palette.
  ///
  /// Validates the form, checks for duplicate journal names, and ensures the palette
  /// meets size constraints. On success, it saves the journal to Firestore,
  /// sets it as the active journal, and navigates back.
  Future<void> _createJournal() async {
    final l10n = AppLocalizations.of(context)!;
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userNotIdentifiedSnackbar)));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final String journalName = _journalNameController.text.trim();
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    // Check if a journal with the same name already exists for this user.
    bool nameExists = await firestoreService.checkJournalNameExists(journalName, _userId!);
    if (nameExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.journalNameExistsSnackbar(journalName)), backgroundColor: Colors.orange));
      }
      return;
    }

    // Validate palette color count
    if (_preparedColors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paletteMinColorError)));
      }
      return;
    }

    if (_preparedColors.length < MIN_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paletteMinColorsError(MIN_COLORS_IN_PALETTE_EDITOR))));
      }
      return;
    }
    if (_preparedColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.paletteMaxColorsError(MAX_COLORS_IN_PALETTE_EDITOR))));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
      final String finalPaletteName = _preparedPaletteName.isNotEmpty ? _preparedPaletteName : l10n.paletteOfJournalName(journalName);

      final Palette newPaletteInstance = Palette(
          id: _uuid.v4(), // Generate new ID for the palette instance
          name: finalPaletteName,
          colors: _preparedColors, // These colors already have new paletteElementIds from _updatePaletteBasedOnMode
          isPredefined: false,
          userId: _userId // Associate user with this palette instance
      );

      final Journal newJournal = Journal(
        id: _uuid.v4(), // Generate new ID for the journal
        userId: _userId!,
        name: journalName,
        palette: newPaletteInstance, // Embed the newly created palette instance
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );

      await firestoreService.createJournal(newJournal);
      _loggerPage.i('Journal created: ${newJournal.name} with palette: ${newPaletteInstance.name}');

      // Set the newly created journal as active
      await activeJournalNotifier.setActiveJournal(newJournal.id, _userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.journalCreatedSuccess(newJournal.name))));
        Navigator.of(context).pop(); // Go back to the previous screen
      }
    } catch (e) {
      _loggerPage.e('Error creating journal: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageGenericSaveError(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Builds the dropdown selector for choosing a [PaletteModel].
  ///
  /// Displays a message if no models are available.
  Widget _buildPaletteModelSelector() {
    final l10n = AppLocalizations.of(context)!;
    if (_availablePaletteModels.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(l10n.noPaletteModelsAvailableMessage, style: TextStyle(color: Colors.orange.shade700))
      );
    }
    return DropdownButtonFormField<PaletteModel>(
      value: _selectedPaletteModel,
      items: _availablePaletteModels.map((PaletteModel model) {
        return DropdownMenuItem<PaletteModel>(
          value: model,
          child: Text(model.name + (model.isPredefined ? l10n.paletteModelSuffixPredefined : l10n.paletteModelSuffixPersonal)),
        );
      }).toList(),
      onChanged: (PaletteModel? newValue) {
        if (mounted) {
          setState(() {
            _selectedPaletteModel = newValue;
            _updatePaletteBasedOnMode();
          });
        }
      },
      decoration: InputDecoration(labelText: l10n.choosePaletteModelDropdownLabel),
      validator: (value) => _creationMode == JournalCreationMode.fromPaletteModel && value == null ? l10n.pleaseChooseModelValidator : null,
    );
  }

  /// Builds the dropdown selector for choosing an existing [Journal] to copy the palette from.
  ///
  /// Displays a message if no user journals are available.
  Widget _buildExistingJournalSelector() {
    final l10n = AppLocalizations.of(context)!;
    if (_availableUserJournals.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(l10n.noExistingJournalsToCopy, style: TextStyle(color: Colors.orange.shade700))
      );
    }
    return DropdownButtonFormField<Journal>(
      value: _selectedExistingJournal,
      items: _availableUserJournals.map((Journal journal) {
        return DropdownMenuItem<Journal>(
          value: journal,
          child: Text(journal.name),
        );
      }).toList(),
      onChanged: (Journal? newValue) {
        if (mounted) {
          setState(() {
            _selectedExistingJournal = newValue;
            _updatePaletteBasedOnMode();
          });
        }
      },
      decoration: InputDecoration(labelText: l10n.copyPaletteFromJournalDropdownLabel),
      validator: (value) => _creationMode == JournalCreationMode.fromExistingJournal && value == null ? l10n.pleaseChooseJournalValidator : null,
    );
  }

  /// Builds a styled step indicator widget.
  ///
  /// [stepNumber] The number of the step (e.g., "1", "2").
  /// [title] The title of the step.
  Widget _buildStepIndicator(String stepNumber, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(stepNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Determine if the create button should be enabled based on selections.
    bool canAttemptCreation = true;
    if (_creationMode == JournalCreationMode.fromPaletteModel && _selectedPaletteModel == null && _availablePaletteModels.isNotEmpty) {
      canAttemptCreation = false; // Must select a model if mode is fromPaletteModel and models are available
    }
    if (_creationMode == JournalCreationMode.fromExistingJournal && _selectedExistingJournal == null && _availableUserJournals.isNotEmpty) {
      canAttemptCreation = false; // Must select a journal if mode is fromExistingJournal and journals are available
    }

    // Update snackbar texts in _loadInitialData if context is available, or use a more generic approach.
    // For this iteration, _loadInitialData was modified to not directly use l10n for snackbars shown before build.
    // Those snackbars will use generic English text or be updated if context can be passed/made available.

    if (_userId == null && !_isLoading) { // Handle user not identified after initial load attempt
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.userNotIdentifiedSnackbar)));
          }
        });
    }
    
    // Update palette names in _updatePaletteBasedOnMode if it hasn't run with l10n yet
    // This is tricky if _updatePaletteBasedOnMode is called from initState.
    // A common pattern is to call it again in didChangeDependencies or ensure l10n is passed.
    // The current _updatePaletteBasedOnMode takes an optional l10n instance.
    // We ensure it's called with l10n from build context if needed, or from _loadInitialData with l10n.

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createJournalPageTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 20.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator("1", l10n.step1JournalName),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _journalNameController,
                        decoration: InputDecoration(
                          labelText: l10n.journalNameTextFieldLabel,
                          hintText: l10n.journalNameTextFieldHint,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.drive_file_rename_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.journalNameValidatorEmpty;
                          }
                          if (value.length > 70) {
                            return l10n.journalNameValidatorTooLong;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 20.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator("2", l10n.step2PaletteConfiguration),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PaletteSourceType>(
                        value: _selectedSourceType,
                        decoration: InputDecoration(
                            labelText: l10n.paletteSourceDropdownLabel,
                            border: const OutlineInputBorder()
                        ),
                        items: [
                          DropdownMenuItem(value: PaletteSourceType.empty, child: Text(l10n.paletteSourceEmptyOption)),
                          DropdownMenuItem(value: PaletteSourceType.model, child: Text(l10n.paletteSourceModelOption)),
                          DropdownMenuItem(value: PaletteSourceType.existingJournal, child: Text(l10n.paletteSourceExistingJournalOption)),
                        ],
                        onChanged: (PaletteSourceType? newValue) {
                          if (newValue != null && mounted) {
                            setState(() {
                              _selectedSourceType = newValue;
                              if (newValue == PaletteSourceType.empty) {
                                _creationMode = JournalCreationMode.emptyPalette;
                              } else if (newValue == PaletteSourceType.model) {
                                _creationMode = JournalCreationMode.fromPaletteModel;
                              } else if (newValue == PaletteSourceType.existingJournal) {
                                _creationMode = JournalCreationMode.fromExistingJournal;
                              }
                              _updatePaletteBasedOnMode(); // Will use context from build
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      if (_creationMode == JournalCreationMode.fromPaletteModel)
                        _buildPaletteModelSelector(),
                      if (_creationMode == JournalCreationMode.fromExistingJournal)
                        _buildExistingJournalSelector(),

                      const SizedBox(height: 10),
                      if (!_isLoading)
                        InlinePaletteEditorWidget(
                          key: _paletteEditorKey,
                          initialPaletteName: _preparedPaletteName,
                          initialColors: _preparedColors,
                          onPaletteNameChanged: (newName) {
                            if (mounted) setState(() => _preparedPaletteName = newName);
                          },
                          onColorsChanged: (newColors) {
                            if (mounted) setState(() => _preparedColors = newColors);
                          },
                          showNameEditor: false,
                          isEditingJournalPalette: false,
                          onDeleteAllColorsRequested: _handleDeleteAllColorsInCreation,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.createJournalButtonLabel),
                  onPressed: (_isLoading || !canAttemptCreation) ? null : _createJournal,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16)
                  ),
                ),
              ),
              const SizedBox(height: 20), 
            ],
          ),
        ),
      ),
    );
  }
}
