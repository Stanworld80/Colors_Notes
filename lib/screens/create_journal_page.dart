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

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

enum JournalCreationMode {
  fromPaletteModel,
  fromExistingJournal,
  // fromThematicTemplate, // Si vous voulez séparer les modèles thématiques d'agenda
}

class CreateJournalPage extends StatefulWidget {
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
    setState(() { _isLoading = true; });

    if (_userId == null) {
      _loggerPage.w("UserID est null, impossible de charger les données initiales.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: Utilisateur non identifié.")),
        );
        setState(() { _isLoading = false; });
      }
      return;
    }

    try {
      final FirestoreService firestoreService = Provider.of<FirestoreService>(context, listen: false);

      // Charger les modèles de palettes (prédéfinis + utilisateur)
      final List<PaletteModel> predefinedPalettesList = predefinedPalettes;
      final List<PaletteModel> userModels = await firestoreService.getUserPaletteModelsStream(_userId!).first;
      _availablePaletteModels = [...predefinedPalettesList, ...userModels];
      if (_availablePaletteModels.isNotEmpty) {
        _selectedPaletteModel = _availablePaletteModels.first;
      }

      // Charger les journaux existants de l'utilisateur
      _availableUserJournals = await firestoreService.getJournalsStream(_userId!).first;
      if (_availableUserJournals.isNotEmpty) {
        _selectedExistingJournal = _availableUserJournals.first;
      }

    } catch (e, stackTrace) {
      _loggerPage.e("Erreur chargement données initiales: $e", error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement des options: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _journalNameController.dispose();
    super.dispose();
  }

  Palette _createPaletteFromModel(PaletteModel model, String? userId) {
    return Palette(
      id: _uuid.v4(), // Nouvel ID pour l'instance de palette
      name: model.name, // Le nom de la palette peut être celui du modèle
      colors: model.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList(), // NOUVEAUX IDs pour chaque ColorData
      isPredefined: false, // L'instance n'est jamais prédéfinie
      userId: userId,
    );
  }

  Palette _createPaletteFromJournal(Journal sourceJournal, String? userId) {
    return Palette(
      id: _uuid.v4(), // Nouvel ID pour l'instance de palette
      name: "${sourceJournal.palette.name} (Copie)", // Indiquer que c'est une copie
      colors: sourceJournal.palette.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList(), // NOUVEAUX IDs pour chaque ColorData
      isPredefined: false,
      userId: userId,
    );
  }

  Future<void> _createJournal() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() { _isLoading = true; });

    Palette? newPaletteInstance;

    if (_creationMode == JournalCreationMode.fromPaletteModel) {
      if (_selectedPaletteModel == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Veuillez sélectionner un modèle de palette.")));
        setState(() { _isLoading = false; });
        return;
      }
      newPaletteInstance = _createPaletteFromModel(_selectedPaletteModel!, _userId);
    } else if (_creationMode == JournalCreationMode.fromExistingJournal) {
      if (_selectedExistingJournal == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Veuillez sélectionner un journal existant comme modèle.")));
        setState(() { _isLoading = false; });
        return;
      }
      newPaletteInstance = _createPaletteFromJournal(_selectedExistingJournal!, _userId);
    }

    if (newPaletteInstance == null) {
      _loggerPage.e("Erreur: newPaletteInstance est null avant la création du journal.");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur interne lors de la préparation de la palette.")));
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);

      final Journal newJournal = Journal(
        id: _uuid.v4(),
        userId: _userId!,
        name: _journalNameController.text.trim(),
        palette: newPaletteInstance,
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );

      await firestoreService.createJournal(newJournal);
      _loggerPage.i('Journal créé: ${newJournal.name} avec mode: $_creationMode');

      // Optionnel: Définir le nouveau journal comme actif
      await activeJournalNotifier.setActiveJournal(newJournal.id, _userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Journal "${newJournal.name}" créé avec succès!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _loggerPage.e('Erreur création journal: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Widget _buildPaletteModelSelector() {
    if (_availablePaletteModels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Aucun modèle de palette disponible. Créez-en un d'abord !", style: TextStyle(color: Colors.orange.shade700)),
      );
    }
    return DropdownButtonFormField<PaletteModel>(
      value: _selectedPaletteModel,
      items: _availablePaletteModels.map((PaletteModel model) {
        return DropdownMenuItem<PaletteModel>(
          value: model,
          child: Text(model.name + (model.isPredefined ? " (Prédéfini)" : " (Personnel)")),
        );
      }).toList(),
      onChanged: (PaletteModel? newValue) {
        if (mounted) setState(() { _selectedPaletteModel = newValue; });
      },
      decoration: InputDecoration(labelText: 'Choisir un modèle de palette'),
      validator: (value) => value == null ? 'Veuillez choisir un modèle de palette' : null,
    );
  }

  Widget _buildExistingJournalSelector() {
    if (_availableUserJournals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Aucun journal existant à copier. Créez-en un d'abord !", style: TextStyle(color: Colors.orange.shade700)),
      );
    }
    return DropdownButtonFormField<Journal>(
      value: _selectedExistingJournal,
      items: _availableUserJournals.map((Journal journal) {
        return DropdownMenuItem<Journal>(
          value: journal,
          child: Text(journal.name),
        );
      }).toList(),
      onChanged: (Journal? newValue) {
        if (mounted) setState(() { _selectedExistingJournal = newValue; });
      },
      decoration: InputDecoration(labelText: 'Copier la palette d\'un journal existant'),
      validator: (value) => value == null ? 'Veuillez choisir un journal à copier' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Créer un nouveau journal')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _journalNameController,
                decoration: InputDecoration(labelText: 'Nom du nouveau journal'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom pour le journal.';
                  }
                  if (value.length > 70) {
                    return 'Le nom du journal est trop long (max 70).';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Text('Méthode de création de la palette:', style: Theme.of(context).textTheme.titleMedium),
              RadioListTile<JournalCreationMode>(
                title: Text('À partir d\'un modèle de palette'),
                value: JournalCreationMode.fromPaletteModel,
                groupValue: _creationMode,
                onChanged: (JournalCreationMode? value) {
                  if (value != null && mounted) setState(() { _creationMode = value; });
                },
              ),
              RadioListTile<JournalCreationMode>(
                title: Text('En copiant la palette d\'un journal existant'),
                value: JournalCreationMode.fromExistingJournal,
                groupValue: _creationMode,
                onChanged: (JournalCreationMode? value) {
                  if (value != null && mounted) setState(() { _creationMode = value; });
                },
              ),
              SizedBox(height: 15),

              if (_creationMode == JournalCreationMode.fromPaletteModel)
                _buildPaletteModelSelector(),

              if (_creationMode == JournalCreationMode.fromExistingJournal)
                _buildExistingJournalSelector(),

              SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.add_circle_outline),
                  label: Text('Créer le journal'),
                  onPressed: (_isLoading ||
                      (_creationMode == JournalCreationMode.fromPaletteModel && _availablePaletteModels.isEmpty) ||
                      (_creationMode == JournalCreationMode.fromExistingJournal && _availableUserJournals.isEmpty)
                  ) ? null : _createJournal,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                ),
              ),
              SizedBox(height: 20),

              // Aperçu de la palette sélectionnée
              if (!_isLoading && _creationMode == JournalCreationMode.fromPaletteModel && _selectedPaletteModel != null) ...[
                Text("Aperçu du modèle : ${_selectedPaletteModel!.name}", style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8.0, runSpacing: 4.0,
                  children: _selectedPaletteModel!.colors.map((colorData) {
                    return Chip(
                      label: Text(colorData.title, style: TextStyle(fontSize: 10)),
                      backgroundColor: colorData.color,
                      labelStyle: TextStyle(color: colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    );
                  }).toList(),
                ),
              ],
              if (!_isLoading && _creationMode == JournalCreationMode.fromExistingJournal && _selectedExistingJournal != null) ...[
                Text("Aperçu de la palette copiée de : ${_selectedExistingJournal!.name}", style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8.0, runSpacing: 4.0,
                  children: _selectedExistingJournal!.palette.colors.map((colorData) {
                    return Chip(
                      label: Text(colorData.title, style: TextStyle(fontSize: 10)),
                      backgroundColor: colorData.color,
                      labelStyle: TextStyle(color: colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    );
                  }).toList(),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
