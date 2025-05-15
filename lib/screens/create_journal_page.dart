// lib/screens/create_journal_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:logger/logger.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

enum JournalCreationMode { emptyPalette, fromPaletteModel, fromExistingJournal }

enum PaletteSourceType { empty, model, existingJournal }

class CreateJournalPage extends StatefulWidget {
  const CreateJournalPage({Key? key}) : super(key: key);

  @override
  _CreateJournalPageState createState() => _CreateJournalPageState();
}

class _CreateJournalPageState extends State<CreateJournalPage> {
  final _formKey = GlobalKey<FormState>();
  final _journalNameController = TextEditingController();

  JournalCreationMode _creationMode = JournalCreationMode.emptyPalette;
  PaletteSourceType _selectedSourceType = PaletteSourceType.empty;

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
    _journalNameController.addListener(_updatePaletteNameOnJournalNameChange);
    _loadInitialData();
  }

  void _updatePaletteNameOnJournalNameChange() {
    if (mounted) {
      setState(() {
        _updatePaletteBasedOnMode();
      });
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    if (_userId == null) {
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

      _updatePaletteBasedOnMode();
    } catch (e) {
      _loggerPage.e("Erreur chargement données initiales: $e");
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

  void _updatePaletteBasedOnMode() {
    final journalName = _journalNameController.text.trim();
    String defaultPaletteName = journalName.isNotEmpty ? "Palette de '$journalName'" : "Nouvelle Palette";

    if (_creationMode != JournalCreationMode.fromPaletteModel) {
      _selectedPaletteModel = null;
    }
    if (_creationMode != JournalCreationMode.fromExistingJournal) {
      _selectedExistingJournal = null;
    }

    _preparedColors = [];

    switch (_creationMode) {
      case JournalCreationMode.fromPaletteModel:
        if (_availablePaletteModels.isNotEmpty) {
          _selectedPaletteModel ??= _availablePaletteModels.first;
          _preparedPaletteName = journalName.isNotEmpty ? "Palette de '$journalName' (Modèle: ${_selectedPaletteModel!.name})" : "Palette (Modèle: ${_selectedPaletteModel!.name})";
          _preparedColors = _selectedPaletteModel!.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
        } else {
          _selectedSourceType = PaletteSourceType.empty;
          _creationMode = JournalCreationMode.emptyPalette;
          _updatePaletteBasedOnMode();
          return;
        }
        break;
      case JournalCreationMode.fromExistingJournal:
        if (_availableUserJournals.isNotEmpty) {
          _selectedExistingJournal ??= _availableUserJournals.first;
          _preparedPaletteName = journalName.isNotEmpty ? "Palette de '$journalName' (Copiée de ${_selectedExistingJournal!.name})" : "Palette (Copiée de ${_selectedExistingJournal!.name})";
          _preparedColors = _selectedExistingJournal!.palette.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList();
        } else {
          _selectedSourceType = PaletteSourceType.empty;
          _creationMode = JournalCreationMode.emptyPalette;
          _updatePaletteBasedOnMode();
          return;
        }
        break;
      case JournalCreationMode.emptyPalette:
        // CORRECTION: La clause `default` a été supprimée car elle était redondante et couverte par ce cas.
        _preparedPaletteName = defaultPaletteName;
        _preparedColors = [];
        break;
      // No default needed as all enum values are covered.
    }
    _paletteEditorKey = UniqueKey();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _journalNameController.removeListener(_updatePaletteNameOnJournalNameChange);
    _journalNameController.dispose();
    super.dispose();
  }

  Future<bool> _handleDeleteAllColorsInCreation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Vider la palette ?'),
          content: const Text('Voulez-vous vraiment supprimer toutes les couleurs de cette nouvelle palette ?'),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Vider'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  Future<void> _createJournal() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final String journalName = _journalNameController.text.trim();
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    bool nameExists = await firestoreService.checkJournalNameExists(journalName, _userId!);
    if (nameExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Un journal nommé "$journalName" existe déjà.'), backgroundColor: Colors.orange));
      }
      return;
    }

    if (_preparedColors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La palette doit contenir au moins 1 couleur.")));
      }
      return;
    }
    if (_preparedColors.length < MIN_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("La palette doit contenir au moins $MIN_COLORS_IN_PALETTE_EDITOR couleur(s).")));
      }
      return;
    }
    if (_preparedColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("La palette ne peut pas avoir plus de $MAX_COLORS_IN_PALETTE_EDITOR couleurs.")));
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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
            _updatePaletteBasedOnMode();
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
            _updatePaletteBasedOnMode();
          });
        }
      },
      decoration: const InputDecoration(labelText: 'Copier la palette d\'un journal existant'),
      validator: (value) => _creationMode == JournalCreationMode.fromExistingJournal && value == null ? 'Veuillez choisir un journal' : null,
    );
  }

  Widget _buildStepIndicator(String stepNumber, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: Theme.of(context).colorScheme.primary, child: Text(stepNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un nouveau journal')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.only(bottom: 20.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepIndicator("1", "Nom du Journal"),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _journalNameController,
                                decoration: InputDecoration(
                                  labelText: 'Choisissez un nom pour votre journal...',
                                  hintText: 'Ex: Journal de gratitude, Projets 2025...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
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
                              ),
                            ],
                          ),
                        ),
                      ),

                      Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.only(bottom: 20.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStepIndicator("2", "Configuration de la Palette"),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<PaletteSourceType>(
                                value: _selectedSourceType,
                                decoration: const InputDecoration(labelText: 'Choisir la source de la palette', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: PaletteSourceType.empty, child: Text('Palette Vierge (à composer)')),
                                  DropdownMenuItem(value: PaletteSourceType.model, child: Text('À partir d\'un modèle de palette')),
                                  DropdownMenuItem(value: PaletteSourceType.existingJournal, child: Text('En copiant la palette d\'un journal existant')),
                                ],
                                onChanged: (PaletteSourceType? newValue) {
                                  if (newValue != null && mounted) {
                                    setState(() {
                                      _selectedSourceType = newValue;
                                      if (newValue == PaletteSourceType.empty) {
                                        _creationMode = JournalCreationMode.emptyPalette;
                                      } else if (newValue == PaletteSourceType.model) {
                                        _creationMode = JournalCreationMode.fromPaletteModel;
                                      } else if (newValue == PaletteSourceType.existingJournal) {
                                        _creationMode = JournalCreationMode.fromExistingJournal;
                                      }
                                      _updatePaletteBasedOnMode();
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 15),
                              if (_creationMode == JournalCreationMode.fromPaletteModel) _buildPaletteModelSelector(),
                              if (_creationMode == JournalCreationMode.fromExistingJournal) _buildExistingJournalSelector(),

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
                                  isEditingJournalPalette: false,
                                  onDeleteAllColorsRequested: _handleDeleteAllColorsInCreation,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Créer le journal'),
                          onPressed: (_isLoading || !canAttemptCreation) ? null : _createJournal,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), textStyle: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
    );
  }
}
