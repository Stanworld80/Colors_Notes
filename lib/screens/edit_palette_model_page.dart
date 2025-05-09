import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Pas directement utilisé ici pour les PaletteModels

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../providers/active_journal_provider.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
const _uuid = Uuid();

const int MIN_COLORS_IN_PALETTE = 1; // Conforme à SF-PALETTE-04 (minimum 3, mais pour l'édition on peut être plus souple temporairement)
const int MAX_COLORS_IN_PALETTE = 48; // Conforme à SF-PALETTE-04

class EditPaletteModelPage extends StatefulWidget {
  final PaletteModel? paletteModelToEdit;
  final Journal? journalToUpdatePaletteFor; // Pour éditer la palette d'un journal spécifique

  EditPaletteModelPage({Key? key, this.paletteModelToEdit, this.journalToUpdatePaletteFor}) : super(key: key);

  @override
  _EditPaletteModelPageState createState() => _EditPaletteModelPageState();
}

class _EditPaletteModelPageState extends State<EditPaletteModelPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _paletteNameController;
  late List<ColorData> _currentColors;
  bool _isEditingPaletteModel = true; // Par défaut, on édite un modèle
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.journalToUpdatePaletteFor != null) {
      // Mode: Édition de la palette d'un journal existant
      _isEditingPaletteModel = false;
      _paletteNameController = TextEditingController(text: widget.journalToUpdatePaletteFor!.palette.name);
      _currentColors = widget.journalToUpdatePaletteFor!.palette.colors.map((c) => c.copyWith()).toList();
    } else if (widget.paletteModelToEdit != null) {
      // Mode: Édition d'un modèle de palette existant
      _isEditingPaletteModel = true;
      _paletteNameController = TextEditingController(text: widget.paletteModelToEdit!.name);
      _currentColors = widget.paletteModelToEdit!.colors.map((c) => c.copyWith()).toList();
    } else {
      // Mode: Création d'un nouveau modèle de palette
      _isEditingPaletteModel = true;
      _paletteNameController = TextEditingController();
      _currentColors = [
        // ColorData(title: 'Rouge', hexCode: 'FF0000', paletteElementId: _uuid.v4()), // Exemple initial
      ];
    }
  }

  @override
  void dispose() {
    _paletteNameController.dispose();
    super.dispose();
  }

  void _showEditColorDialog({ColorData? existingColorData}) {
    final bool isAdding = existingColorData == null;
    Color pickerColor = isAdding ? Color(0xFF808080) : existingColorData.color; // Gris par défaut pour ajout
    String initialTitle = isAdding ? '' : existingColorData.title; // Laisser vide si ajout

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
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: (color) {
                      pickerColor = color;
                    },
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
                if (!dialogFormKey.currentState!.validate()) {
                  return;
                }

                final String newTitle = titleController.text.trim();
                final String newHexCode = pickerColor.value.toRadixString(16).substring(2).toUpperCase();

                bool titleExists = _currentColors.any((c) =>
                c.title.toLowerCase() == newTitle.toLowerCase() &&
                    (isAdding || c.paletteElementId != existingColorData.paletteElementId));
                if (titleExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ce titre de couleur existe déjà dans cette palette.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                bool colorExists = _currentColors.any((c) =>
                c.hexCode.toUpperCase() == newHexCode.toUpperCase() &&
                    (isAdding || c.paletteElementId != existingColorData.paletteElementId));
                if (colorExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cette couleur existe déjà dans cette palette.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                setState(() {
                  if (isAdding) {
                    _currentColors.add(ColorData(
                      title: newTitle,
                      hexCode: newHexCode,
                      paletteElementId: _uuid.v4(),
                    ));
                  } else {
                    final index = _currentColors.indexWhere((c) => c.paletteElementId == existingColorData.paletteElementId);
                    if (index != -1) {
                      _currentColors[index] = _currentColors[index].copyWith(
                        title: newTitle,
                        hexCode: newHexCode,
                      );
                    }
                  }
                });
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void _removeColor(String paletteElementIdToRemove) async {
    if (_currentColors.length <= MIN_COLORS_IN_PALETTE && _isEditingPaletteModel) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Un modèle de palette doit contenir au moins $MIN_COLORS_IN_PALETTE couleur(s).'))
      );
      return;
    }
    if (_currentColors.length <= 0 && !_isEditingPaletteModel) {
      // Pas de restriction si c'est une instance et qu'on veut la vider
    }


    if (_userId == null) {
      _loggerPage.w("UserID est null, suppression de couleur annulée.");
      return;
    }
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    bool isUsed = false;

    if (!_isEditingPaletteModel && widget.journalToUpdatePaletteFor != null) {
      try {
        setState(() { _isLoading = true; });
        isUsed = await firestoreService.isPaletteElementUsedInNotes(
            widget.journalToUpdatePaletteFor!.id,
            paletteElementIdToRemove
        );
      } catch (e) {
        _loggerPage.e("Erreur vérification utilisation couleur: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur vérification utilisation couleur: ${e.toString()}'), backgroundColor: Colors.red)
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }

    if (isUsed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cette couleur est utilisée dans des notes et ne peut être supprimée de ce journal.'), backgroundColor: Colors.orange)
        );
      }
      return;
    }

    setState(() {
      _currentColors.removeWhere((color) => color.paletteElementId == paletteElementIdToRemove);
    });
  }


  Future<void> _savePalette() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur non identifié."), backgroundColor: Colors.red));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_currentColors.length < MIN_COLORS_IN_PALETTE || _currentColors.length > MAX_COLORS_IN_PALETTE) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("La palette doit contenir entre $MIN_COLORS_IN_PALETTE et $MAX_COLORS_IN_PALETTE couleurs."), backgroundColor: Colors.orange));
      return;
    }

    setState(() { _isLoading = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
    final String paletteName = _paletteNameController.text.trim();

    try {
      if (_isEditingPaletteModel) {
        if (widget.paletteModelToEdit == null) {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(paletteName, _userId!);
          if (nameExists) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle de palette avec ce nom existe déjà."), backgroundColor: Colors.orange));
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
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un autre modèle de palette avec ce nom existe déjà."), backgroundColor: Colors.orange));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Modèle de palette sauvegardé."), backgroundColor: Colors.green));

      } else if (widget.journalToUpdatePaletteFor != null) {
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(
          name: paletteName,
          colors: _currentColors,
        );

        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

        if (activeJournalNotifier.activeJournalId == currentJournal.id && _userId != null) {
          await activeJournalNotifier.setActiveJournal(currentJournal.id, _userId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Palette du journal sauvegardée."), backgroundColor: Colors.green));
      }
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      _loggerPage.e("Erreur sauvegarde palette: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    String pageTitle = _isEditingPaletteModel
        ? (widget.paletteModelToEdit == null ? 'Créer un modèle de palette' : 'Modifier le modèle')
        : (widget.journalToUpdatePaletteFor != null ? 'Modifier la palette de "${widget.journalToUpdatePaletteFor!.name}"' : 'Modifier la palette');

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          if (_isLoading) Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0,))
          else IconButton(icon: Icon(Icons.save_alt_outlined), onPressed: _savePalette, tooltip: "Sauvegarder")
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _paletteNameController,
                decoration: InputDecoration(labelText: _isEditingPaletteModel ? 'Nom du modèle de palette' : 'Nom de la palette du journal'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Veuillez entrer un nom.';
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
                    onPressed: _currentColors.length < MAX_COLORS_IN_PALETTE ? () => _showEditColorDialog() : null,
                    style: _currentColors.length >= MAX_COLORS_IN_PALETTE ? TextButton.styleFrom(foregroundColor: Colors.grey) : null,
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
                              onPressed: () => _showEditColorDialog(existingColorData: colorData),
                              tooltip: "Modifier la couleur",
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                              onPressed: (_isEditingPaletteModel && _currentColors.length <= MIN_COLORS_IN_PALETTE)
                                  ? null
                                  : () => _removeColor(colorData.paletteElementId),
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
            ],
          ),
        ),
      ),
    );
  }
}
