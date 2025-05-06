// lib/screens/edit_palette_model_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';
import '../services/firestore_service.dart';

class EditPaletteModelPage extends StatefulWidget {
  final PaletteModel? existingPaletteModel;
  final Journal? existingJournalInstance;

  const EditPaletteModelPage({Key? key, this.existingPaletteModel, this.existingJournalInstance})
      : assert(existingPaletteModel == null || existingJournalInstance == null, 'Cannot edit both a model and an instance at the same time.'),
        super(key: key);

  @override
  _EditPaletteModelPageState createState() => _EditPaletteModelPageState();
}

class _EditPaletteModelPageState extends State<EditPaletteModelPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late List<ColorData> _currentColors;
  bool _isSaving = false;

  bool get _isEditingModel => widget.existingPaletteModel != null;
  bool get _isEditingInstance => widget.existingJournalInstance != null;

  @override
  void initState() {
    super.initState();
    if (_isEditingModel) {
      _nameController = TextEditingController(text: widget.existingPaletteModel!.name);
      _currentColors = widget.existingPaletteModel!.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList();
    } else if (_isEditingInstance) {
      _nameController = TextEditingController(text: widget.existingJournalInstance!.embeddedPaletteInstance.name);
      _currentColors = widget.existingJournalInstance!.embeddedPaletteInstance.colors.map((c) =>
          ColorData(id: c.paletteElementId, title: c.title, hexValue: c.hexValue)
      ).toList();
    } else {
      _nameController = TextEditingController();
      _currentColors = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _safeParseColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('FF');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) { return Colors.grey; }
  }

  String _colorToHex(Color color) {
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _showColorEditDialog({ColorData? colorToEdit, int? editIndex}) {
    final bool isEditingColor = colorToEdit != null && editIndex != null;
    Color pickerColor = colorToEdit != null ? _safeParseColor(colorToEdit.hexValue) : Colors.blue;
    Color currentColor = pickerColor;
    String initialTitle = colorToEdit?.title ?? '';
    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final String? existingId = colorToEdit?.paletteElementId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isEditingColor ? 'Modifier la Couleur' : 'Ajouter une Couleur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Titre de la couleur (unique)'), textCapitalization: TextCapitalization.sentences),
                const SizedBox(height: 20),
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (Color color) { currentColor = color; },
                  colorPickerWidth: 300.0,
                  pickerAreaHeightPercent: 0.7,
                  enableAlpha: false,
                  displayThumbColor: true,
                  paletteType: PaletteType.hsvWithSaturation,
                  labelTypes: const [],
                  pickerAreaBorderRadius: const BorderRadius.all(Radius.circular(8.0)),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () async {
                final String newTitle = titleController.text.trim();
                final String newHexValue = _colorToHex(currentColor);

                if (newTitle.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Le titre ne peut pas être vide.'), backgroundColor: Colors.orange));
                  return;
                }

                int titleIndex = _currentColors.indexWhere((c) => c.title.toLowerCase() == newTitle.toLowerCase());
                bool titleExists = titleIndex != -1 && titleIndex != editIndex;
                int colorIndex = _currentColors.indexWhere((c) => c.hexValue.toUpperCase() == newHexValue.toUpperCase());
                bool colorExists = colorIndex != -1 && colorIndex != editIndex;

                if (titleExists) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Ce titre de couleur existe déjà.'), backgroundColor: Colors.orange));
                  return;
                }
                if (colorExists) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Cette couleur existe déjà.'), backgroundColor: Colors.orange));
                  return;
                }

                List<ColorData> updatedColors = List.from(_currentColors);
                final newColorData = ColorData(
                    id: existingId,
                    title: newTitle,
                    hexValue: newHexValue
                );

                if (isEditingColor) {
                  updatedColors[editIndex] = newColorData;
                } else {
                  updatedColors.add(newColorData);
                }

                if (_isEditingInstance) {
                  bool success = await _saveInstancePaletteUpdate(updatedColors);
                  if (success && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } else {
                  setState(() { _currentColors = updatedColors; });
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _validatePaletteModel() async {
    final userId = context.read<User?>()?.uid;
    final fs = context.read<FirestoreService>();
    final messenger = ScaffoldMessenger.of(context);

    if (userId == null) return false;
    if (!_formKey.currentState!.validate()) return false;
    if (_currentColors.length < PaletteModel.minColors || _currentColors.length > PaletteModel.maxColors) {
      messenger.showSnackBar(SnackBar(content: Text('La palette doit contenir entre ${PaletteModel.minColors} et ${PaletteModel.maxColors} couleurs.'), backgroundColor: Colors.orange));
      return false;
    }
    final String name = _nameController.text.trim();
    bool needsNameCheck = !_isEditingModel || (widget.existingPaletteModel?.name != name);
    if (needsNameCheck) {
      bool nameExists = await fs.checkPaletteModelNameExists(userId, name, modelIdToExclude: _isEditingModel ? widget.existingPaletteModel!.id : null);
      if (nameExists) {
        messenger.showSnackBar(const SnackBar(content: Text('Un modèle de palette avec ce nom existe déjà.'), backgroundColor: Colors.orange));
        return false;
      }
    }
    final Set<String> titles = {}; final Set<String> hexValues = {};
    for (final colorData in _currentColors) {
      if (!titles.add(colorData.title.toLowerCase()) || !hexValues.add(colorData.hexValue.toUpperCase())) {
        messenger.showSnackBar(const SnackBar(content: Text('Erreur interne : Chaque titre et chaque couleur doivent être uniques.'), backgroundColor: Colors.red));
        return false;
      }
    }
    return true;
  }

  Future<bool> _saveInstancePaletteUpdate(List<ColorData> colorsToSave) async {
    if (!_isEditingInstance) return false;
    final journalId = widget.existingJournalInstance!.id;
    final userId = context.read<User?>()?.uid;
    final firestoreService = context.read<FirestoreService>();
    final activeJournalNotifier = context.read<ActiveJournalNotifier>();
    final messenger = ScaffoldMessenger.of(context);

    if (userId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Erreur: Utilisateur non trouvé.'), backgroundColor: Colors.red)); return false;
    }
    if (colorsToSave.length < PaletteModel.minColors || colorsToSave.length > PaletteModel.maxColors) {
      messenger.showSnackBar(SnackBar(content: Text('La palette doit contenir entre ${PaletteModel.minColors} et ${PaletteModel.maxColors} couleurs.'), backgroundColor: Colors.orange)); return false;
    }
    setState(() { _isSaving = true; });
    try {
      final String instancePaletteName = widget.existingJournalInstance!.embeddedPaletteInstance.name;
      final colorsWithEnsuredIds = colorsToSave.map((c) =>
          ColorData(id: c.paletteElementId, title: c.title, hexValue: c.hexValue)
      ).toList();
      final updatedPaletteInstance = Palette(name: instancePaletteName, colors: colorsWithEnsuredIds);

      await firestoreService.updateJournalPaletteInstance(journalId, updatedPaletteInstance);
      setState(() { _currentColors = colorsWithEnsuredIds; });
      final updatedJournal = Journal(id: journalId, name: widget.existingJournalInstance!.name, userId: userId, embeddedPaletteInstance: updatedPaletteInstance);
      activeJournalNotifier.setActiveJournal(updatedJournal);
      print("Instance palette saved successfully."); return true;
    } catch (e) {
      print("Error saving instance palette update: $e");
      messenger.showSnackBar(SnackBar(content: Text('Erreur sauvegarde: $e'), backgroundColor: Colors.red)); return false;
    } finally {
      if (mounted) { setState(() { _isSaving = false; }); }
    }
  }

  Future<void> _savePaletteModel() async {
    if (_isEditingInstance) return;
    final navigator = Navigator.of(context); final messenger = ScaffoldMessenger.of(context);
    final firestoreService = context.read<FirestoreService>(); final userId = context.read<User?>()?.uid;
    setState(() { _isSaving = true; });
    if (!await _validatePaletteModel()) { setState(() { _isSaving = false; }); return; }
    if (userId == null) { setState(() { _isSaving = false; }); messenger.showSnackBar(const SnackBar(content: Text('Erreur: Utilisateur non trouvé.'), backgroundColor: Colors.red)); return; }
    final String name = _nameController.text.trim();
    final List<ColorData> colorsToSave = _currentColors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList();
    try {
      if (_isEditingModel) {
        await firestoreService.updatePaletteModel(widget.existingPaletteModel!.id, name, colorsToSave);
        messenger.showSnackBar(const SnackBar(content: Text('Modèle mis à jour.')));
      } else {
        final newModel = PaletteModel(id: '', userId: userId, name: name, colors: colorsToSave);
        await firestoreService.createPaletteModel(newModel);
        messenger.showSnackBar(const SnackBar(content: Text('Modèle créé.')));
      }
      navigator.pop();
    } catch (e) { print("Error saving palette model: $e"); messenger.showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) { setState(() { _isSaving = false; }); } }
  }

  Future<void> _deleteColor(int index) async {
    final colorToDelete = _currentColors[index];
    final messenger = ScaffoldMessenger.of(context);
    final firestoreService = context.read<FirestoreService>();

    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Confirmer la suppression'),
      content: Text('Supprimer la couleur "${colorToDelete.title}" ?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
        TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
      ],
    ));
    if (confirm != true) return;

    if (_isEditingInstance) {
      setState(() { _isSaving = true; });
      bool isUsed = false;
      try {
        isUsed = await firestoreService.isPaletteElementUsedInNotes(
            widget.existingJournalInstance!.id,
            colorToDelete.paletteElementId
        );
      } catch (e) {
        print("Error checking color usage: $e");
        messenger.showSnackBar(SnackBar(content: Text('Erreur vérification utilisation (vérifiez index): $e'), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
        setState(() { _isSaving = false; });
        return;
      }
      setState(() { _isSaving = false; });

      if (isUsed) {
        messenger.showSnackBar(SnackBar(
            content: Text('Impossible de supprimer "${colorToDelete.title}" car elle est utilisée par des notes.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4)
        ));
        return;
      }
    }

    List<ColorData> updatedColors = List.from(_currentColors);
    updatedColors.removeAt(index);

    if (_isEditingInstance) {
      await _saveInstancePaletteUpdate(updatedColors);
    } else {
      setState(() { _currentColors = updatedColors; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditingInstance ? 'Modifier Palette (${widget.existingJournalInstance!.name})' : (_isEditingModel ? 'Modifier Modèle' : 'Nouveau Modèle'),
        ),
        actions: [
          if (!_isEditingInstance)
            IconButton(
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
              tooltip: 'Enregistrer le modèle',
              onPressed: _isSaving ? null : _savePaletteModel,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditingInstance)
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: _isEditingModel ? 'Nom du modèle' : 'Nom du nouveau modèle', border: const OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Veuillez entrer un nom.' : null,
                ),
              if (!_isEditingInstance) const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Couleurs (${_currentColors.length})", style: Theme.of(context).textTheme.titleMedium),
                  if (_currentColors.length < PaletteModel.maxColors)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      tooltip: 'Ajouter une couleur',
                      onPressed: _isSaving ? null : () => _showColorEditDialog(),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isSaving) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Center(child: LinearProgressIndicator())),
              Expanded(
                child: _currentColors.isEmpty
                    ? const Center(child: Text("Ajoutez des couleurs à votre palette."))
                    : ListView.builder(
                  itemCount: _currentColors.length,
                  itemBuilder: (context, index) {
                    final colorData = _currentColors[index];
                    final color = _safeParseColor(colorData.hexValue);
                    return ListTile(
                      leading: Container(width: 24, height: 24, color: color, margin: const EdgeInsets.symmetric(vertical: 8)),
                      title: Text(colorData.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Modifier couleur',
                            onPressed: _isSaving ? null : () => _showColorEditDialog(colorToEdit: colorData, editIndex: index),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: _currentColors.length > PaletteModel.minColors ? Colors.redAccent : Colors.grey),
                            tooltip: _currentColors.length > PaletteModel.minColors ? 'Supprimer couleur' : 'Minimum ${PaletteModel.minColors} couleurs requises',
                            onPressed: (_isSaving || _currentColors.length <= PaletteModel.minColors) ? null : () => _deleteColor(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}