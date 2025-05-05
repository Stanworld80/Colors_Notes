import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/palette_model.dart';
import '../models/agenda.dart';
import '../models/palette.dart';
import '../models/color_data.dart';
import '../services/firestore_service.dart';
import '../core/predefined_templates.dart';

enum CreationMode { blank, predefinedTemplate, existingAgenda }

class CreateAgendaPage extends StatefulWidget {
  const CreateAgendaPage({Key? key}) : super(key: key);

  @override
  _CreateAgendaPageState createState() => _CreateAgendaPageState();
}

class _CreateAgendaPageState extends State<CreateAgendaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;

  CreationMode _selectedMode = CreationMode.blank;
  PredefinedAgendaTemplate? _selectedPredefinedTemplate;
  Agenda? _selectedExistingAgendaTemplate;
  String? _selectedExistingAgendaId;
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
        _selectedExistingAgendaTemplate = null;
        _nameController.text = '';
      });
    }
  }

  Future<void> _saveAgenda() async {
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
    } else if (_selectedMode == CreationMode.existingAgenda && _selectedExistingAgendaTemplate == null) {
      selectionValid = false;
      messenger.showSnackBar(const SnackBar(content: Text('Choisissez un agenda source.'), backgroundColor: Colors.orange));
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

    final String agendaName = _nameController.text.trim();
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
      } else if (_selectedMode == CreationMode.existingAgenda) {
        paletteInstance = Palette(
          name: _selectedExistingAgendaTemplate!.embeddedPaletteInstance.name,
          colors: _selectedExistingAgendaTemplate!.embeddedPaletteInstance.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue)).toList(),
        );
      } else {
        throw Exception("Mode de création non supporté.");
      }

      final newAgenda = Agenda(id: '', name: agendaName, userId: userId, embeddedPaletteInstance: paletteInstance);
      await firestoreService.createAgenda(userId, newAgenda);
      messenger.showSnackBar(const SnackBar(content: Text('Agenda créé avec succès !')));
      navigator.pop();
    } catch (e) {
      print("Error creating agenda: $e");
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
        title: const Text('Nouvel Agenda'),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            tooltip: 'Enregistrer',
            onPressed: _isSaving ? null : _saveAgenda,
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
                        title: const Text('Agenda Vierge'),
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
                        title: const Text('Agenda Existant'),
                        subtitle: const Text('Copier structure d\'un agenda.'),
                        value: CreationMode.existingAgenda,
                        groupValue: _selectedMode,
                        onChanged: _updateMode,
                      ),
                      const Divider(height: 24, thickness: 1),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nom du nouvel agenda', border: OutlineInputBorder()),
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
                        DropdownButtonFormField<PredefinedAgendaTemplate?>(
                          value: _selectedPredefinedTemplate,
                          items: [
                            const DropdownMenuItem<PredefinedAgendaTemplate?>(value: null, child: Text("Sélectionnez...", style: TextStyle(color: Colors.grey))),
                            ...predefinedAgendaTemplates.map((template) => DropdownMenuItem(value: template, child: Text(template.templateName))).toList(),
                          ],
                          onChanged: (template) {
                            setState(() {
                              _selectedPredefinedTemplate = template;
                              _nameController.text = template?.suggestedAgendaName ?? '';
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Modèle thématique', border: OutlineInputBorder()),
                          validator: (value) => value == null ? 'Choisissez un modèle.' : null,
                          isExpanded: true,
                        ),
                      ],

                      // --- Section Agenda Existant ---
                      // --- SECTION CONDITIONNELLE : AGENDA EXISTANT ---
                      if (_selectedMode == CreationMode.existingAgenda) ...[
                        Text("Choisir un agenda comme modèle :", style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        StreamBuilder<List<Agenda>>(
                          stream: firestoreService.getUserAgendasStream(userId),
                          builder: (context, snapshot) {
                            // --- GESTION DE L'ATTENTE ---
                            if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                              // Afficher un indicateur de chargement centré
                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
                            }
                            // --- GESTION DES ERREURS ---
                            if (snapshot.hasError) {
                              // Afficher un message d'erreur clair
                              print("Error loading existing agendas: ${snapshot.error}"); // Garder un log pour le debug
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  "Erreur lors du chargement de vos agendas.\n(${snapshot.error})", // Afficher l'erreur peut aider au debug
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            final existingAgendas = snapshot.data ?? [];
                            if (existingAgendas.isEmpty) {
                              // Vérifier s'il y a au moins 1 agenda à copier
                              return const Text("Aucun agenda disponible pour servir de modèle.", style: TextStyle(fontStyle: FontStyle.italic));
                            }

                            // Construire les items avec agenda.id comme valeur
                            final List<DropdownMenuItem<String?>> items = [
                              const DropdownMenuItem<String?>(value: null, child: Text("Sélectionnez l'agenda source...", style: TextStyle(color: Colors.grey))),
                              ...existingAgendas
                                  .map(
                                    (agenda) => DropdownMenuItem<String?>(
                                      // Type String?
                                      value: agenda.id, // <<< Utiliser agenda.id comme valeur
                                      child: Text(agenda.name),
                                    ),
                                  )
                                  .toList(),
                            ];

                            // Vérifier si la valeur sélectionnée existe
                            bool valueExists = items.any((item) => item.value == _selectedExistingAgendaId);
                            String? valueForDropdown = valueExists ? _selectedExistingAgendaId : null;

                            // Logique de reset post-build (optionnelle mais sûre)
                            if (_selectedExistingAgendaId != null && !valueExists) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && _selectedExistingAgendaId != null && !items.any((item) => item.value == _selectedExistingAgendaId)) {
                                  setState(() {
                                    _selectedExistingAgendaId = null;
                                    _selectedExistingAgendaTemplate = null;
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
                                // Reçoit l'ID (String?) de l'agenda
                                // 'existingAgendas' doit être accessible depuis le scope du builder parent
                                final List<Agenda> localExistingAgendas = existingAgendas; // Recréer ici par sécurité si besoin

                                setState(() {
                                  _selectedExistingAgendaId = newValue; // Met à jour l'ID stocké
                                  _selectedExistingAgendaTemplate = null; // Réinitialise l'objet trouvé

                                  if (newValue != null) {
                                    try {
                                      // Essayer de trouver l'objet Agenda correspondant à l'ID
                                      _selectedExistingAgendaTemplate = localExistingAgendas.firstWhere(
                                        (agenda) => agenda.id == newValue,
                                        // Pas de orElse: ici !
                                      );
                                    } on StateError catch (_) {
                                      // Gérer le cas où l'agenda n'est pas trouvé
                                      print(">>> INFO: Selected agenda ID '$newValue' not found (StateError caught).");
                                      _selectedExistingAgendaTemplate = null;
                                    } catch (e) {
                                      // Gérer toute autre erreur
                                      print(">>> ERROR during existing agenda lookup: $e");
                                      _selectedExistingAgendaTemplate = null;
                                    }
                                  }

                                  // Pré-remplir le nom
                                  _nameController.text = _selectedExistingAgendaTemplate != null ? 'Copie de ${_selectedExistingAgendaTemplate!.name}' : '';

                                  print("--- ExistingAgenda Dropdown onChanged ---");
                                  print("newValue (agendaId) received: $newValue");
                                  print("Selected ExistingAgenda object set to: ${_selectedExistingAgendaTemplate?.name}");
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Agenda source à copier', border: OutlineInputBorder()),
                              validator: (value) => value == null ? 'Choisissez un agenda source.' : null,
                              isExpanded: true,
                            );
                          },
                        ),
                      ], // Fin Section Agenda Existant
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
    );
  }
}
