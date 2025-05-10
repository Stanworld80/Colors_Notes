// lib/screens/create_journal_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';
import '../core/predefined_templates.dart';
import '../widgets/inline_palette_editor.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

enum JournalCreationMode { fromPaletteModel, fromExistingJournal }

class CreateJournalPage extends StatefulWidget {
  const CreateJournalPage({Key? key}) : super(key: key);

  @override
  _CreateJournalPageState createState() => _CreateJournalPageState();
}

class _CreateJournalPageState extends State<CreateJournalPage> {
  final _formKey = GlobalKey<FormState>();
  final _journalNameController = TextEditingController();

  JournalCreationMode _creationMode = JournalCreationMode.fromPaletteModel;

  PaletteModel? _selectedPaletteModel;
  List<PaletteModel> _availablePaletteModels = [];

  Journal? _selectedExistingJournal;
  List<Journal> _availableUserJournals = [];

  List<ColorData> _preparedColors = [];
  String _preparedPaletteName = "";

  Key _paletteEditorKey = UniqueKey();

  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    if (_userId == null) {
      _loggerPage.w("UserID est null, impossible de charger les données initiales.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur: Utilisateur non identifié.")));
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final FirestoreService firestoreService = Provider.of<FirestoreService>(context, listen: false);

      final List<PaletteModel> predefinedPalettesList = predefinedPalettes; // Assuming predefinedPalettes is globally available or passed
      final List<PaletteModel> userModels = await firestoreService.getUserPaletteModelsStream(_userId!).first;
      _availablePaletteModels = [...predefinedPalettesList, ...userModels];

      _availableUserJournals = await firestoreService.getJournalsStream(_userId!).first;

      if (_creationMode == JournalCreationMode.fromPaletteModel && _availablePaletteModels.isNotEmpty) {
        _selectedPaletteModel = _availablePaletteModels.first;
        _updatePreparedPaletteFromModel(_selectedPaletteModel);
      } else if (_creationMode == JournalCreationMode.fromExistingJournal && _availableUserJournals.isNotEmpty) {
        _selectedExistingJournal = _availableUserJournals.first;
        _updatePreparedPaletteFromJournal(_selectedExistingJournal);
      } else if (_availablePaletteModels.isEmpty && _availableUserJournals.isNotEmpty) {
        _creationMode = JournalCreationMode.fromExistingJournal;
        _selectedExistingJournal = _availableUserJournals.first;
        _updatePreparedPaletteFromJournal(_selectedExistingJournal);
      } else if (_availablePaletteModels.isNotEmpty) {
        _creationMode = JournalCreationMode.fromPaletteModel;
        _selectedPaletteModel = _availablePaletteModels.first;
        _updatePreparedPaletteFromModel(_selectedPaletteModel);
      } else {
        _preparedPaletteName = "Palette du nouveau journal";
        _preparedColors = [
          // Provide a very basic default if no sources are available
          ColorData(paletteElementId: _uuid.v4(), title: "Couleur 1", hexCode: "#FFC107"), // Amber
          ColorData(paletteElementId: _uuid.v4(), title: "Couleur 2", hexCode: "#4CAF50"), // Green
          ColorData(paletteElementId: _uuid.v4(), title: "Couleur 3", hexCode: "#2196F3"), // Blue
        ];
        _paletteEditorKey = UniqueKey();
      }
    } catch (e, stackTrace) {
      _loggerPage.e("Erreur chargement données initiales: $e", error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur chargement des options: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updatePreparedPaletteFromModel(PaletteModel? model) {
    final journalName = _journalNameController.text.trim();
    if (model == null) {
      _preparedPaletteName = journalName.isNotEmpty ? "Palette de '$journalName'" : "Nouvelle Palette";
      _preparedColors = [];
    } else {
      _preparedPaletteName = journalName.isNotEmpty ? "Palette de '$journalName' (Modèle: ${model.name})" : "Palette (Modèle: ${model.name})";
      _preparedColors = model.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
    }
    _paletteEditorKey = UniqueKey();
    if (mounted) setState(() {});
  }

  void _updatePreparedPaletteFromJournal(Journal? journal) {
    final journalName = _journalNameController.text.trim();
    if (journal == null) {
      _preparedPaletteName = journalName.isNotEmpty ? "Palette de '$journalName'" : "Nouvelle Palette";
      _preparedColors = [];
    } else {
      _preparedPaletteName = journalName.isNotEmpty ? "Palette de '$journalName' (Copiée de ${journal.name})" : "Palette (Copiée de ${journal.name})";
      _preparedColors = journal.palette.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
    }
    _paletteEditorKey = UniqueKey();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _journalNameController.dispose();
    super.dispose();
  }

  Future<void> _createJournal() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final String journalName = _journalNameController.text.trim();
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    // Vérifier si le nom du journal existe déjà pour cet utilisateur
    bool nameExists = await firestoreService.checkJournalNameExists(journalName, _userId!);
    if (nameExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Un journal nommé "$journalName" existe déjà.'), backgroundColor: Colors.orange));
      }
      return; // Arrêter la création
    }

    if (_preparedColors.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La palette en préparation est vide. Veuillez ajouter des couleurs ou choisir une source avec des couleurs.")));
      return;
    }

    // SF-PALETTE-04: Une instance de palette doit contenir entre 3 et 48 couleurs.
    // La constante MIN_COLORS_IN_PALETTE_EDITOR vient de inline_palette_editor.dart
    if (_preparedColors.length < MIN_COLORS_IN_PALETTE_EDITOR || _preparedColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("La palette doit contenir entre ${MIN_COLORS_IN_PALETTE_EDITOR} et ${MAX_COLORS_IN_PALETTE_EDITOR} couleurs.")));
      return;
    }

    if (mounted)
      setState(() {
        _isLoading = true;
      });

    try {
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);

      final String finalPaletteName = _preparedPaletteName.isNotEmpty ? _preparedPaletteName : "Palette de $journalName";

      final Palette newPaletteInstance = Palette(id: _uuid.v4(), name: finalPaletteName, colors: _preparedColors, isPredefined: false, userId: _userId);

      final Journal newJournal = Journal(id: _uuid.v4(), userId: _userId!, name: journalName, palette: newPaletteInstance, createdAt: Timestamp.now(), lastUpdatedAt: Timestamp.now());

      await firestoreService.createJournal(newJournal);
      _loggerPage.i('Journal créé: ${newJournal.name} avec palette: ${newPaletteInstance.name}');

      await activeJournalNotifier.setActiveJournal(newJournal.id, _userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Journal "${newJournal.name}" créé avec succès!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      _loggerPage.e('Erreur création journal: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPaletteModelSelector() {
    if (_availablePaletteModels.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("Aucun modèle de palette disponible.", style: TextStyle(color: Colors.orange.shade700)));
    }
    return DropdownButtonFormField<PaletteModel>(
      value: _selectedPaletteModel,
      items:
          _availablePaletteModels.map((PaletteModel model) {
            return DropdownMenuItem<PaletteModel>(value: model, child: Text(model.name + (model.isPredefined ? " (Prédéfini)" : " (Personnel)")));
          }).toList(),
      onChanged: (PaletteModel? newValue) {
        if (mounted) {
          setState(() {
            _selectedPaletteModel = newValue;
            _selectedExistingJournal = null;
            _updatePreparedPaletteFromModel(newValue);
          });
        }
      },
      decoration: const InputDecoration(labelText: 'Choisir un modèle de palette'),
      validator: (value) => _creationMode == JournalCreationMode.fromPaletteModel && value == null ? 'Veuillez choisir un modèle' : null,
    );
  }

  Widget _buildExistingJournalSelector() {
    if (_availableUserJournals.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("Aucun journal existant à copier.", style: TextStyle(color: Colors.orange.shade700)));
    }
    return DropdownButtonFormField<Journal>(
      value: _selectedExistingJournal,
      items:
          _availableUserJournals.map((Journal journal) {
            return DropdownMenuItem<Journal>(value: journal, child: Text(journal.name));
          }).toList(),
      onChanged: (Journal? newValue) {
        if (mounted) {
          setState(() {
            _selectedExistingJournal = newValue;
            _selectedPaletteModel = null;
            _updatePreparedPaletteFromJournal(newValue);
          });
        }
      },
      decoration: const InputDecoration(labelText: 'Copier la palette d\'un journal existant'),
      validator: (value) => _creationMode == JournalCreationMode.fromExistingJournal && value == null ? 'Veuillez choisir un journal' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canAttemptCreation = true;
    if (_creationMode == JournalCreationMode.fromPaletteModel && _selectedPaletteModel == null && _availablePaletteModels.isNotEmpty) {
      canAttemptCreation = false;
    }
    if (_creationMode == JournalCreationMode.fromExistingJournal && _selectedExistingJournal == null && _availableUserJournals.isNotEmpty) {
      canAttemptCreation = false;
    }
    if (_creationMode == JournalCreationMode.fromPaletteModel && _availablePaletteModels.isEmpty) {
      canAttemptCreation = false;
    }
    if (_creationMode == JournalCreationMode.fromExistingJournal && _availableUserJournals.isEmpty) {
      canAttemptCreation = false;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un nouveau journal')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Nom du journal :', style: Theme.of(context).textTheme.titleMedium),
                      TextFormField(
                        controller: _journalNameController,
                        decoration: InputDecoration(
                          labelText: 'Choississez ici le nom du nouveau journal...',
                          hintText: 'Ex: Journal de gratitude, Projets 2025...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.edit),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer un nom pour le journal.';
                          }
                          if (value.length > 70) {
                            return 'Le nom du journal est trop long (max 70).';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (mounted) {
                            setState(() {
                              final trimmedValue = value.trim();
                              if (_creationMode == JournalCreationMode.fromPaletteModel && _selectedPaletteModel != null) {
                                _preparedPaletteName =
                                    trimmedValue.isNotEmpty ? "Palette de '$trimmedValue' (Modèle: ${_selectedPaletteModel!.name})" : "Palette (Modèle: ${_selectedPaletteModel!.name})";
                              } else if (_creationMode == JournalCreationMode.fromExistingJournal && _selectedExistingJournal != null) {
                                _preparedPaletteName =
                                    trimmedValue.isNotEmpty ? "Palette de '$trimmedValue' (Copiée de ${_selectedExistingJournal!.name})" : "Palette (Copiée de ${_selectedExistingJournal!.name})";
                              } else {
                                _preparedPaletteName = trimmedValue.isNotEmpty ? "Palette de '$trimmedValue'" : "Nouvelle Palette";
                              }
                              _paletteEditorKey = UniqueKey();
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 20),
                      const Divider(thickness: 2, color: Colors.grey),
                      const SizedBox(height: 10),

                      Text('Source de la palette :', style: Theme.of(context).textTheme.titleMedium),
                      RadioListTile<JournalCreationMode>(
                        title: const Text('À partir d\'un modèle de palette'),
                        value: JournalCreationMode.fromPaletteModel,
                        groupValue: _creationMode,
                        onChanged:
                            _availablePaletteModels.isNotEmpty
                                ? (JournalCreationMode? value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      _creationMode = value;
                                      if (_selectedPaletteModel == null && _availablePaletteModels.isNotEmpty) {
                                        _selectedPaletteModel = _availablePaletteModels.first;
                                      }
                                      _selectedExistingJournal = null;
                                      _updatePreparedPaletteFromModel(_selectedPaletteModel);
                                    });
                                  }
                                }
                                : null,
                      ),
                      RadioListTile<JournalCreationMode>(
                        title: const Text('En copiant la palette d\'un journal existant'),
                        value: JournalCreationMode.fromExistingJournal,
                        groupValue: _creationMode,
                        onChanged:
                            _availableUserJournals.isNotEmpty
                                ? (JournalCreationMode? value) {
                                  if (value != null && mounted) {
                                    setState(() {
                                      _creationMode = value;
                                      if (_selectedExistingJournal == null && _availableUserJournals.isNotEmpty) {
                                        _selectedExistingJournal = _availableUserJournals.first;
                                      }
                                      _selectedPaletteModel = null;
                                      _updatePreparedPaletteFromJournal(_selectedExistingJournal);
                                    });
                                  }
                                }
                                : null,
                      ),
                      const SizedBox(height: 15),

                      if (_creationMode == JournalCreationMode.fromPaletteModel) _buildPaletteModelSelector(),

                      if (_creationMode == JournalCreationMode.fromExistingJournal) _buildExistingJournalSelector(),

                      const Divider(height: 30, thickness: 1),
                      Text('Prévisualisation et édition de la palette :', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),

                      if (!_isLoading)
                        InlinePaletteEditorWidget(
                          key: _paletteEditorKey,
                          initialPaletteName: _preparedPaletteName,
                          initialColors: _preparedColors,
                          onPaletteNameChanged: (newName) {
                            if (mounted) {
                              setState(() {
                                _preparedPaletteName = newName;
                              });
                            }
                          },
                          onColorsChanged: (newColors) {
                            if (mounted) {
                              setState(() {
                                _preparedColors = newColors;
                              });
                            }
                          },
                          showNameEditor: false,
                          isEditingJournalPalette: false, // On crée une nouvelle instance, pas une édition de palette de journal existant
                          // canDeleteColorCallback n'est pas nécessaire ici car on ne supprime pas de couleurs d'un journal existant
                          // onPaletteNeedsSave n'est pas crucial ici car la sauvegarde se fait via le bouton principal "_createJournal"
                        ),

                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Créer le journal'),
                          onPressed: (_isLoading || !canAttemptCreation) ? null : _createJournal,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
