import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../providers/active_journal_provider.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
const _uuid = Uuid();

const int MIN_COLORS_IN_PALETTE = 1;
const int MAX_COLORS_IN_PALETTE = 10;

class EditPaletteModelPage extends StatefulWidget {
  final PaletteModel? paletteModelToEdit;
  final Journal? journalToUpdatePaletteFor;

  EditPaletteModelPage({Key? key, this.paletteModelToEdit, this.journalToUpdatePaletteFor}) : super(key: key);

  @override
  _EditPaletteModelPageState createState() => _EditPaletteModelPageState();
}

class _EditPaletteModelPageState extends State<EditPaletteModelPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _modelNameController;
  late List<ColorData> _currentColors;
  bool _isEditingModel = false;
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.paletteModelToEdit != null) {
      _isEditingModel = true;
      _modelNameController = TextEditingController(text: widget.paletteModelToEdit!.name);
      _currentColors = widget.paletteModelToEdit!.colors.map((c) => c.copyWith()).toList();
    } else if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false;
      _modelNameController = TextEditingController(text: widget.journalToUpdatePaletteFor!.palette.name);
      _currentColors = widget.journalToUpdatePaletteFor!.palette.colors.map((c) => c.copyWith()).toList();
    } else {
      _isEditingModel = true;
      _modelNameController = TextEditingController();
      _currentColors = [
        ColorData(title: 'Couleur 1', hexCode: 'FF0000', paletteElementId: _uuid.v4()),
      ];
    }
  }

  @override
  void dispose() {
    _modelNameController.dispose();
    super.dispose();
  }

  void _addColor() {
    if (_currentColors.length >= MAX_COLORS_IN_PALETTE) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vous avez atteint le nombre maximum de $MAX_COLORS_IN_PALETTE couleurs.'))
      );
      return;
    }
    setState(() {
      _currentColors.add(ColorData(
        title: 'Nouvelle Couleur ${_currentColors.length + 1}',
        hexCode: '808080',
        paletteElementId: _uuid.v4(),
      ));
    });
  }

  void _removeColor(String paletteElementIdToRemove) async {
    if (_currentColors.length <= MIN_COLORS_IN_PALETTE) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une palette doit contenir au moins $MIN_COLORS_IN_PALETTE couleur(s).'))
      );
      return;
    }

    if (_userId == null) return;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    bool isUsed = false;

    if (!_isEditingModel && widget.journalToUpdatePaletteFor != null) {
      try {
        isUsed = await firestoreService.isPaletteElementUsedInNotes(
            widget.journalToUpdatePaletteFor!.id,
            paletteElementIdToRemove
        );
      } catch (e) {
        _loggerPage.e("Erreur vérification utilisation couleur: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur vérification utilisation couleur: ${e.toString()}'))
          );
        }
        return;
      }
    }

    if (isUsed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cette couleur est utilisée dans des notes et ne peut être supprimée.'))
        );
      }
      return;
    }

    setState(() {
      _currentColors.removeWhere((color) => color.paletteElementId == paletteElementIdToRemove);
    });
  }

  void _editColor(ColorData colorToEdit) {
    Color pickerColor = colorToEdit.color;
    TextEditingController titleController = TextEditingController(text: colorToEdit.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier la couleur'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Nom de la couleur'),
                autofocus: true,
              ),
              SizedBox(height: 20),
              ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) => pickerColor = color,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Sauvegarder'),
            onPressed: () {
              setState(() {
                final index = _currentColors.indexWhere((c) => c.paletteElementId == colorToEdit.paletteElementId);
                if (index != -1) {
                  _currentColors[index] = _currentColors[index].copyWith(
                    title: titleController.text.trim(),
                    hexCode: pickerColor.value.toRadixString(16).substring(2).toUpperCase(),
                  );
                }
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _savePalette() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_currentColors.length < MIN_COLORS_IN_PALETTE || _currentColors.length > MAX_COLORS_IN_PALETTE) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("La palette doit contenir entre $MIN_COLORS_IN_PALETTE et $MAX_COLORS_IN_PALETTE couleurs.")));
      return;
    }

    setState(() { _isLoading = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
    final String paletteName = _modelNameController.text.trim();

    try {
      if (_isEditingModel) {
        if (widget.paletteModelToEdit == null) {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(paletteName, _userId!);
          if (nameExists) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle de palette avec ce nom existe déjà.")));
            setState(() { _isLoading = false; });
            return;
          }
          final newModel = PaletteModel(
            name: paletteName,
            colors: _currentColors,
            userId: _userId!,
            isPredefined: false,
          );
          await firestoreService.createPaletteModel(newModel);
          _loggerPage.i("Nouveau modèle de palette créé: ${newModel.name}");
        } else {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(paletteName, _userId!, excludeId: widget.paletteModelToEdit!.id);
          if (nameExists) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un autre modèle de palette avec ce nom existe déjà.")));
            setState(() { _isLoading = false; });
            return;
          }
          final updatedModel = widget.paletteModelToEdit!.copyWith(
            name: paletteName,
            colors: _currentColors,
          );
          await firestoreService.updatePaletteModel(updatedModel);
          _loggerPage.i("Modèle de palette mis à jour: ${updatedModel.name}");
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Modèle de palette sauvegardé.")));

      } else if (widget.journalToUpdatePaletteFor != null) {
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = Palette(
          id: currentJournal.palette.id,
          name: paletteName,
          colors: _currentColors,
          isPredefined: false,
          userId: currentJournal.userId,
        );

        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

        if (activeJournalNotifier.activeJournalId == currentJournal.id && _userId != null) {
          await activeJournalNotifier.setActiveJournal(currentJournal.id, _userId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Palette du journal sauvegardée.")));
      }
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      _loggerPage.e("Erreur sauvegarde palette: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}")));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle = _isEditingModel
        ? (widget.paletteModelToEdit == null ? 'Créer un modèle de palette' : 'Modifier le modèle')
        : (widget.journalToUpdatePaletteFor != null ? 'Modifier la palette de "${widget.journalToUpdatePaletteFor!.name}"' : 'Modifier la palette');

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _modelNameController,
                decoration: InputDecoration(labelText: _isEditingModel ? 'Nom du modèle' : 'Nom de la palette'),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Veuillez entrer un nom.';
                  if (value.length > 50) return 'Le nom ne doit pas dépasser 50 caractères.';
                  return null;
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Couleurs (${_currentColors.length}) :', style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    icon: Icon(Icons.add_circle_outline),
                    label: Text('Ajouter'),
                    onPressed: _currentColors.length < MAX_COLORS_IN_PALETTE ? _addColor : null,
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (_currentColors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical:16.0),
                  child: Center(child: Text("Aucune couleur. Cliquez sur 'Ajouter' pour commencer.", textAlign: TextAlign.center,)),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _currentColors.length,
                  itemBuilder: (context, index) {
                    final colorData = _currentColors[index];
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
                              onPressed: () => _editColor(colorData),
                              tooltip: "Modifier la couleur",
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                              onPressed: _currentColors.length > MIN_COLORS_IN_PALETTE
                                  ? () => _removeColor(colorData.paletteElementId)
                                  : null,
                              tooltip: "Supprimer la couleur",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final ColorData item = _currentColors.removeAt(oldIndex);
                      _currentColors.insert(newIndex, item);
                    });
                  },
                ),
              SizedBox(height: 12),
              SizedBox(height: 30),
              ElevatedButton.icon(
                icon: Icon(Icons.save_alt_outlined),
                onPressed: _savePalette,
                label: Text('Sauvegarder la palette'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
