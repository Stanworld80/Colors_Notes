import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/agenda.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';

class EditPaletteModelPage extends StatefulWidget {
  final PaletteModel? existingPaletteModel; // Pour édition de modèle
  final Agenda? existingAgendaInstance; // Pour édition d'instance

  // Vérifier qu'un seul des deux est fourni (ou aucun pour création modèle)
  const EditPaletteModelPage({Key? key, this.existingPaletteModel, this.existingAgendaInstance})
    : assert(existingPaletteModel == null || existingAgendaInstance == null, 'Cannot edit both a model and an instance at the same time.'),
      super(key: key);

  @override
  _EditPaletteModelPageState createState() => _EditPaletteModelPageState();
}

class _EditPaletteModelPageState extends State<EditPaletteModelPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late List<ColorData> _currentColors;
  bool _isSaving = false;

  bool get _isEditing => widget.existingPaletteModel != null;

  bool get _isEditingModel => widget.existingPaletteModel != null;

  bool get _isEditingInstance => widget.existingAgendaInstance != null;

  @override
  @override
  void initState() {
    super.initState();
    if (_isEditingModel) {
      _nameController = TextEditingController(text: widget.existingPaletteModel!.name);
      _currentColors = widget.existingPaletteModel!.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList();
    } else if (_isEditingInstance) {
      // Utiliser le nom de la palette de l'instance
      _nameController = TextEditingController(text: widget.existingAgendaInstance!.embeddedPaletteInstance.name);
      _currentColors = widget.existingAgendaInstance!.embeddedPaletteInstance.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList();
    } else {
      // Mode Création de modèle
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
    } catch (e) {
      return Colors.grey;
    }
  }

  String _colorToHex(Color color) {
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _showColorEditDialog({ColorData? colorToEdit, int? editIndex}) {
    final bool isEditingColor = colorToEdit != null && editIndex != null;
    Color pickerColor = colorToEdit != null ? _safeParseColor(colorToEdit.hexValue) : Colors.blue;
    Color currentColor = pickerColor;

    String initialTitle = colorToEdit?.title ?? _colorToHex(pickerColor);
    final TextEditingController titleController = TextEditingController(text: initialTitle);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isEditingColor ? 'Modifier la Couleur' : 'Ajouter une Couleur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: titleController, autofocus: true, decoration: const InputDecoration(labelText: 'Titre de la couleur'), textCapitalization: TextCapitalization.sentences),
                const SizedBox(height: 20),
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (Color color) {
                    currentColor = color;
                  },
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
              onPressed: () {
                final String title = titleController.text.trim();
                final String hexValue = '#${(currentColor.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

                if (title.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Le titre ne peut pas être vide.'), backgroundColor: Colors.orange));
                  return;
                }

                int titleIndex = _currentColors.indexWhere((c) => c.title.toLowerCase() == title.toLowerCase());
                bool titleExists = titleIndex != -1 && titleIndex != editIndex;

                int colorIndex = _currentColors.indexWhere((c) => c.hexValue.toUpperCase() == hexValue.toUpperCase());
                bool colorExists = colorIndex != -1 && colorIndex != editIndex;

                if (titleExists) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Ce titre de couleur existe déjà.'), backgroundColor: Colors.orange));
                  return;
                }
                if (colorExists) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Cette couleur existe déjà.'), backgroundColor: Colors.orange));
                  return;
                }

                setState(() {
                  if (isEditingColor) {
                    _currentColors[editIndex] = ColorData(title: title, hexValue: hexValue);
                  } else {
                    _currentColors.add(ColorData(title: title, hexValue: hexValue));
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

  Future<bool> _validatePalette() async {
    final userId = context.read<User?>()?.uid;
    final fs = context.read<FirestoreService>();
    final messenger = ScaffoldMessenger.of(context); // Capture context sensitive widget

    if (userId == null) return false;

    if (!_isEditingInstance && !_formKey.currentState!.validate()) {
      return false;
    }

    if (_currentColors.length < PaletteModel.minColors || _currentColors.length > PaletteModel.maxColors) {
      messenger.showSnackBar(SnackBar(content: Text('La palette doit contenir entre ${PaletteModel.minColors} et ${PaletteModel.maxColors} couleurs.'), backgroundColor: Colors.orange));
      return false;
    }

    // 3. Valider Unicité Nom (SEULEMENT si création/modif de MODÈLE)
    if (!_isEditingInstance) {
      final String name = _nameController.text.trim();
      bool needsNameCheck = !_isEditingModel || (widget.existingPaletteModel?.name != name);
      if (needsNameCheck) {
        bool nameExists = await fs.checkPaletteModelNameExists(
          userId,
          name,
          modelIdToExclude: _isEditingModel ? widget.existingPaletteModel!.id : null,
        );
        if (nameExists) {
          messenger.showSnackBar(const SnackBar(content: Text('Un modèle de palette avec ce nom existe déjà.'), backgroundColor: Colors.orange));
          return false; // Validation échouée
        }
      }
    }

    final Set<String> titles = {};
    final Set<String> hexValues = {};
    for (final colorData in _currentColors) {
      if (!titles.add(colorData.title.toLowerCase()) || !hexValues.add(colorData.hexValue.toUpperCase())) {
        messenger.showSnackBar(const SnackBar(content: Text('Chaque titre et chaque couleur doivent être uniques.'), backgroundColor: Colors.orange));
        return false;
      }
    }
    return true;
  }

  Future<void> _savePalette() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final firestoreService = context.read<FirestoreService>();
    final userId = context.read<User?>()?.uid;
    // Récupérer le notifier pour mettre à jour l'état de l'agenda actif après modif instance
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();

    setState(() {
      _isSaving = true;
    });

    // Utiliser la validation adaptée
    if (!await _validatePalette()) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    if (userId == null) {
      setState(() {
        _isSaving = false;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Erreur: Utilisateur non trouvé.'), backgroundColor: Colors.red));
      return;
    }

    final String name = _nameController.text.trim();
    final List<ColorData> colorsToSave = List.from(_currentColors);

    try {
      if (_isEditingInstance) {
        // --- MISE À JOUR DE L'INSTANCE D'AGENDA ---
        final agendaId = widget.existingAgendaInstance!.id;
        // Créer le nouvel objet Palette instance
        // Si le nom de l'instance n'est pas modifiable, réutiliser l'ancien:
        final String instancePaletteName = widget.existingAgendaInstance!.embeddedPaletteInstance.name;
        final updatedPaletteInstance = Palette(name: instancePaletteName, colors: colorsToSave);

        // Appeler une NOUVELLE méthode du service Firestore
        await firestoreService.updateAgendaPaletteInstance(agendaId, updatedPaletteInstance);

        // Mettre à jour l'état global de l'agenda actif
        final updatedAgenda = Agenda(
          id: agendaId,
          name: widget.existingAgendaInstance!.name, // Le nom de l'agenda ne change pas ici
          userId: userId,
          embeddedPaletteInstance: updatedPaletteInstance, // Mettre la palette à jour
        );
        activeAgendaNotifier.setActiveAgenda(updatedAgenda); // Notifier le changement

        messenger.showSnackBar(const SnackBar(content: Text('Palette de l\'agenda mise à jour.')));
        // --- FIN MISE À JOUR INSTANCE ---
      } else {
        // --- CRÉATION/MISE À JOUR DE MODÈLE (Logique existante) ---
        if (_isEditingModel) {
          await firestoreService.updatePaletteModel(widget.existingPaletteModel!.id, name, colorsToSave);
          messenger.showSnackBar(const SnackBar(content: Text('Modèle mis à jour.')));
        } else {
          final newModel = PaletteModel(id: '', userId: userId, name: name, colors: colorsToSave);
          await firestoreService.createPaletteModel(newModel);
          messenger.showSnackBar(const SnackBar(content: Text('Modèle créé.')));
        }
        // --- FIN GESTION MODÈLE ---
      }
      navigator.pop(); // Revenir en arrière dans tous les cas de succès
    } catch (e) {
      print("Error saving palette model: $e");
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      // Ne pas remettre _isSaving à false ici, le finally s'en charge
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditingInstance
              ? 'Modifier Palette (${widget.existingAgendaInstance!.name})' // Nom de l'agenda
              : (_isEditingModel ? 'Modifier Modèle' : 'Nouveau Modèle'),
        ),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            tooltip: 'Enregistrer',
            onPressed: _isSaving ? null : _savePalette,
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
                  // enabled: !_isEditingInstance, // Optionnel: juste désactiver
                  decoration: InputDecoration(labelText: _isEditingModel ? 'Nom du modèle' : 'Nom du nouveau modèle', border: const OutlineInputBorder()),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Veuillez entrer un nom.' : null,
                ),
              if (!_isEditingInstance) const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Couleurs (${_currentColors.length})", style: Theme.of(context).textTheme.titleMedium),
                  if (_currentColors.length < PaletteModel.maxColors) IconButton.filledTonal(icon: const Icon(Icons.add), tooltip: 'Ajouter une couleur', onPressed: () => _showColorEditDialog()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    _currentColors.length < PaletteModel.minColors && !_isEditing
                        ? Center(child: Text("Ajoutez au moins ${PaletteModel.minColors} couleurs pour pouvoir enregistrer."))
                        : ListView.builder(
                          itemCount: _currentColors.length,
                          itemBuilder: (context, index) {
                            final colorData = _currentColors[index];
                            final color = _safeParseColor(colorData.hexValue);
                            return ListTile(
                              leading: Container(width: 24, height: 24, color: color, margin: const EdgeInsets.symmetric(vertical: 8)),
                              title: Text(colorData.title),
                              //subtitle: Text(colorData.hexValue.toUpperCase()),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    tooltip: 'Modifier couleur',
                                    onPressed: () => _showColorEditDialog(colorToEdit: colorData, editIndex: index),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: _currentColors.length > PaletteModel.minColors ? Colors.redAccent : Colors.grey),
                                    tooltip: _currentColors.length > PaletteModel.minColors ? 'Supprimer couleur' : 'Minimum ${PaletteModel.minColors} couleurs requises',
                                    onPressed:
                                        _currentColors.length > PaletteModel.minColors
                                            ? () {
                                              setState(() {
                                                _currentColors.removeAt(index);
                                              });
                                            }
                                            : null,
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
