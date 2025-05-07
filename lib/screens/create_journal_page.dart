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

class CreateJournalPage extends StatefulWidget {
  @override
  _CreateJournalPageState createState() => _CreateJournalPageState();
}

class _CreateJournalPageState extends State<CreateJournalPage> {
  final _formKey = GlobalKey<FormState>();
  final _journalNameController = TextEditingController();
  PaletteModel? _selectedPaletteModel;
  List<PaletteModel> _availablePaletteModels = [];
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    _loadPaletteModels();
  }

  Future<void> _loadPaletteModels() async {
    if (_userId == null) {
      _loggerPage.w("UserID est null, impossible de charger les modèles de palettes.");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() { _isLoading = true; });
    }

    try {
      final FirestoreService firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final List<PaletteModel> predefined = predefinedPalettes;
      final List<PaletteModel> userModels = await firestoreService.getUserPaletteModelsStream(_userId!).first;

      _loggerPage.d("Type de 'predefined': ${predefined.runtimeType}, Longueur: ${predefined.length}");
      _loggerPage.d("Type de 'userModels': ${userModels.runtimeType}, Longueur: ${userModels.length}");

      if (mounted) {
        setState(() {
          _availablePaletteModels = <PaletteModel>[...predefined, ...userModels];
          if (_availablePaletteModels.isNotEmpty) {
            _selectedPaletteModel = _availablePaletteModels.first;
          }
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _loggerPage.e("Erreur chargement modèles palettes: $e", error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement modèles: ${e.toString()}")),
        );
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _journalNameController.dispose();
    super.dispose();
  }

  Future<void> _createJournal() async {
    if (_userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Utilisateur non identifié.")),
        );
      }
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPaletteModel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez sélectionner un modèle de palette.")),
        );
      }
      return;
    }

    if (mounted) {
      setState(() { _isLoading = true; });
    }

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);

      final Palette paletteInstance = Palette(
        id: _uuid.v4(),
        name: _selectedPaletteModel!.name,
        colors: _selectedPaletteModel!.colors.map((c) => c.copyWith(paletteElementId: _uuid.v4())).toList(),
        isPredefined: false,
        userId: _userId,
      );

      final Journal newJournal = Journal(
        id: _uuid.v4(),
        userId: _userId!,
        name: _journalNameController.text.trim(),
        palette: paletteInstance,
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );

      await firestoreService.createJournal(newJournal);
      _loggerPage.i('Journal créé: ${newJournal.name}');

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
                decoration: InputDecoration(labelText: 'Nom du journal'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nom pour le journal.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Text('Modèle de palette:', style: Theme.of(context).textTheme.titleMedium),
              if (_availablePaletteModels.isEmpty && !_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Aucun modèle de palette disponible."),
                )
              else if (_availablePaletteModels.isNotEmpty)
                DropdownButtonFormField<PaletteModel>(
                  value: _selectedPaletteModel,
                  items: _availablePaletteModels.map((PaletteModel model) {
                    return DropdownMenuItem<PaletteModel>(
                      value: model,
                      child: Text(model.name),
                    );
                  }).toList(),
                  onChanged: (PaletteModel? newValue) {
                    if (mounted) {
                      setState(() {
                        _selectedPaletteModel = newValue;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Choisir un modèle',
                  ),
                  validator: (value) => value == null ? 'Veuillez choisir un modèle' : null,
                ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _createJournal,
                  child: Text('Créer le journal'),
                ),
              ),
              SizedBox(height: 20),
              if (_selectedPaletteModel != null) ...[
                Text("Aperçu : ${_selectedPaletteModel!.name}", style: Theme.of(context).textTheme.titleSmall),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _selectedPaletteModel!.colors.map((colorData) {
                    return Chip(
                      label: Text(colorData.title),
                      backgroundColor: colorData.color,
                      labelStyle: TextStyle(
                        color: colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
