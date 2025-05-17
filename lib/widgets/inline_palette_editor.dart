import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/color_data.dart'; // Defines the ColorData model.


/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
/// A global Uuid instance for generating unique IDs for new ColorData items.
const _uuid = Uuid();

/// The minimum number of colors allowed in a palette when using this editor,
/// particularly relevant for palette models.
const int MIN_COLORS_IN_PALETTE_EDITOR = 1;
/// The maximum number of colors allowed in a palette when using this editor.
const int MAX_COLORS_IN_PALETTE_EDITOR = 48;
/// The maximum number of steps allowed when generating a gradient of colors.
const int MAX_GRADIENT_STEPS = 48;


/// A widget for inline editing of a color palette.
///
/// This widget allows users to:
/// - Edit the palette name (if [showNameEditor] is true).
/// - Add new colors or gradients of colors.
/// - Edit existing colors (name and hex code).
/// - Delete colors (with an optional callback to check if deletion is allowed).
/// - Reorder colors within the palette (in list view).
/// - View colors in a grid or list format.
/// - Delete all colors (with an optional confirmation callback).
///
/// It calls back [onPaletteNameChanged], [onColorsChanged], and [onPaletteNeedsSave]
/// to notify the parent widget of changes, facilitating automatic saving or other actions.
class InlinePaletteEditorWidget extends StatefulWidget {
  /// The initial name of the palette.
  final String initialPaletteName;
  /// The initial list of [ColorData] objects for the palette.
  final List<ColorData> initialColors;
  /// Callback function invoked when the palette name changes in the editor.
  final Function(String newName) onPaletteNameChanged;
  /// Callback function invoked when the list of colors changes
  /// (e.g., a color is added, edited, deleted, or reordered).
  final Function(List<ColorData> newColors) onColorsChanged;
  /// Flag indicating if the palette being edited belongs to a journal instance
  /// (`true`) or if it's a palette model (`false`). This can affect certain
  /// behaviors, like deletion constraints.
  final bool isEditingJournalPalette;
  /// Optional callback to determine if a specific color (by its [paletteElementId])
  /// can be deleted. This is useful for preventing deletion of colors that are
  /// currently in use (e.g., by notes in a journal).
  final Future<bool> Function(String paletteElementId)? canDeleteColorCallback;
  /// Optional callback invoked whenever a change occurs in the palette
  /// (name or colors) that might require the parent to save the state.
  final Future<void> Function()? onPaletteNeedsSave;
  /// Flag to control the visibility of the palette name editor. Defaults to `true`.
  /// Set to `false` if the palette name is managed externally or should not be editable here.
  final bool showNameEditor;
  /// Optional callback invoked when the user requests to delete all colors from the palette.
  /// The parent widget is expected to handle any confirmation dialogs and then,
  /// if confirmed, can proceed to clear the colors or instruct this widget to do so.
  final Future<bool> Function()? onDeleteAllColorsRequested;

  /// Creates an [InlinePaletteEditorWidget].
  const InlinePaletteEditorWidget({
    super.key,
    required this.initialPaletteName,
    required this.initialColors,
    required this.onPaletteNameChanged,
    required this.onColorsChanged,
    this.isEditingJournalPalette = false,
    this.canDeleteColorCallback,
    this.onPaletteNeedsSave,
    this.showNameEditor = true,
    this.onDeleteAllColorsRequested,
  });

  @override
  _InlinePaletteEditorWidgetState createState() => _InlinePaletteEditorWidgetState();
}

/// The state for the [InlinePaletteEditorWidget].
///
/// Manages the editable palette name, list of colors, and the current view mode (grid/list).
/// It handles user interactions for adding, editing, deleting, and reordering colors.
class _InlinePaletteEditorWidgetState extends State<InlinePaletteEditorWidget> {
  /// Controller for the palette name text field.
  late TextEditingController _paletteNameController;
  /// The current list of [ColorData] being edited. This is a deep copy of `widget.initialColors`
  /// to allow local modifications without directly mutating the parent's state until intended.
  late List<ColorData> _editableColors;
  /// `true` if colors are displayed in a grid, `false` for a list view.
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _paletteNameController = TextEditingController(text: widget.initialPaletteName);
    // Create a deep copy of initial colors to allow local modifications.
    _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();

    // Listen to palette name changes to invoke callbacks.
    _paletteNameController.addListener(() {
      widget.onPaletteNameChanged(_paletteNameController.text);
      // If the name editor is visible, any change to the name should trigger a save.
      if (widget.showNameEditor) {
        widget.onPaletteNeedsSave?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InlinePaletteEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update palette name controller if initial name changes from parent,
    // but only if the controller's text hasn't been changed by the user already to that new value.
    if (widget.initialPaletteName != oldWidget.initialPaletteName &&
        widget.initialPaletteName != _paletteNameController.text) {
      _paletteNameController.text = widget.initialPaletteName;
    }
    // Update editable colors if initial colors change from parent.
    // This ensures the editor reflects external updates to the palette.
    // The _listEquals check helps prevent unnecessary rebuilds if the list content is identical.
    if (!_listEquals(widget.initialColors, _editableColors) && // Only update if current state differs from new props
        (!_listEquals(widget.initialColors, oldWidget.initialColors) || // And new props differ from old props
            widget.initialColors.length != oldWidget.initialColors.length)) {
      _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();
    }
  }

  /// Compares two lists, specifically designed to compare lists of [ColorData]
  /// by their content rather than by reference.
  ///
  /// Returns `true` if the lists are identical in length and content, `false` otherwise.
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] is ColorData && b[i] is ColorData) {
        final colorA = a[i] as ColorData;
        final colorB = b[i] as ColorData;
        // Compare all relevant fields of ColorData.
        if (colorA.paletteElementId != colorB.paletteElementId ||
            colorA.title != colorB.title ||
            colorA.hexCode != colorB.hexCode ||
            colorA.isDefault != colorB.isDefault) {
          return false;
        }
      } else if (a[i] != b[i]) {
        // Fallback for non-ColorData types, though this list should only contain ColorData.
        return false;
      }
    }
    return true;
  }

  /// Shows a dialog to add a new color/gradient or edit an existing color.
  ///
  /// [existingColorData] The [ColorData] to edit. If null, a new color is being added.
  /// [existingColorIndex] The index of the color being edited. Null if adding.
  void _showEditColorDialog({ColorData? existingColorData, int? existingColorIndex}) {
    final bool isAdding = existingColorData == null;
    Color pickerColor = isAdding ? Colors.grey : existingColorData.color; // Initial color for the picker.
    String initialTitle = isAdding ? '' : existingColorData.title; // Initial title. Note: `title` in ColorData is non-nullable.

    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final TextEditingController gradientStepsController = TextEditingController(text: '1'); // For adding gradients.
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>(); // For dialog form validation.
    String addButtonText = isAdding ? 'Ajouter la couleur' : 'Sauvegarder'; // UI Text in French. Dynamic button text.
    Widget? deleteButton; // Delete button, only shown when editing.

    // If editing an existing color, provide a delete button.
    if (!isAdding && existingColorIndex != null) {
      deleteButton = TextButton.icon(
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        label: Text('Supprimer cette couleur', style: TextStyle(color: Theme.of(context).colorScheme.error)), // UI Text in French
        onPressed: () async {
          Navigator.of(context).pop(); // Close the edit dialog first.
          // Show a confirmation dialog for deletion.
          final bool? confirmDelete = await showDialog<bool>(
            context: context,
            builder: (BuildContext confirmCtx) {
              return AlertDialog(
                title: const Text('Confirmer la suppression'), // UI Text in French
                content: Text('Voulez-vous vraiment supprimer la couleur "${existingColorData.title}" ?'), // UI Text in French
                actions: <Widget>[
                  TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(confirmCtx).pop(false)), // UI Text in French
                  TextButton(child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(confirmCtx).pop(true)), // UI Text in French
                ],
              );
            },
          );
          if (confirmDelete == true) {
            await _removeColor(existingColorIndex); // Call method to remove the color.
          }
        },
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Use StatefulBuilder to update dialog content (e.g., addButtonText).
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isAdding ? 'Ajouter une couleur/dégradé' : 'Modifier la couleur'), // UI Text in French
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title input field.
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Nom de base pour la couleur/dégradé'), // UI Text in French
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le titre de base ne peut pas être vide.'; // UI Text in French
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Gradient steps input field (only for adding new colors).
                      if (isAdding)
                        TextFormField(
                          controller: gradientStepsController,
                          decoration: const InputDecoration(labelText: 'Nombre de couleurs (1 pour simple, 2-$MAX_GRADIENT_STEPS pour dégradé)', hintText: '1'), // UI Text in French
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            int steps = int.tryParse(value) ?? 1;
                            setDialogState(() { // Update button text based on number of steps.
                              addButtonText = steps > 1 ? 'Ajouter le dégradé' : 'Ajouter la couleur'; // UI Text in French
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Entrez un nombre.'; // UI Text in French
                            int steps = int.tryParse(value) ?? 0;
                            if (steps < 1 || steps > MAX_GRADIENT_STEPS) {
                              return 'Entre 1 et $MAX_GRADIENT_STEPS.'; // UI Text in French
                            }
                            if (_editableColors.length + steps > MAX_COLORS_IN_PALETTE_EDITOR) {
                              return 'Trop de couleurs (max ${MAX_COLORS_IN_PALETTE_EDITOR - _editableColors.length} permis).'; // UI Text in French
                            }
                            return null;
                          },
                        ),
                      if (isAdding) const SizedBox(height: 20),
                      // Color picker widget.
                      ColorPicker(
                        pickerColor: pickerColor,
                        onColorChanged: (color) => pickerColor = color, // Update pickerColor on change.
                        colorPickerWidth: 300.0,
                        pickerAreaHeightPercent: 0.7,
                        enableAlpha: false, // Alpha channel is not used.
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithValue, // Color model for the picker.
                        pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(2.0)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                if (deleteButton != null) deleteButton, // Show delete button if editing.
                TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()), // UI Text in French
                FilledButton( // Add/Save button.
                  child: Text(addButtonText),
                  onPressed: () {
                    if (!dialogFormKey.currentState!.validate()) return; // Validate the dialog form.

                    final String baseTitle = titleController.text.trim();
                    final int gradientSteps = isAdding ? (int.tryParse(gradientStepsController.text) ?? 1) : 1;
                    List<ColorData> colorsToAdd = [];
                    List<String> tempGeneratedTitles = []; // For checking duplicate titles within the gradient.
                    List<String> tempGeneratedHexCodes = []; // For checking duplicate hex codes within the gradient.

                    if (gradientSteps == 1) { // Adding a single color or editing an existing one.
                      final String newHexCode = '#${pickerColor.value.toRadixString(16).substring(2).toUpperCase()}';
                      // Check for duplicate title.
                      if (_editableColors.any((c) => c.title.toLowerCase() == baseTitle.toLowerCase() && (isAdding || c.paletteElementId != existingColorData.paletteElementId))) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre de couleur existe déjà.'), backgroundColor: Colors.orange)); // UI Text in French
                        return;
                      }
                      // Check for duplicate hex code.
                      if (_editableColors.any((c) => c.hexCode.toUpperCase() == newHexCode.toUpperCase() && (isAdding || c.paletteElementId != existingColorData.paletteElementId))) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cette couleur (hex) existe déjà.'), backgroundColor: Colors.orange)); // UI Text in French
                        return;
                      }
                      colorsToAdd.add(ColorData(paletteElementId: isAdding ? _uuid.v4() : existingColorData.paletteElementId, title: baseTitle, hexCode: newHexCode));
                    } else { // Adding a gradient of colors.
                      if (_editableColors.length + gradientSteps > MAX_COLORS_IN_PALETTE_EDITOR) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ajouter $gradientSteps couleurs, maximum de la palette atteint.'), backgroundColor: Colors.orange)); // UI Text in French
                        return;
                      }
                      HSLColor hslPickerColor = HSLColor.fromColor(pickerColor);
                      double centerLightness = hslPickerColor.lightness;
                      double maxLightnessDeviation = 0.3; // Max deviation for lightness in gradient.
                      for (int i = 0; i < gradientSteps; i++) {
                        // Calculate lightness for the current step in the gradient.
                        double stepFactor = (gradientSteps == 1) ? 0 : (i / (gradientSteps - 1) * 2.0) - 1.0;
                        double currentLightness = (centerLightness + stepFactor * maxLightnessDeviation).clamp(0.0, 1.0);
                        Color newColor = hslPickerColor.withLightness(currentLightness).toColor();
                        String newHex = '#${newColor.value.toRadixString(16).substring(2).toUpperCase()}';
                        String newTitle = "$baseTitle ${i + 1}"; // Append step number to base title.

                        // Check for duplicate titles/hex codes within the generated gradient and existing colors.
                        if (tempGeneratedTitles.contains(newTitle.toLowerCase()) || _editableColors.any((c) => c.title.toLowerCase() == newTitle.toLowerCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Titre généré "$newTitle" existe déjà.'), backgroundColor: Colors.orange)); // UI Text in French
                          return;
                        }
                        if (tempGeneratedHexCodes.contains(newHex.toUpperCase()) || _editableColors.any((c) => c.hexCode.toUpperCase() == newHex.toUpperCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couleur générée $newHex existe déjà.'), backgroundColor: Colors.orange)); // UI Text in French
                          return;
                        }
                        tempGeneratedTitles.add(newTitle.toLowerCase());
                        tempGeneratedHexCodes.add(newHex.toUpperCase());
                        colorsToAdd.add(ColorData(paletteElementId: _uuid.v4(), title: newTitle, hexCode: newHex));
                      }
                    }

                    // Update the state with the new/modified colors.
                    if (mounted) {
                      setState(() {
                        if (isAdding) {
                          _editableColors.addAll(colorsToAdd);
                        } else if (existingColorIndex != null && colorsToAdd.isNotEmpty) {
                          // Replace the existing color with the (first) modified color.
                          _editableColors[existingColorIndex] = colorsToAdd.first;
                        }
                        widget.onColorsChanged(List.from(_editableColors)); // Notify parent of changes.
                        widget.onPaletteNeedsSave?.call(); // Trigger save.
                      });
                    }
                    Navigator.of(dialogContext).pop(); // Close the dialog.
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Handles the "delete all colors" action.
  ///
  /// If `widget.onDeleteAllColorsRequested` is provided, it calls this callback
  /// (which should show a confirmation dialog to the user). If confirmed,
  /// it clears the `_editableColors` list and notifies the parent.
  Future<void> _handleDeleteAllColors() async {
    if (widget.onDeleteAllColorsRequested != null) {
      final bool shouldProceed = await widget.onDeleteAllColorsRequested!();
      if (shouldProceed) {
        if (mounted) {
          setState(() {
            _editableColors.clear();
            widget.onColorsChanged(List.from(_editableColors));
            widget.onPaletteNeedsSave?.call();
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toutes les couleurs ont été supprimées de la palette en cours d\'édition.'), backgroundColor: Colors.green)); // UI Text in French
        }
      }
    }
  }

  /// Removes a color from the `_editableColors` list at the given [indexToRemove].
  ///
  /// Before removal, it checks constraints:
  /// - For palette models, ensures the minimum number of colors is maintained.
  /// - For journal palettes, if `widget.canDeleteColorCallback` is provided,
  ///   it calls this callback to check if the color is in use and can be deleted.
  Future<void> _removeColor(int indexToRemove) async {
    final String colorTitle = _editableColors[indexToRemove].title;

    // Prevent deletion if it violates minimum color count for palette models.
    if (!widget.isEditingJournalPalette && _editableColors.length <= MIN_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Un modèle de palette doit contenir au moins $MIN_COLORS_IN_PALETTE_EDITOR couleur(s). Impossible de supprimer "$colorTitle".'))); // UI Text in French
      }
      return;
    }

    // If editing a journal palette and a callback is provided, check if the color can be deleted.
    if (widget.isEditingJournalPalette && widget.canDeleteColorCallback != null) {
      final colorToDelete = _editableColors[indexToRemove];
      final bool canDelete = await widget.canDeleteColorCallback!(colorToDelete.paletteElementId);
      if (!canDelete) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('La couleur "${colorToDelete.title}" est utilisée et ne peut être supprimée.'), backgroundColor: Colors.orange)); // UI Text in French
        }
        return;
      }
    }

    // Proceed with removal if all checks pass.
    if (mounted) {
      setState(() {
        _editableColors.removeAt(indexToRemove);
        widget.onColorsChanged(List.from(_editableColors)); // Notify parent.
        widget.onPaletteNeedsSave?.call(); // Trigger save.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couleur "$colorTitle" supprimée.'), duration: const Duration(seconds: 1))); // UI Text in French
      });
    }
  }

  /// Handles reordering of colors in the list view.
  ///
  /// Called by [ReorderableListView] when a color is dragged to a new position.
  /// Updates the `_editableColors` list and notifies the parent.
  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex >= _editableColors.length) return; // Safety check.
    if (mounted) {
      setState(() {
        // Adjust newIndex if item is moved downwards in the list.
        if (newIndex > _editableColors.length) {
          newIndex = _editableColors.length;
        }
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final ColorData item = _editableColors.removeAt(oldIndex);
        _editableColors.insert(newIndex, item);
        widget.onColorsChanged(List.from(_editableColors)); // Notify parent.
        widget.onPaletteNeedsSave?.call(); // Trigger save.
      });
    }
  }

  @override
  void dispose() {
    _paletteNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the "Add" button should be shown (i.e., if max color limit not reached).
    bool canShowAddButtonInListOrGrid = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;
    _loggerPage.d("DEBUG DELETE ALL : widget.onDeleteAllColorsRequested :${widget.onDeleteAllColorsRequested} \n _editableColors.isNotEmpty:${_editableColors.isNotEmpty}");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Palette name editor (optional).
        if (widget.showNameEditor)
          TextFormField(
            controller: _paletteNameController,
            decoration: const InputDecoration(labelText: 'Nom de la palette', hintText: 'Ex: Ma palette de travail', border: OutlineInputBorder()), // UI Text in French
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le nom de la palette ne peut pas être vide.'; // UI Text in French
              }
              if (value.length > 50) return 'Le nom ne doit pas dépasser 50 caractères.'; // UI Text in French
              return null;
            },
          ),
        if (widget.showNameEditor) const SizedBox(height: 16),

        // Header for the colors section with count and view toggle.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Couleurs (${_editableColors.length} / $MAX_COLORS_IN_PALETTE_EDITOR) :', style: Theme.of(context).textTheme.titleMedium), // UI Text in French
            Row(
              children: [
                // "Delete All Colors" button, if callback is provided and colors exist.
                if (widget.onDeleteAllColorsRequested != null && _editableColors.isNotEmpty)
                  Tooltip(
                    message: "Supprimer toutes les couleurs", // UI Text in French
                    child: IconButton(icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error), onPressed: _handleDeleteAllColors),
                  ),
                // Grid/List view toggle button.
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  tooltip: _isGridView ? "Afficher en liste" : "Afficher en grille", // UI Text in French
                  onPressed: () => { if (mounted) setState(() => _isGridView = !_isGridView) },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Display message if palette is empty and cannot add more, or display the color editor.
        if (_editableColors.isEmpty && !canShowAddButtonInListOrGrid)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: Text("La palette est vide et a atteint le nombre maximum de couleurs.", textAlign: TextAlign.center)) // UI Text in French
          )
        else if (_editableColors.isEmpty && canShowAddButtonInListOrGrid)
        // If empty but can add, show the appropriate view (grid or list) which will include an add button.
          _isGridView ? _buildGridView() : _buildListView()
        else
        // If not empty, show the appropriate view.
          _isGridView ? _buildGridView() : _buildListView(),
      ],
    );
  }

  /// Builds the "Add New Color" card for the grid view.
  Widget _buildAddButtonCardGrid() {
    return Card(
      key: const ValueKey('add_new_color_grid_card'), // For testing/identification.
      elevation: 2.0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest, // Slightly elevated surface color.
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5) // Border to distinguish.
      ),
      child: InkWell(
        onTap: () => _showEditColorDialog(), // Open dialog to add color.
        borderRadius: BorderRadius.circular(10.0),
        child: Center(child: Icon(Icons.add_circle_outline, size: 30.0, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  /// Builds the "Add New Color/Gradient" list tile for the list view.
  Widget _buildAddButtonListTile() {
    return Card(
      key: const ValueKey('add_new_color_list_card'), // For testing/identification.
      elevation: 1.0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)
      ),
      child: ListTile(
        leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 28),
        title: Text("Ajouter une nouvelle couleur/dégradé", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)), // UI Text in French
        onTap: () => _showEditColorDialog(), // Open dialog to add color.
        contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      ),
    );
  }

  /// Builds the grid view for displaying and interacting with colors.
  Widget _buildGridView() {
    // Determine responsive grid column count.
    final screenWidth = MediaQuery.of(context).size.width;
    int gridCrossAxisCount;
    if (screenWidth < 350) {
      gridCrossAxisCount = 3;
    } else if (screenWidth < 450) {
      gridCrossAxisCount = 4;
    } else if (screenWidth < 600) {
      gridCrossAxisCount = 5;
    } else if (screenWidth < 800) {
      gridCrossAxisCount = 6;
    } else {
      gridCrossAxisCount = 7; // Max columns for very wide screens.
    }

    // Adjust font size based on grid density.
    double fontSize = 11.0;
    if (gridCrossAxisCount > 5) fontSize = 9.0;

    bool canAddMore = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;
    // Total items in grid: existing colors + 1 for "Add" button if space allows.
    int itemCount = _editableColors.length + (canAddMore ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true, // Important for embedding in a Column.
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling within the editor itself.
      padding: const EdgeInsets.symmetric(vertical: 5),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCrossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0, // Square items.
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // If it's the last item and we can add more, show the "Add" button.
        if (canAddMore && index == _editableColors.length) {
          return _buildAddButtonCardGrid();
        }
        final colorData = _editableColors[index];
        // Determine text color for contrast against the background color.
        final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
        return Card(
          key: ValueKey(colorData.paletteElementId), // Unique key for each color item.
          color: colorData.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          elevation: 2.0,
          child: InkWell(
            onTap: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: index),
            borderRadius: BorderRadius.circular(10.0),
            child: Stack( // Stack to overlay edit icon.
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Center(
                    child: Text(
                      colorData.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: fontSize, color: textColor, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),
                // Edit icon overlay.
                Positioned(top: 4, right: 4, child: Icon(Icons.edit_note_outlined, size: 16, color: textColor.withAlpha((0.7 * 255).round()))),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds the list view for displaying and interacting with colors.
  ///
  /// Uses [ReorderableListView] to allow drag-and-drop reordering of colors.
  Widget _buildListView() {
    bool canAddMore = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;

    // Map editable colors to Card widgets for the list.
    List<Widget> children = _editableColors.asMap().entries.map((entry) {
      int idx = entry.key;
      ColorData colorData = entry.value;
      // Determine text color for contrast.
      final Color textColorOnCard = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

      return Card(
        key: ValueKey(colorData.paletteElementId), // Unique key for reordering.
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: colorData.color,
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor: textColorOnCard.withAlpha((0.2 * 255).round()), // MODIFIED HERE - Semi-transparent background for index.
              child: Text((idx + 1).toString(), style: TextStyle(color: textColorOnCard, fontWeight: FontWeight.bold))
          ),
          title: Text(colorData.title, style: TextStyle(color: textColorOnCard, fontWeight: FontWeight.w500)),
          subtitle: Text(colorData.hexCode.toUpperCase(), style: TextStyle(color: textColorOnCard.withAlpha((0.85 * 255).round()))), // MODIFIED HERE
          onTap: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: idx),
          trailing: Row( // Edit and drag handles.
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_outlined, size: 20, color: textColorOnCard.withAlpha((0.7 * 255).round())), // MODIFIED HERE
              const SizedBox(width: 8),
              // Drag handle for reordering.
              ReorderableDragStartListener(index: idx, child: Icon(Icons.drag_handle_outlined, color: textColorOnCard.withAlpha((0.9 * 255).round()))), // MODIFIED HERE
            ],
          ),
        ),
      );
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editableColors.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true, // Important for embedding in a Column.
            physics: const NeverScrollableScrollPhysics(), // Disable scrolling within the editor itself.
            onReorder: _onReorder, // Callback for reordering.
            children: children, // The list of color cards.
          ),
        // "Add" button tile, shown if more colors can be added.
        if (canAddMore) _buildAddButtonListTile(),
      ],
    );
  }
}
