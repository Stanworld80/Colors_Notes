import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/palette_model.dart';
import '../models/journal.dart';
import '../models/palette.dart';
import '../models/color_data.dart';
import '../services/firestore_service.dart';
import '../core/predefined_templates.dart';

enum CreationMode { blank, predefinedTemplate, existingJournal }

class CreateJournalPage extends StatefulWidget {
  const CreateJournalPage({Key? key}) : super(key: key);

  @override
  _CreateJournalPageState createState() => _CreateJournalPageState();
}

class _CreateJournalPageState extends State<CreateJournalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  CreationMode _selectedMode = CreationMode.blank;
  PredefinedJournalTemplate? _selectedPredefinedTemplate;
  Journal? _selectedExistingJournalTemplate;
  String? _selectedExistingJournalId;
  Object? _selectedPaletteSource;
  String? _selectedPaletteValue;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Helper pour réinitialiser les sélections lors du changement de mode
  void _updateMode(CreationMode? value) {
    if (value != null && value != _selectedMode) {
      setState(() {
        _selectedMode = value;
        _selectedPaletteSource = null;
        _selectedPaletteValue = null;
        _selectedPredefinedTemplate = null;
        _selectedExistingJournalTemplate = null;
        _nameController.text = '';
      });
    }
  }

  Future<void> _saveJournal() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final firestoreService = context.read<FirestoreService>();
    final userId = context.read<User?>()?.uid;

    if (!_formKey.currentState!.validate()) return;

    bool selectionValid = true;
    if (_selectedMode == CreationMode.blank && _selectedPaletteSource == null) {
      selectionValid = false;
      messenger.showSnackBar(const SnackBar(content: Text('Choisissez une palette de base.'), backgroundColor: Colors.orange));
    } else if (_selectedMode == CreationMode.predefinedTemplate && _selectedPredefinedTemplate == null) {
      selectionValid = false;
      messenger.showSnackBar(const SnackBar(content: Text('Choisissez un modèle thématique.'), backgroundColor: Colors.orange));
    } else if (_selectedMode == CreationMode.existingJournal && _selectedExistingJournalTemplate == null) {
      selectionValid = false;
      messenger.showSnackBar(const SnackBar(content: Text('Choisissez un journal source.'), backgroundColor: Colors.orange));
    }

    if (!selectionValid) return;
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    if (userId == null) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
      messenger.showSnackBar(const SnackBar(content: Text('Erreur: Utilisateur non trouvé.'), backgroundColor: Colors.red));
      return;
    }

    final String journalName = _nameController.text.trim();
    Palette paletteInstance;

    try {
      if (_selectedMode == CreationMode.blank) {
        if (_selectedPaletteSource is PaletteModel) {
          final model = _selectedPaletteSource as PaletteModel;
          paletteInstance = Palette(name: model.name, colors: model.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList());
        } else if (_selectedPaletteSource is MapEntry<String, List<ColorData>>) {
          final entry = _selectedPaletteSource as MapEntry<String, List<ColorData>>;
          paletteInstance = Palette(name: entry.key, colors: entry.value.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList());
        } else {
          throw Exception("Source de palette invalide.");
        }
      } else if (_selectedMode == CreationMode.predefinedTemplate) {
        paletteInstance = Palette(
          name: _selectedPredefinedTemplate!.paletteDefinition.name,
          colors: _selectedPredefinedTemplate!.paletteDefinition.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList(),
        );
      } else if (_selectedMode == CreationMode.existingJournal) {
        paletteInstance = Palette(
          name: _selectedExistingJournalTemplate!.embeddedPaletteInstance.name,
          colors: _selectedExistingJournalTemplate!.embeddedPaletteInstance.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList(),
        );
      } else {
        throw Exception("Mode de création non supporté.");
      }

      final newJournal = Journal(id: '', name: journalName, userId: userId, embeddedPaletteInstance: paletteInstance);
      await firestoreService.createJournal(userId, newJournal);
      messenger.showSnackBar(const SnackBar(content: Text('Journal créé avec succès !')));
      navigator.pop();
    } catch (e) {
      print("Error creating journal: $e");
      messenger.showSnackBar(SnackBar(content: Text('Erreur création: $e'), backgroundColor: Colors.red));
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
    final firestoreService = context.read<FirestoreService>();
    final userId = context.watch<User?>()?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau journal'),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            tooltip: 'Enregistrer',
            onPressed: _isSaving ? null : _saveJournal,
          ),
        ],
      ),
      body:
          userId == null
              ? const Center(child: Text("Veuillez vous connecter."))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Text("Méthode de création :", style: Theme.of(context).textTheme.titleMedium),
                      RadioListTile<CreationMode>(
                        title: const Text('Journal Vierge'),
                        subtitle: const Text('Choisir nom et palette de base.'),
                        value: CreationMode.blank,
                        groupValue: _selectedMode,
                        onChanged: _updateMode,
                      ),
                      RadioListTile<CreationMode>(
                        title: const Text('Modèle Thématique'),
                        subtitle: const Text('Utiliser structure prédéfinie.'),
                        value: CreationMode.predefinedTemplate,
                        groupValue: _selectedMode,
                        onChanged: _updateMode,
                      ),
                      RadioListTile<CreationMode>(
                        title: const Text('Journal Existant'),
                        subtitle: const Text('Copier structure d\'un journal.'),
                        value: CreationMode.existingJournal,
                        groupValue: _selectedMode,
                        onChanged: _updateMode,
                      ),
                      const Divider(height: 24, thickness: 1),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nom du nouvel journal', border: OutlineInputBorder()),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Entrez un nom.' : null,
                      ),
                      const SizedBox(height: 24),

                      // --- Section Vierge ---
                      if (_selectedMode == CreationMode.blank) ...[
                        Text("Palette de base :", style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        StreamBuilder<List<PaletteModel>>(
                          stream: firestoreService.getUserPaletteModelsStream(userId),
                          builder: (context, snapshot) {
                            // ... gestion attente/erreur ...

                            final personalModels = snapshot.data ?? [];
                            final genericEntries = predefinedGenericPalettes.entries.toList();

                            // Construire UNIQUEMENT les items sélectionnables
                            final List<DropdownMenuItem<String?>> items = [];

                            // 1. Placeholder (value: null)
                            items.add(const DropdownMenuItem<String?>(value: null, child: Text("Sélectionnez...", style: TextStyle(color: Colors.grey))));

                            // 2. Modèles Personnels (value: model.id)
                            if (personalModels.isNotEmpty) {
                              // Optionnel : Ajouter un préfixe au texte pour clarté
                              items.addAll(
                                personalModels.map(
                                  (model) => DropdownMenuItem<String?>(
                                    value: model.id,
                                    child: Text("Personnel: ${model.name}"), // Préfixe optionnel
                                  ),
                                ),
                              );
                            }

                            // 3. Modèles Génériques (value: entry.key)
                            if (genericEntries.isNotEmpty) {
                              // Optionnel : Ajouter un préfixe au texte pour clarté
                              items.addAll(
                                genericEntries.map(
                                  (entry) => DropdownMenuItem<String?>(
                                    value: entry.key,
                                    child: Text("Générique: ${entry.key}"), // Préfixe optionnel
                                  ),
                                ),
                              );
                            }
                            // --- NE PAS ajouter les Headers/Dividers ici ---

                            // Le reste de la logique (calcul valueForDropdown, reset post-build, return DropdownButtonFormField)
                            // devrait maintenant fonctionner car la liste 'items' est correcte.

                            final Set<String?> validValues = items.map((item) => item.value).toSet();
                            String? valueForDropdown = (_selectedPaletteValue != null && validValues.contains(_selectedPaletteValue)) ? _selectedPaletteValue : null;

                            if (_selectedPaletteValue != null && !validValues.contains(_selectedPaletteValue)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _selectedPaletteValue != null && !items.any((item) => item.value == _selectedPaletteValue)) {
                                  setState(() {
                                    _selectedPaletteValue = null;
                                    _selectedPaletteSource = null;
                                  });
                                }
                              });
                            }

                            // Logs finaux (peuvent être retirés une fois que ça marche)
                            final List<String?> itemValuesForDebug = items.map((item) => item.value).toList();
                            print("--- Dropdown Build ---");
                            print("Current _selectedPaletteValue state: $_selectedPaletteValue");
                            print("Final generated (SELECTABLE ONLY) item values: $itemValuesForDebug");
                            print("Value passed to DropdownButtonFormField: $valueForDropdown");

                            return DropdownButtonFormField<String?>(
                              value: valueForDropdown,
                              // La valeur calculée
                              items: items,
                              // La liste des items générée
                              // Assurez-vous que onChanged ressemble à ceci :
                              onChanged: (String? newValue) {
                                // 'allSources' doit être accessible ici
                                final List<Object> localAllSources = [...personalModels, ...genericEntries]; // Recréer si besoin

                                setState(() {
                                  _selectedPaletteValue = newValue;
                                  _selectedPaletteSource = null; // Reset

                                  if (newValue != null) {
                                    try {
                                      // Utiliser firstWhere SANS orElse
                                      _selectedPaletteSource = localAllSources.firstWhere((source) => source is PaletteModel ? source.id == newValue : (source as MapEntry).key == newValue);
                                    } on StateError catch (_) {
                                      // Gérer le cas non trouvé
                                      print(">>> INFO: Selected value '$newValue' not found (StateError caught). Resetting source object.");
                                      _selectedPaletteSource = null;
                                    } catch (e) {
                                      // Gérer autre erreur
                                      print(">>> ERROR during source lookup: $e");
                                      _selectedPaletteSource = null;
                                    }
                                  }
                                  // Logs
                                  print("--- Palette Dropdown onChanged ---");
                                  print("newValue received: $newValue");
                                  print("Selected source object set to: $_selectedPaletteSource");
                                });
                              },
                              // Fin de onChanged
                              decoration: const InputDecoration(labelText: 'Modèle de palette', border: OutlineInputBorder()),
                              validator: (value) => value == null ? 'Choisissez une palette.' : null,
                              isExpanded: true,
                            );
                          },
                        ),
                      ],

                      // --- Section Modèle Prédéfini ---
                      if (_selectedMode == CreationMode.predefinedTemplate) ...[
                        Text("Modèle thématique :", style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PredefinedJournalTemplate?>(
                          value: _selectedPredefinedTemplate,
                          items: [
                            const DropdownMenuItem<PredefinedJournalTemplate?>(value: null, child: Text("Sélectionnez...", style: TextStyle(color: Colors.grey))),
                            ...predefinedJournalTemplates.map((template) => DropdownMenuItem(value: template, child: Text(template.templateName))).toList(),
                          ],
                          onChanged: (template) {
                            setState(() {
                              _selectedPredefinedTemplate = template;
                              _nameController.text = template?.suggestedJournalName ?? '';
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Modèle thématique', border: OutlineInputBorder()),
                          validator: (value) => value == null ? 'Choisissez un modèle.' : null,
                          isExpanded: true,
                        ),
                      ],

                      // --- Section Journal Existant ---
                      // --- SECTION CONDITIONNELLE : AGENDA EXISTANT ---
                      if (_selectedMode == CreationMode.existingJournal) ...[
                        Text("Choisir un journal comme modèle :", style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        StreamBuilder<List<Journal>>(
                          stream: firestoreService.getUserJournalsStream(userId),
                          builder: (context, snapshot) {
                            // --- GESTION DE L'ATTENTE ---
                            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                              // Afficher un indicateur de chargement centré
                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                            }
                            // --- GESTION DES ERREURS ---
                            if (snapshot.hasError) {
                              // Afficher un message d'erreur clair
                              print("Error loading existing journals: ${snapshot.error}"); // Garder un log pour le debug
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  "Erreur lors du chargement de vos journals.\n(${snapshot.error})", // Afficher l'erreur peut aider au debug
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            final existingJournals = snapshot.data ?? [];
                            if (existingJournals.isEmpty) {
                              // Vérifier s'il y a au moins 1 journal à copier
                              return const Text("Aucun journal disponible pour servir de modèle.", style: TextStyle(fontStyle: FontStyle.italic));
                            }

                            // Construire les items avec journal.id comme valeur
                            final List<DropdownMenuItem<String?>> items = [
                              const DropdownMenuItem<String?>(value: null, child: Text("Sélectionnez l'journal source...", style: TextStyle(color: Colors.grey))),
                              ...existingJournals
                                  .map(
                                    (journal) => DropdownMenuItem<String?>(
                                      // Type String?
                                      value: journal.id, // <<< Utiliser journal.id comme valeur
                                      child: Text(journal.name),
                                    ),
                                  )
                                  .toList(),
                            ];

                            // Vérifier si la valeur sélectionnée existe
                            bool valueExists = items.any((item) => item.value == _selectedExistingJournalId);
                            String? valueForDropdown = valueExists ? _selectedExistingJournalId : null;

                            // Logique de reset post-build (optionnelle mais sûre)
                            if (_selectedExistingJournalId != null && !valueExists) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _selectedExistingJournalId != null && !items.any((item) => item.value == _selectedExistingJournalId)) {
                                  setState(() {
                                    _selectedExistingJournalId = null;
                                    _selectedExistingJournalTemplate = null;
                                  });
                                }
                              });
                            }

                            return DropdownButtonFormField<String?>(
                              // Type String?
                              value: valueForDropdown,
                              // Utiliser l'ID stocké
                              items: items,
                              onChanged: (String? newValue) {
                                // Reçoit l'ID (String?) de l'journal
                                // 'existingJournals' doit être accessible depuis le scope du builder parent
                                final List<Journal> localExistingJournals = existingJournals; // Recréer ici par sécurité si besoin

                                setState(() {
                                  _selectedExistingJournalId = newValue; // Met à jour l'ID stocké
                                  _selectedExistingJournalTemplate = null; // Réinitialise l'objet trouvé

                                  if (newValue != null) {
                                    try {
                                      // Essayer de trouver l'objet Journal correspondant à l'ID
                                      _selectedExistingJournalTemplate = localExistingJournals.firstWhere(
                                        (journal) => journal.id == newValue,
                                        // Pas de orElse: ici !
                                      );
                                    } on StateError catch (_) {
                                      // Gérer le cas où l'journal n'est pas trouvé
                                      print(">>> INFO: Selected journal ID '$newValue' not found (StateError caught).");
                                      _selectedExistingJournalTemplate = null;
                                    } catch (e) {
                                      // Gérer toute autre erreur
                                      print(">>> ERROR during existing journal lookup: $e");
                                      _selectedExistingJournalTemplate = null;
                                    }
                                  }

                                  // Pré-remplir le nom
                                  _nameController.text = _selectedExistingJournalTemplate != null ? 'Copie de ${_selectedExistingJournalTemplate!.name}' : '';

                                  print("--- ExistingJournal Dropdown onChanged ---");
                                  print("newValue (journalId) received: $newValue");
                                  print("Selected ExistingJournal object set to: ${_selectedExistingJournalTemplate?.name}");
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Journal source à copier', border: OutlineInputBorder()),
                              validator: (value) => value == null ? 'Choisissez un journal source.' : null,
                              isExpanded: true,
                            );
                          },
                        ),
                      ], // Fin Section Journal Existant
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
    );
  }
}
