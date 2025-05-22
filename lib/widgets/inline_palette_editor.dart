import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../core/app_constants.dart';
import '../models/color_data.dart'; // Defines the ColorData model.

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
/// A global Uuid instance for generating unique IDs for new ColorData items.
const _uuid = Uuid();


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
    final l10n = AppLocalizations.of(context)!;
    final bool isAdding = existingColorData == null;
    Color pickerColor = isAdding ? Colors.grey : existingColorData.color;
    String initialTitle = isAdding ? '' : existingColorData.title;

    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final TextEditingController gradientStepsController = TextEditingController(text: '1');
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    String addButtonText = isAdding ? l10n.addColorButtonLabel : l10n.saveButtonLabel;
    Widget? deleteButton;

    if (!isAdding && existingColorIndex != null) {
      deleteButton = TextButton.icon(
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        label: Text(l10n.deleteThisColorButtonLabel, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        onPressed: () async {
          Navigator.of(context).pop();
          final bool? confirmDelete = await showDialog<bool>(
            context: context,
            builder: (BuildContext confirmCtx) {
              return AlertDialog(
                title: Text(l10n.confirmDeleteColorTitle),
                content: Text(l10n.confirmDeleteColorContent(existingColorData.title)),
                actions: <Widget>[
                  TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(confirmCtx).pop(false)),
                  TextButton(child: Text(l10n.deleteButtonLabel, style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(confirmCtx).pop(true)),
                ],
              );
            },
          );
          if (confirmDelete == true) {
            await _removeColor(existingColorIndex);
          }
        },
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isAdding ? l10n.addColorGradientDialogTitle : l10n.editColorDialogTitle),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(labelText: l10n.baseNameForColorGradientLabel),
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.baseNameCannotBeEmptyValidator;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      if (isAdding)
                        TextFormField(
                          controller: gradientStepsController,
                          decoration: InputDecoration(labelText: l10n.numberOfColorsLabel(MAX_GRADIENT_STEPS), hintText: l10n.numberOfColorsHint),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            int steps = int.tryParse(value) ?? 1;
                            setDialogState(() {
                              addButtonText = steps > 1 ? l10n.addGradientButtonLabel : l10n.addColorButtonLabel;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return l10n.enterNumberValidator;
                            int steps = int.tryParse(value) ?? 0;
                            if (steps < 1 || steps > MAX_GRADIENT_STEPS) {
                              return l10n.numberBetweenValidator(MAX_GRADIENT_STEPS);
                            }
                            if (_editableColors.length + steps > MAX_COLORS_IN_PALETTE_EDITOR) {
                              return l10n.tooManyColorsValidator((MAX_COLORS_IN_PALETTE_EDITOR - _editableColors.length));
                            }
                            return null;
                          },
                        ),
                      if (isAdding) const SizedBox(height: 20),
                      ColorPicker(
                        pickerColor: pickerColor,
                        onColorChanged: (color) => pickerColor = color,
                        colorPickerWidth: 300.0,
                        pickerAreaHeightPercent: 0.7,
                        enableAlpha: false,
                        displayThumbColor: true,
                        paletteType: PaletteType.hsvWithValue,
                        pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(2.0)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                if (deleteButton != null) deleteButton,
                TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop()),
                FilledButton(
                  child: Text(addButtonText),
                  onPressed: () {
                    if (!dialogFormKey.currentState!.validate()) return;

                    final String baseTitle = titleController.text.trim();
                    final int gradientSteps = isAdding ? (int.tryParse(gradientStepsController.text) ?? 1) : 1;
                    List<ColorData> colorsToAdd = [];
                    List<String> tempGeneratedTitles = [];
                    List<String> tempGeneratedHexCodes = [];

                    if (gradientSteps == 1) {
                      final String newHexCode = '#${pickerColor.value.toRadixString(16).substring(2).toUpperCase()}';
                      if (_editableColors.any((c) => c.title.toLowerCase() == baseTitle.toLowerCase() && (isAdding || c.paletteElementId != existingColorData.paletteElementId))) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.colorTitleExistsError), backgroundColor: Colors.orange));
                        return;
                      }
                      if (_editableColors.any((c) => c.hexCode.toUpperCase() == newHexCode.toUpperCase() && (isAdding || c.paletteElementId != existingColorData.paletteElementId))) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.colorHexExistsError), backgroundColor: Colors.orange));
                        return;
                      }
                      colorsToAdd.add(ColorData(paletteElementId: isAdding ? _uuid.v4() : existingColorData.paletteElementId, title: baseTitle, hexCode: newHexCode));
                    } else {
                      if (_editableColors.length + gradientSteps > MAX_COLORS_IN_PALETTE_EDITOR) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotAddGradientMaxReachedError(gradientSteps)), backgroundColor: Colors.orange));
                        return;
                      }
                      HSLColor hslPickerColor = HSLColor.fromColor(pickerColor);
                      double centerLightness = hslPickerColor.lightness;
                      double maxLightnessDeviation = 0.3;
                      for (int i = 0; i < gradientSteps; i++) {
                        double stepFactor = (gradientSteps == 1) ? 0 : (i / (gradientSteps - 1) * 2.0) - 1.0;
                        double currentLightness = (centerLightness + stepFactor * maxLightnessDeviation).clamp(0.0, 1.0);
                        Color newColor = hslPickerColor.withLightness(currentLightness).toColor();
                        String newHex = '#${newColor.value.toRadixString(16).substring(2).toUpperCase()}';
                        String newTitle = "$baseTitle ${i + 1}";

                        if (tempGeneratedTitles.contains(newTitle.toLowerCase()) || _editableColors.any((c) => c.title.toLowerCase() == newTitle.toLowerCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.generatedTitleExistsError(newTitle)), backgroundColor: Colors.orange));
                          return;
                        }
                        if (tempGeneratedHexCodes.contains(newHex.toUpperCase()) || _editableColors.any((c) => c.hexCode.toUpperCase() == newHex.toUpperCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.generatedColorExistsError(newHex)), backgroundColor: Colors.orange));
                          return;
                        }
                        tempGeneratedTitles.add(newTitle.toLowerCase());
                        tempGeneratedHexCodes.add(newHex.toUpperCase());
                        colorsToAdd.add(ColorData(paletteElementId: _uuid.v4(), title: newTitle, hexCode: newHex));
                      }
                    }

                    if (mounted) {
                      setState(() {
                        if (isAdding) {
                          _editableColors.addAll(colorsToAdd);
                        } else if (existingColorIndex != null && colorsToAdd.isNotEmpty) {
                          _editableColors[existingColorIndex] = colorsToAdd.first;
                        }
                        widget.onColorsChanged(List.from(_editableColors));
                        widget.onPaletteNeedsSave?.call();
                      });
                    }
                    Navigator.of(dialogContext).pop();
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.allColorsDeletedFromEditorSnackbar), backgroundColor: Colors.green));
        }
      }
    }
  }

  /// Removes a color from the `_editableColors` list at the given [indexToRemove].
  Future<void> _removeColor(int indexToRemove) async {
    final l10n = AppLocalizations.of(context)!;
    final String colorTitle = _editableColors[indexToRemove].title;

    if (!widget.isEditingJournalPalette && _editableColors.length <= MIN_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.modelMinColorsDeleteError(MIN_COLORS_IN_PALETTE_EDITOR, colorTitle))));
      }
      return;
    }

    if (widget.isEditingJournalPalette && widget.canDeleteColorCallback != null) {
      final colorToDelete = _editableColors[indexToRemove];
      final bool canDelete = await widget.canDeleteColorCallback!(colorToDelete.paletteElementId);
      if (!canDelete) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.colorInUseDeleteError(colorToDelete.title)), backgroundColor: Colors.orange));
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _editableColors.removeAt(indexToRemove);
        widget.onColorsChanged(List.from(_editableColors));
        widget.onPaletteNeedsSave?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.colorDeletedSnackbar(colorTitle)), duration: const Duration(seconds: 1)));
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
    final l10n = AppLocalizations.of(context)!;
    bool canShowAddButtonInListOrGrid = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;
    _loggerPage.d("DEBUG DELETE ALL : widget.onDeleteAllColorsRequested :${widget.onDeleteAllColorsRequested} \n _editableColors.isNotEmpty:${_editableColors.isNotEmpty}");
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showNameEditor)
          TextFormField(
            controller: _paletteNameController,
            decoration: InputDecoration(labelText: l10n.paletteNameLabel, hintText: l10n.paletteNameHint, border: const OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.paletteNameEmptyValidator;
              }
              if (value.length > 50) return l10n.paletteNameTooLongValidator;
              return null;
            },
          ),
        if (widget.showNameEditor) const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.colorsSectionHeader(_editableColors.length, MAX_COLORS_IN_PALETTE_EDITOR), style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                if (widget.onDeleteAllColorsRequested != null && _editableColors.isNotEmpty)
                  Tooltip(
                    message: l10n.deleteAllColorsTooltip,
                    child: IconButton(icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error), onPressed: _handleDeleteAllColors),
                  ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  tooltip: _isGridView ? l10n.viewAsListTooltip : l10n.viewAsGridTooltip,
                  onPressed: () => { if (mounted) setState(() => _isGridView = !_isGridView) },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_editableColors.isEmpty && !canShowAddButtonInListOrGrid)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: Text(l10n.paletteEmptyMaxReachedMessage, textAlign: TextAlign.center))
          )
        else if (_editableColors.isEmpty && canShowAddButtonInListOrGrid)
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
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.addNewColorGradientListTile, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
        onTap: () => _showEditColorDialog(),
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
