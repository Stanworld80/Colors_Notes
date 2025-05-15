import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
import '../models/color_data.dart';

const _uuid = Uuid();

const int MIN_COLORS_IN_PALETTE_EDITOR = 1;
const int MAX_COLORS_IN_PALETTE_EDITOR = 48;
const int MAX_GRADIENT_STEPS = 48;

class InlinePaletteEditorWidget extends StatefulWidget {
  final String initialPaletteName;
  final List<ColorData> initialColors;
  final Function(String newName) onPaletteNameChanged;
  final Function(List<ColorData> newColors) onColorsChanged;
  final bool isEditingJournalPalette;
  final Future<bool> Function(String paletteElementId)? canDeleteColorCallback;
  final Future<void> Function()? onPaletteNeedsSave;
  final bool showNameEditor;
  final Future<bool> Function()? onDeleteAllColorsRequested;

  const InlinePaletteEditorWidget({
    Key? key,
    required this.initialPaletteName,
    required this.initialColors,
    required this.onPaletteNameChanged,
    required this.onColorsChanged,
    this.isEditingJournalPalette = false,
    this.canDeleteColorCallback,
    this.onPaletteNeedsSave,
    this.showNameEditor = true,
    this.onDeleteAllColorsRequested,
  }) : super(key: key);

  @override
  _InlinePaletteEditorWidgetState createState() => _InlinePaletteEditorWidgetState();
}

class _InlinePaletteEditorWidgetState extends State<InlinePaletteEditorWidget> {
  late TextEditingController _paletteNameController;
  late List<ColorData> _editableColors;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _paletteNameController = TextEditingController(text: widget.initialPaletteName);
    _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();

    _paletteNameController.addListener(() {
      widget.onPaletteNameChanged(_paletteNameController.text);
      if (widget.showNameEditor) {
        widget.onPaletteNeedsSave?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InlinePaletteEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPaletteName != oldWidget.initialPaletteName && widget.initialPaletteName != _paletteNameController.text) {
      _paletteNameController.text = widget.initialPaletteName;
    }
    if (!_listEquals(widget.initialColors, _editableColors) && (!_listEquals(widget.initialColors, oldWidget.initialColors) || widget.initialColors.length != oldWidget.initialColors.length)) {
      _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();
    }
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] is ColorData && b[i] is ColorData) {
        final colorA = a[i] as ColorData;
        final colorB = b[i] as ColorData;
        if (colorA.paletteElementId != colorB.paletteElementId || colorA.title != colorB.title || colorA.hexCode != colorB.hexCode || colorA.isDefault != colorB.isDefault) {
          return false;
        }
      } else if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _showEditColorDialog({ColorData? existingColorData, int? existingColorIndex}) {
    final bool isAdding = existingColorData == null;
    Color pickerColor = isAdding ? Colors.grey : existingColorData.color;
    String initialTitle = isAdding ? '' : existingColorData.title;

    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final TextEditingController gradientStepsController = TextEditingController(text: '1');
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();
    String addButtonText = isAdding ? 'Ajouter la couleur' : 'Sauvegarder';
    Widget? deleteButton;

    if (!isAdding && existingColorIndex != null) {
      deleteButton = TextButton.icon(
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        label: Text('Supprimer cette couleur', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        onPressed: () async {
          Navigator.of(context).pop();
          final bool? confirmDelete = await showDialog<bool>(
            context: context,
            builder: (BuildContext confirmCtx) {
              return AlertDialog(
                title: const Text('Confirmer la suppression'),
                content: Text('Voulez-vous vraiment supprimer la couleur "${existingColorData.title}" ?'),
                actions: <Widget>[
                  TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(confirmCtx).pop(false)),
                  TextButton(child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(confirmCtx).pop(true)),
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
              title: Text(isAdding ? 'Ajouter une couleur/dégradé' : 'Modifier la couleur'),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Nom de base pour la couleur/dégradé'),
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le titre de base ne peut pas être vide.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      if (isAdding)
                        TextFormField(
                          controller: gradientStepsController,
                          decoration: const InputDecoration(labelText: 'Nombre de couleurs (1 pour simple, 2-$MAX_GRADIENT_STEPS pour dégradé)', hintText: '1'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            int steps = int.tryParse(value) ?? 1;
                            setDialogState(() {
                              addButtonText = steps > 1 ? 'Ajouter le dégradé' : 'Ajouter la couleur';
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Entrez un nombre.';
                            int steps = int.tryParse(value) ?? 0;
                            if (steps < 1 || steps > MAX_GRADIENT_STEPS) {
                              return 'Entre 1 et $MAX_GRADIENT_STEPS.';
                            }
                            if (_editableColors.length + steps > MAX_COLORS_IN_PALETTE_EDITOR) {
                              return 'Trop de couleurs (max ${MAX_COLORS_IN_PALETTE_EDITOR - _editableColors.length} permis).';
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
                const Spacer(),
                TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
                FilledButton(
                  child: Text(addButtonText),
                  onPressed: () {
                    // CORRECTION: unnecessary_null_comparison
                    // if (dialogFormKey.currentState != null && !dialogFormKey.currentState!.validate()) return;
                    // Devient:
                    if (!dialogFormKey.currentState!.validate()) return;

                    final String baseTitle = titleController.text.trim();
                    final int gradientSteps = isAdding ? (int.tryParse(gradientStepsController.text) ?? 1) : 1;
                    List<ColorData> colorsToAdd = [];
                    List<String> tempGeneratedTitles = [];
                    List<String> tempGeneratedHexCodes = [];

                    if (gradientSteps == 1) {
                      final String newHexCode = '#${pickerColor.value.toRadixString(16).substring(2).toUpperCase()}';
                      // CORRECTION: unnecessary_non_null_assertion
                      // if (_editableColors.any((c) => c.title.toLowerCase() == baseTitle.toLowerCase() && (isAdding || c.paletteElementId != existingColorData!.paletteElementId))) {
                      if (_editableColors.any((c) => c.title.toLowerCase() == baseTitle.toLowerCase() && (isAdding || c.paletteElementId != existingColorData.paletteElementId))) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce titre de couleur existe déjà.'), backgroundColor: Colors.orange));
                        return;
                      }
                      // CORRECTION: unnecessary_non_null_assertion
                      // if (_editableColors.any((c) => c.hexCode.toUpperCase() == newHexCode.toUpperCase() && (isAdding || c.paletteElementId != existingColorData!.paletteElementId))) {
                      if (_editableColors.any((c) => c.hexCode.toUpperCase() == newHexCode.toUpperCase() && (isAdding || c.paletteElementId != existingColorData.paletteElementId))) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cette couleur (hex) existe déjà.'), backgroundColor: Colors.orange));
                        return;
                      }
                      // CORRECTION: unnecessary_non_null_assertion
                      // colorsToAdd.add(ColorData(paletteElementId: isAdding ? _uuid.v4() : existingColorData!.paletteElementId, title: baseTitle, hexCode: newHexCode));
                      colorsToAdd.add(ColorData(paletteElementId: isAdding ? _uuid.v4() : existingColorData.paletteElementId, title: baseTitle, hexCode: newHexCode));
                    } else {
                      if (_editableColors.length + gradientSteps > MAX_COLORS_IN_PALETTE_EDITOR) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Impossible d\'ajouter $gradientSteps couleurs, maximum de la palette atteint.'), backgroundColor: Colors.orange));
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Titre généré "$newTitle" existe déjà.'), backgroundColor: Colors.orange));
                          return;
                        }
                        if (tempGeneratedHexCodes.contains(newHex.toUpperCase()) || _editableColors.any((c) => c.hexCode.toUpperCase() == newHex.toUpperCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couleur générée $newHex existe déjà.'), backgroundColor: Colors.orange));
                          return;
                        }
                        tempGeneratedTitles.add(newTitle.toLowerCase());
                        tempGeneratedHexCodes.add(newHex.toUpperCase());
                        colorsToAdd.add(ColorData(paletteElementId: _uuid.v4(), title: newTitle, hexCode: newHex));
                      }
                    }

                    setState(() {
                      if (isAdding) {
                        _editableColors.addAll(colorsToAdd);
                      } else if (existingColorIndex != null && colorsToAdd.isNotEmpty) {
                        _editableColors[existingColorIndex] = colorsToAdd.first;
                      }
                      widget.onColorsChanged(List.from(_editableColors));
                      widget.onPaletteNeedsSave?.call();
                    });
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toutes les couleurs ont été supprimées de la palette en cours d\'édition.'), backgroundColor: Colors.green));
        }
      }
    }
  }

  Future<void> _removeColor(int indexToRemove) async {
    final String colorTitle = _editableColors[indexToRemove].title;

    if (!widget.isEditingJournalPalette && _editableColors.length <= MIN_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Un modèle de palette doit contenir au moins $MIN_COLORS_IN_PALETTE_EDITOR couleur(s). Impossible de supprimer "${colorTitle}".')));
      }
      return;
    }

    if (widget.isEditingJournalPalette && widget.canDeleteColorCallback != null) {
      final colorToDelete = _editableColors[indexToRemove];
      final bool canDelete = await widget.canDeleteColorCallback!(colorToDelete.paletteElementId);
      if (!canDelete) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('La couleur "${colorToDelete.title}" est utilisée et ne peut être supprimée.'), backgroundColor: Colors.orange));
        }
        return;
      }
    }

    setState(() {
      _editableColors.removeAt(indexToRemove);
      widget.onColorsChanged(List.from(_editableColors));
      widget.onPaletteNeedsSave?.call();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couleur "${colorTitle}" supprimée.'), duration: const Duration(seconds: 1)));
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex >= _editableColors.length) return;
    setState(() {
      if (newIndex > _editableColors.length) {
        newIndex = _editableColors.length;
      }
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final ColorData item = _editableColors.removeAt(oldIndex);
      _editableColors.insert(newIndex, item);
      widget.onColorsChanged(List.from(_editableColors));
      widget.onPaletteNeedsSave?.call();
    });
  }

  @override
  void dispose() {
    _paletteNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canShowAddButtonInList = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showNameEditor)
          TextFormField(
            controller: _paletteNameController,
            decoration: const InputDecoration(labelText: 'Nom de la palette', hintText: 'Ex: Ma palette de travail', border: OutlineInputBorder()),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le nom de la palette ne peut pas être vide.';
              }
              if (value.length > 50) return 'Le nom ne doit pas dépasser 50 caractères.';
              return null;
            },
          ),
        if (widget.showNameEditor) const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Couleurs (${_editableColors.length} / $MAX_COLORS_IN_PALETTE_EDITOR) :', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                if (widget.onDeleteAllColorsRequested != null && _editableColors.isNotEmpty)
                  Tooltip(
                    message: "Supprimer toutes les couleurs",
                    child: IconButton(icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error), onPressed: _handleDeleteAllColors),
                  ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  tooltip: _isGridView ? "Afficher en liste" : "Afficher en grille",
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_editableColors.isEmpty && !canShowAddButtonInList)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Center(child: Text("La palette est vide et a atteint le nombre maximum de couleurs.", textAlign: TextAlign.center)))
        else if (_editableColors.isEmpty && canShowAddButtonInList)
          _isGridView ? _buildGridView() : _buildListView()
        else
          _isGridView ? _buildGridView() : _buildListView(),
      ],
    );
  }

  Widget _buildAddButtonCardGrid() {
    return Card(
      key: const ValueKey('add_new_color_grid_card'),
      elevation: 2.0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5)),
      child: InkWell(
        onTap: () => _showEditColorDialog(),
        borderRadius: BorderRadius.circular(10.0),
        child: Center(child: Icon(Icons.add_circle_outline, size: 30.0, color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  Widget _buildAddButtonListTile() {
    return Card(
      key: const ValueKey('add_new_color_list_card'),
      elevation: 1.0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: ListTile(
        leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 28),
        title: Text("Ajouter une nouvelle couleur/dégradé", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
        onTap: () => _showEditColorDialog(),
        contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      ),
    );
  }

  Widget _buildGridView() {
    final screenWidth = MediaQuery.of(context).size.width;
    int gridCrossAxisCount;
    if (screenWidth < 350)
      gridCrossAxisCount = 3;
    else if (screenWidth < 450)
      gridCrossAxisCount = 4;
    else if (screenWidth < 600)
      gridCrossAxisCount = 5;
    else if (screenWidth < 800)
      gridCrossAxisCount = 6;
    else
      gridCrossAxisCount = 7;

    double fontSize = 11.0;
    if (gridCrossAxisCount > 5) fontSize = 9.0;

    bool canAddMore = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;
    int itemCount = _editableColors.length + (canAddMore ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 5),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, crossAxisSpacing: 8.0, mainAxisSpacing: 8.0, childAspectRatio: 1.0),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (canAddMore && index == _editableColors.length) {
          return _buildAddButtonCardGrid();
        }
        final colorData = _editableColors[index];
        final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
        return Card(
          key: ValueKey(colorData.paletteElementId),
          color: colorData.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          elevation: 2.0,
          child: InkWell(
            onTap: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: index),
            borderRadius: BorderRadius.circular(10.0),
            child: Stack(
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
                Positioned(top: 4, right: 4, child: Icon(Icons.edit_note_outlined, size: 16, color: textColor.withOpacity(0.7))),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    bool canAddMore = _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR;

    List<Widget> children =
    _editableColors.asMap().entries.map((entry) {
      int idx = entry.key;
      ColorData colorData = entry.value;
      final Color textColorOnCard = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

      return Card(
        key: ValueKey(colorData.paletteElementId),
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: colorData.color,
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2), child: Text((idx + 1).toString(), style: TextStyle(color: textColorOnCard, fontWeight: FontWeight.bold))),
          title: Text(colorData.title, style: TextStyle(color: textColorOnCard, fontWeight: FontWeight.w500)),
          subtitle: Text(colorData.hexCode.toUpperCase(), style: TextStyle(color: textColorOnCard.withOpacity(0.85))),
          onTap: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: idx),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_outlined, size: 20, color: textColorOnCard.withOpacity(0.7)),
              const SizedBox(width: 8),
              ReorderableDragStartListener(index: idx, child: Icon(Icons.drag_handle_outlined, color: textColorOnCard.withOpacity(0.9))),
            ],
          ),
        ),
      );
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_editableColors.isNotEmpty) ReorderableListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), onReorder: _onReorder, children: children),
        if (canAddMore) _buildAddButtonListTile(),
      ],
    );
  }
}
