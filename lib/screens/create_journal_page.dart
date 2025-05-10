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

enum JournalCreationMode {
  fromPaletteModel,
  fromExistingJournal,
  // fromScratch, // Optionnel: si on veut une palette complètement vide par défaut
}

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
  String _preparedPaletteName = ""; // Sera initialisé mais non modifiable via UI ici

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

      final List<PaletteModel> predefinedPalettesList = predefinedPalettes;
      final List<PaletteModel> userModels = await firestoreService.getUserPaletteModelsStream(_userId!).first;
      _availablePaletteModels = [...predefinedPalettesList, ...userModels];

      _availableUserJournals = await firestoreService.getJournalsStream(_userId!).first;

      // Définir la source initiale pour l'éditeur de palette
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
        // Aucune source disponible, initialiser avec une palette vide nommée
        _preparedPaletteName = "Palette du nouveau journal"; // Nom par défaut non modifiable par UI ici
        _preparedColors = []; // Ou une palette de base si souhaité
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
    if (model == null) {
      _preparedPaletteName = "Palette (depuis modèle)"; // Nom par défaut
      _preparedColors = [];
    } else {
      _preparedPaletteName = "Palette de '${_journalNameController.text}' (basée sur ${model.name})"; // Nom initial, non éditable via UI
      _preparedColors = model.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
    }
    _paletteEditorKey = UniqueKey();
    // Forcer la mise à jour du nom de la palette dans le widget enfant si le champ n'est pas montré
    // Cela se fera via initialPaletteName lors de la reconstruction avec la nouvelle clé.
    if (mounted) setState(() {});
  }

  void _updatePreparedPaletteFromJournal(Journal? journal) {
    if (journal == null) {
      _preparedPaletteName = "Palette (copiée)"; // Nom par défaut
      _preparedColors = [];
    } else {
      _preparedPaletteName = "Palette de '${_journalNameController.text}' (copiée de ${journal.name})"; // Nom initial, non éditable via UI
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

    // _preparedPaletteName est maintenant géré en interne et basé sur la source, non plus sur un champ de saisie direct ici.
    // Sa validité n'est plus un souci direct pour ce formulaire.

    if (_preparedColors.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La palette en préparation est vide. Veuillez ajouter des couleurs ou choisir une source avec des couleurs.")));
      return;
    }
    // SF-PALETTE-04: Une instance de palette doit contenir entre 3 et 48 couleurs.
    // Cette validation devrait être faite ici avant la création.
    if (_preparedColors.length < 1 || _preparedColors.length > 48) {
      // Temporairement 1 pour test, devrait être 3.
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("La palette doit contenir entre ${MIN_COLORS_IN_PALETTE_EDITOR} et ${MAX_COLORS_IN_PALETTE_EDITOR} couleurs.")));
      return;
    }

    if (mounted)
      setState(() {
        _isLoading = true;
      });

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);

      // Utiliser _preparedPaletteName qui a été défini lors de la sélection de la source
      final String finalPaletteName = _preparedPaletteName.isNotEmpty ? _preparedPaletteName : "Palette de ${_journalNameController.text.trim()}";

      final Palette newPaletteInstance = Palette(
        id: _uuid.v4(),
        // L'ID de l'instance de palette
        name: finalPaletteName,
        // Nom de la palette pour cette instance
        colors: _preparedColors,
        isPredefined: false,
        // Une instance n'est jamais un modèle prédéfini
        userId: _userId, // L'ID de l'utilisateur peut être utile pour les règles Firestore sur les sous-collections de palettes si un jour on en fait
      );

      final Journal newJournal = Journal(
        id: _uuid.v4(),
        userId: _userId!,
        name: _journalNameController.text.trim(),
        palette: newPaletteInstance,
        // L'instance de palette complète est embarquée
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );

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
      // If mode is fromPaletteModel but nothing is selected yet (and models are available),
      // it's not ready for creation until a selection is made or if _availablePaletteModels is empty (handled below).
      canAttemptCreation = false;
    }
    if (_creationMode == JournalCreationMode.fromExistingJournal && _selectedExistingJournal == null && _availableUserJournals.isNotEmpty) {
      canAttemptCreation = false;
    }
    // If a mode is selected but its respective list is empty, then it's also not ready.
    if (_creationMode == JournalCreationMode.fromPaletteModel && _availablePaletteModels.isEmpty) {
      canAttemptCreation = false; // Cannot create from model if no models exist
    }
    if (_creationMode == JournalCreationMode.fromExistingJournal && _availableUserJournals.isEmpty) {
      canAttemptCreation = false; // Cannot create from journal if no journals exist
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
                          prefixIcon: Icon(Icons.book_outlined),
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
                          // Mettre à jour le nom de la palette préparée si le nom du journal change
                          if (mounted) {
                            setState(() {
                              if (_creationMode == JournalCreationMode.fromPaletteModel && _selectedPaletteModel != null) {
                                _preparedPaletteName = "Palette de '$value' (basée sur ${_selectedPaletteModel!.name})";
                              } else if (_creationMode == JournalCreationMode.fromExistingJournal && _selectedExistingJournal != null) {
                                _preparedPaletteName = "Palette de '$value' (copiée de ${_selectedExistingJournal!.name})";
                              } else {
                                _preparedPaletteName = "Palette de '$value'";
                              }
                              _paletteEditorKey = UniqueKey(); // Forcer la reconstruction de l'éditeur
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 20),
                      Divider(
                        thickness: 3, // Épaisseur de la ligne
                        color: Colors.black26, // Couleur de la ligne
                      ),

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
                                      _selectedExistingJournal = null; // Important to clear other selection
                                      _updatePreparedPaletteFromModel(_selectedPaletteModel);
                                    });
                                  }
                                }
                                : null, // Disable if no models available
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
                                      _selectedPaletteModel = null; // Important to clear other selection
                                      _updatePreparedPaletteFromJournal(_selectedExistingJournal);
                                    });
                                  }
                                }
                                : null, // Disable if no journals available
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
                          // Passé mais non éditable par UI ici
                          initialColors: _preparedColors,
                          onPaletteNameChanged: (newName) {
                            // Ce callback est toujours requis par le widget, mais comme le champ
                            // de nom n'est pas montré, cette valeur ne devrait pas changer via l'UI ici.
                            // On met à jour _preparedPaletteName au cas où, mais il est principalement
                            // défini par _updatePreparedPaletteFromModel/Journal.
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
