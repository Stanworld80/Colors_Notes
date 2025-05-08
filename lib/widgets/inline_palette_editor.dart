// lib/widgets/inline_palette_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/color_data.dart';

final _logger = Logger(printer: PrettyPrinter(methodCount: 1, printTime: false));
const _uuid = Uuid();


int MIN_COLORS_IN_PALETTE_PREVIEW = 3; // Plus flexible pour la pré-création
int MAX_COLORS_IN_PALETTE_PREVIEW = 48;

class InlinePaletteEditorWidget extends StatefulWidget {


  final String initialPaletteName;
  final List<ColorData> initialColors;
  final Function(String newName) onPaletteNameChanged;
  final Function(List<ColorData> newColors) onColorsChanged;
  // final String? userId; // Pourrait être utile pour des validations futures spécifiques à l'utilisateur

  const InlinePaletteEditorWidget({
    Key? key,
    required this.initialPaletteName,
    required this.initialColors,
    required this.onPaletteNameChanged,
    required this.onColorsChanged,
    // this.userId,
  }) : super(key: key);

  @override
  _InlinePaletteEditorWidgetState createState() => _InlinePaletteEditorWidgetState();
}

class _InlinePaletteEditorWidgetState extends State<InlinePaletteEditorWidget> {
  late TextEditingController _paletteNameController;
  late List<ColorData> _editableColors;
  bool _isGridView = true; // Default to grid view

  @override
  void initState() {
    super.initState();
    _paletteNameController = TextEditingController(text: widget.initialPaletteName);
    // Créer une copie profonde pour l'édition locale afin de ne pas muter la liste parente directement
    // sauf via le callback onColorsChanged. Les IDs sont déjà uniques grâce à la page CreateJournalPage.
    _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();

    _paletteNameController.addListener(() {
      widget.onPaletteNameChanged(_paletteNameController.text);
    });
  }

  @override
  void didUpdateWidget(covariant InlinePaletteEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si le nom initial change de l'extérieur, mettre à jour le contrôleur
    if (widget.initialPaletteName != oldWidget.initialPaletteName &&
        widget.initialPaletteName != _paletteNameController.text) {
      _paletteNameController.text = widget.initialPaletteName;
    }
    // Si la liste de couleurs initiale change radicalement de l'extérieur (ex: changement de source de palette)
    // il faut reconstruire _editableColors. Pour cela, il est préférable de donner une Key au widget parent
    // pour forcer la reconstruction complète de cet éditeur si la source change.
    // Cependant, pour des mises à jour moins drastiques, on peut comparer.
    // Ici, on suppose que la Key gère les changements majeurs de source.
    // Si seulement le contenu des couleurs change mais pas la référence de la liste :
    if (!listEquals(_editableColors, widget.initialColors)) {
      _editableColors = widget.initialColors.map((c) => c.copyWith()).toList();
    }
  }

  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) { // This might need deep equality for ColorData if not handled by copyWith/Equatable
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
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Nom de la couleur'),
                    autofocus: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le titre ne peut pas être vide.';
                      }
                      final newTitleLower = value.trim().toLowerCase();
                      if (_editableColors.any((c) =>
                      c.title.toLowerCase() == newTitleLower &&
                          (isAdding || c.paletteElementId != existingColorData!.paletteElementId))) {
                        return 'Ce titre de couleur existe déjà.';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
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
          actions: [
            TextButton(
              child: Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(isAdding ? 'Ajouter' : 'Sauvegarder'),
              onPressed: () {
                if (!dialogFormKey.currentState!.validate()) return;

                final String newTitle = titleController.text.trim();
                final String newHexCode = '#${pickerColor.value.toRadixString(16).substring(2).toUpperCase()}';

                if (_editableColors.any((c) =>
                c.hexCode.toUpperCase() == newHexCode.toUpperCase() &&
                    (isAdding || c.paletteElementId != existingColorData!.paletteElementId))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cette couleur existe déjà.'), backgroundColor: Colors.red),
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
                  widget.onColorsChanged(List.from(_editableColors)); // Notifier le parent
                });
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _removeColor(int index) {
    if (_editableColors.length <= MIN_COLORS_IN_PALETTE_PREVIEW) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La palette doit contenir au moins ${MIN_COLORS_IN_PALETTE_PREVIEW + 1} couleur(s) pour en supprimer une.')),
      );
      return;
    }
    setState(() {
      _editableColors.removeAt(index);
      widget.onColorsChanged(List.from(_editableColors)); // Notifier le parent
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final ColorData item = _editableColors.removeAt(oldIndex);
      _editableColors.insert(newIndex, item);
      widget.onColorsChanged(List.from(_editableColors)); // Notifier le parent
    });
  }

  @override
  void dispose() {
    _paletteNameController.removeListener(() {
      widget.onPaletteNameChanged(_paletteNameController.text);
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
          decoration: InputDecoration(
            labelText: 'Nom de la palette en préparation',
            hintText: 'Ex: Ma superbe palette',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le nom de la palette ne peut pas être vide.';
            }
            if (value.length > 50) return 'Le nom ne doit pas dépasser 50 caractères.';
            return null;
          },
        ),
        SizedBox(height: 16),
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
                  icon: Icon(Icons.add_circle_outline),
                  tooltip: 'Ajouter une couleur',
                  onPressed: _editableColors.length < MAX_COLORS_IN_PALETTE_PREVIEW
                      ? () => _showEditColorDialog()
                      : null, // Désactiver si max atteint
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        if (_editableColors.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text("Aucune couleur. Cliquez sur '+' pour ajouter.", textAlign: TextAlign.center)),
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
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 5),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridCrossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0, // Carrés
      ),
      itemCount: _editableColors.length,
      itemBuilder: (context, index) {
        final colorData = _editableColors[index];
        final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
        return Card(
          key: ValueKey(colorData.paletteElementId),
          color: colorData.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          elevation: 3.0,
          child: InkWell(
            onTap: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: index),
            borderRadius: BorderRadius.circular(10.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    colorData.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: fontSize, color: textColor, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: textColor.withOpacity(0.7), size: 18),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    tooltip: "Supprimer '${colorData.title}'",
                    onPressed: () => _removeColor(index),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _editableColors.length,
      itemBuilder: (context, index) {
        final colorData = _editableColors[index];
        return Card(
          key: ValueKey(colorData.paletteElementId),
          margin: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: colorData.color, radius: 20),
            title: Text(colorData.title),
            subtitle: Text(colorData.hexCode.toUpperCase()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _showEditColorDialog(existingColorData: colorData, existingColorIndex: index),
                  tooltip: "Modifier la couleur",
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: () => _removeColor(index),
                  tooltip: "Supprimer la couleur",
                ),
              ],
            ),
          ),
        );
      },
      onReorder: _onReorder,
    );
  }
}
