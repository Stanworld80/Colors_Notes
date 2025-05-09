// lib/widgets/inline_palette_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/color_data.dart';

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, printTime: false));
const _uuid = Uuid();

const int MIN_COLORS_IN_PALETTE_EDITOR = 1;
const int MAX_COLORS_IN_PALETTE_EDITOR = 48;

class InlinePaletteEditorWidget extends StatefulWidget {
  final String initialPaletteName;
  final List<ColorData> initialColors;
  final Function(String newName) onPaletteNameChanged;
  final Function(List<ColorData> newColors) onColorsChanged;
  final bool isEditingJournalPalette;
  final Future<bool> Function(String paletteElementId)? canDeleteColorCallback;
  final Future<void> Function()? onPaletteNeedsSave; // Nouveau callback pour la sauvegarde automatique

  const InlinePaletteEditorWidget({
    Key? key,
    required this.initialPaletteName,
    required this.initialColors,
    required this.onPaletteNameChanged,
    required this.onColorsChanged,
    this.isEditingJournalPalette = false,
    this.canDeleteColorCallback,
    this.onPaletteNeedsSave, // Ajout du callback
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
      widget.onPaletteNeedsSave?.call(); // Déclenche la sauvegarde après changement de nom
    });
  }

  @override
  void didUpdateWidget(covariant InlinePaletteEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPaletteName != oldWidget.initialPaletteName &&
        widget.initialPaletteName != _paletteNameController.text) {
      _paletteNameController.text = widget.initialPaletteName;
      // Pas besoin de widget.onPaletteNeedsSave?.call() ici car le listener s'en charge déjà
    }
    if (!_listEquals(widget.initialColors, oldWidget.initialColors)) {
      _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();
    }
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] is ColorData && b[i] is ColorData) {
        final colorA = a[i] as ColorData;
        final colorB = b[i] as ColorData;
        if (colorA.paletteElementId != colorB.paletteElementId ||
            colorA.title != colorB.title ||
            colorA.hexCode != colorB.hexCode) {
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
    Color pickerColor = isAdding ? Colors.grey : existingColorData!.color;
    String initialTitle = isAdding ? '' : existingColorData!.title;

    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final GlobalKey<FormState> dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isAdding ? 'Ajouter une couleur' : 'Modifier la couleur'),
          content: SingleChildScrollView(
            child: Form(
              key: dialogFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Nom de la couleur'),
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le titre ne peut pas être vide.';
                      }
                      final newTitleLower = value.trim().toLowerCase();
                      if (_editableColors.any((c) =>
                      c.title.toLowerCase() == newTitleLower &&
                          (isAdding || c.paletteElementId != existingColorData!.paletteElementId))) {
                        return 'Ce titre de couleur existe déjà dans cette palette.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
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
                  if (!isAdding && existingColorData != null && existingColorIndex != null) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    TextButton.icon(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                      label: Text(
                        'Supprimer cette couleur',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final bool? confirmDelete = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext confirmCtx) {
                            return AlertDialog(
                              title: const Text('Confirmer la suppression'),
                              content: Text('Voulez-vous vraiment supprimer la couleur "${existingColorData.title}" ?'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Annuler'),
                                  onPressed: () => Navigator.of(confirmCtx).pop(false),
                                ),
                                TextButton(
                                  child: Text('Supprimer', style: TextStyle(color: Colors.red.shade700)),
                                  onPressed: () => Navigator.of(confirmCtx).pop(true),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmDelete == true) {
                          await _removeColor(existingColorIndex); // Changé pour être async
                        }
                      },
                    ),
                  ]
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: Text(isAdding ? 'Ajouter' : 'Sauvegarder'),
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;

                final String newTitle = titleController.text.trim();
                final String newHexCode = '#${pickerColor.value.toRadixString(16).substring(2).toUpperCase()}';

                if (_editableColors.any((c) =>
                c.hexCode.toUpperCase() == newHexCode.toUpperCase() &&
                    (isAdding || c.paletteElementId != existingColorData!.paletteElementId))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cette couleur (valeur hexadécimale) existe déjà dans cette palette.'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                setState(() {
                  if (isAdding) {
                    _editableColors.add(ColorData(
                      paletteElementId: _uuid.v4(),
                      title: newTitle,
                      hexCode: newHexCode,
                    ));
                  } else if (existingColorIndex != null) {
                    _editableColors[existingColorIndex] = _editableColors[existingColorIndex].copyWith(
                      title: newTitle,
                      hexCode: newHexCode,
                    );
                  }
                  widget.onColorsChanged(List.from(_editableColors));
                  widget.onPaletteNeedsSave?.call(); // Déclenche la sauvegarde
                });
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeColor(int indexToRemove) async { // Changé pour retourner Future<void>
    if (_editableColors.length <= MIN_COLORS_IN_PALETTE_EDITOR && !widget.isEditingJournalPalette) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Un modèle de palette doit contenir au moins $MIN_COLORS_IN_PALETTE_EDITOR couleur(s). Impossible de supprimer.')),
      );
      return;
    }

    if (widget.isEditingJournalPalette && widget.canDeleteColorCallback != null) {
      final colorToDelete = _editableColors[indexToRemove];
      final bool canDelete = await widget.canDeleteColorCallback!(colorToDelete.paletteElementId);
      if (!canDelete) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cette couleur est utilisée dans des notes et ne peut pas être supprimée de ce journal.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _editableColors.removeAt(indexToRemove);
      widget.onColorsChanged(List.from(_editableColors));
      widget.onPaletteNeedsSave?.call(); // Déclenche la sauvegarde
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final ColorData item = _editableColors.removeAt(oldIndex);
      _editableColors.insert(newIndex, item);
      widget.onColorsChanged(List.from(_editableColors));
      widget.onPaletteNeedsSave?.call(); // Déclenche la sauvegarde
    });
  }

  @override
  void dispose() {
    _paletteNameController.removeListener(() { // Assurez-vous que le listener est bien retiré
      // widget.onPaletteNameChanged(_paletteNameController.text); // Déjà géré par le setter
      // widget.onPaletteNeedsSave?.call(); // Déjà géré par le setter
    });
    _paletteNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _paletteNameController,
          decoration: const InputDecoration(
            labelText: 'Nom de la palette en préparation',
            hintText: 'Ex: Ma palette de travail',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le nom de la palette ne peut pas être vide.';
            }
            if (value.length > 50) return 'Le nom ne doit pas dépasser 50 caractères.';
            return null;
          },
          // Le listener dans initState s'occupe déjà d'appeler onPaletteNameChanged et onPaletteNeedsSave
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Couleurs (${_editableColors.length}) :', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  tooltip: _isGridView ? "Afficher en liste" : "Afficher en grille",
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Ajouter une nouvelle couleur',
                  onPressed: _editableColors.length < MAX_COLORS_IN_PALETTE_EDITOR
                      ? () => _showEditColorDialog()
                      : null,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_editableColors.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text("Aucune couleur dans cette palette. Cliquez sur '+' pour commencer.", textAlign: TextAlign.center)),
          )
        else if (_isGridView)
          _buildGridView()
        else
          _buildListView(),
      ],
    );
  }

  Widget _buildGridView() {
    final screenWidth = MediaQuery.of(context).size.width;
    int gridCrossAxisCount;
    if (screenWidth < 350) gridCrossAxisCount = 3;
    else if (screenWidth < 450) gridCrossAxisCount = 4;
    else if (screenWidth < 600) gridCrossAxisCount = 5;
    else if (screenWidth < 800) gridCrossAxisCount = 6;
    else gridCrossAxisCount = 7;

    double fontSize = 11.0;
    if (gridCrossAxisCount > 5) fontSize = 9.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 5),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCrossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0,
      ),
      itemCount: _editableColors.length,
      itemBuilder: (context, index) {
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
            child: Padding(
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
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _editableColors.length,
      itemBuilder: (context, index) {
        final colorData = _editableColors[index];
        return Card(
          key: ValueKey(colorData.paletteElementId),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: colorData.color, radius: 20),
            title: Text(colorData.title),
            subtitle: Text(colorData.hexCode.toUpperCase()),
            onTap: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: index),
          ),
        );
      },
      onReorder: _onReorder,
    );
  }
}
