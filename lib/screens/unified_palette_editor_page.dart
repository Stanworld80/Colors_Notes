// lib/screens/unified_palette_editor_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../widgets/inline_palette_editor.dart'; // Notre widget réutilisable
import '../widgets/loading_indicator.dart'; // Assurez-vous d'avoir ce widget

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
const _uuid = Uuid();

class UnifiedPaletteEditorPage extends StatefulWidget {
  final Journal? journalToUpdatePaletteFor; // Pour éditer la palette d'un journal existant
  final PaletteModel? paletteModelToEdit;   // Pour éditer un modèle de palette existant
  // Si les deux sont null, c'est pour créer un nouveau modèle de palette

  const UnifiedPaletteEditorPage({
    Key? key,
    this.journalToUpdatePaletteFor,
    this.paletteModelToEdit,
  }) : super(key: key);

  @override
  _UnifiedPaletteEditorPageState createState() => _UnifiedPaletteEditorPageState();
}

class _UnifiedPaletteEditorPageState extends State<UnifiedPaletteEditorPage> {
  final _formKey = GlobalKey<FormState>(); // Clé pour le Form qui contiendra l'éditeur

  late String _currentPaletteName;
  late List<ColorData> _currentColors;

  bool _isLoading = false;
  String? _userId;
  bool _isEditingModel = false; // Détermine si on édite un modèle ou une instance de journal
  String _pageTitle = "";
  bool _hasChanges = false; // <-- NOUVEAU: Flag pour suivre les changements

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false;
      _currentPaletteName = widget.journalToUpdatePaletteFor!.palette.name;
      _currentColors = widget.journalToUpdatePaletteFor!.palette.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Modifier Palette: ${widget.journalToUpdatePaletteFor!.name}";
    } else if (widget.paletteModelToEdit != null) {
      _isEditingModel = true;
      _currentPaletteName = widget.paletteModelToEdit!.name;
      _currentColors = widget.paletteModelToEdit!.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Modifier Modèle: ${widget.paletteModelToEdit!.name}";
    } else {
      // Création d'un nouveau modèle
      _isEditingModel = true;
      _currentPaletteName = "";
      _currentColors = [];
      _pageTitle = "Nouveau Modèle de Palette";
      // Un nouveau modèle commence sans changement (l'utilisateur doit en faire)
      _hasChanges = false;
    }
  }

  /// Marque qu'un changement a eu lieu.
  void _markChanges() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _savePalette() async {
    // 1. Valider le formulaire (contient le nom de la palette)
    if (!_formKey.currentState!.validate()) {
      _loggerPage.w("Validation du formulaire échouée.");
      return;
    }

    // 2. Vérifier s'il y a réellement des changements (comparer avec l'état initial si nécessaire ou se fier à _hasChanges)
    if (!_hasChanges) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Aucune modification à sauvegarder.")));
      return;
    }

    // 3. Valider les règles métier (nombre de couleurs)
    if (_currentPaletteName.trim().isEmpty) { // Redondant avec validator mais double check
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Le nom de la palette ne peut pas être vide."), backgroundColor: Colors.orange));
      return;
    }
    // Utiliser les constantes définies dans InlinePaletteEditorWidget ou les redéfinir ici
    if (_currentColors.length < MIN_COLORS_IN_PALETTE_PREVIEW && _isEditingModel) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle doit avoir au moins $MIN_COLORS_IN_PALETTE_PREVIEW couleurs."), backgroundColor: Colors.orange));
      return;
    }
    if (_currentColors.length > MAX_COLORS_IN_PALETTE_PREVIEW) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Une palette ne peut pas avoir plus de $MAX_COLORS_IN_PALETTE_PREVIEW couleurs."), backgroundColor: Colors.orange));
      return;
    }

    // 4. Vérifier l'utilisateur
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur non identifié."), backgroundColor: Colors.red));
      return;
    }

    // 5. Procéder à la sauvegarde
    setState(() { _isLoading = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final navigator = Navigator.of(context); // Capture navigator before async gap
    bool saveSucceeded = false;

    try {
      if (_isEditingModel) {
        // Sauvegarde d'un modèle de palette
        if (widget.paletteModelToEdit == null) { // Création
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!);
          if (nameExists) {
            throw Exception("Un modèle de palette avec ce nom existe déjà.");
          }
          final newModel = PaletteModel(
            id: _uuid.v4(),
            name: _currentPaletteName,
            colors: _currentColors,
            userId: _userId!,
            isPredefined: false,
          );
          await firestoreService.createPaletteModel(newModel);
          _loggerPage.i("Nouveau modèle de palette créé: ${newModel.name}");
        } else { // Modification
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!, excludeId: widget.paletteModelToEdit!.id);
          if (nameExists) {
            throw Exception("Un autre modèle de palette avec ce nom existe déjà.");
          }
          final updatedModel = widget.paletteModelToEdit!.copyWith(
            name: _currentPaletteName,
            colors: _currentColors,
          );
          await firestoreService.updatePaletteModel(updatedModel);
          _loggerPage.i("Modèle de palette mis à jour: ${updatedModel.name}");
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Modèle de palette sauvegardé."), backgroundColor: Colors.green));
        saveSucceeded = true;

      } else if (widget.journalToUpdatePaletteFor != null) {
        // Sauvegarde de la palette d'une instance de journal
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(
          name: _currentPaletteName,
          colors: _currentColors,
        );

        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

        // Mettre à jour le journal actif dans le provider
        final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
        if (activeJournalNotifier.activeJournalId == currentJournal.id) {
          await activeJournalNotifier.setActiveJournal(currentJournal.id, _userId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Palette du journal sauvegardée."), backgroundColor: Colors.green));
        saveSucceeded = true;
      }

      // Réinitialiser le flag de changement UNIQUEMENT si la sauvegarde a réussi
      if (saveSucceeded) {
        setState(() {
          _hasChanges = false;
        });
      }
      // Optionnel: Quitter la page après sauvegarde réussie
      // if (saveSucceeded && mounted) navigator.pop();

    } catch (e) {
      _loggerPage.e("Erreur sauvegarde palette: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.red));
      // Ne pas réinitialiser _hasChanges si erreur
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  /// Gère le bouton retour. Demande confirmation si des changements existent.
  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true; // Autoriser retour si pas de changements
    }

    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // L'utilisateur doit choisir une option
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Modifications non sauvegardées'),
          content: const Text('Voulez-vous sauvegarder vos modifications avant de quitter ?'),
          actions: <Widget>[
            // Bouton Annuler
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop(false); // Ne pas quitter la page
              },
            ),
            // Bouton Ne pas Sauvegarder
            TextButton(
              child: Text(
                'Quitter sans sauvegarder',
                style: TextStyle(color: Theme.of(context).colorScheme.error), // Style rouge
              ),
              onPressed: () {
                Navigator.of(context).pop(true); // Quitter la page
              },
            ),
            // Bouton Sauvegarder et Quitter
            FilledButton(
              child: const Text('Sauvegarder et Quitter'),
              onPressed: () async {
                // Tenter de sauvegarder
                await _savePalette();
                // Vérifier si le widget est toujours monté après l'opération asynchrone
                if (!mounted) return;
                // Quitter SEULEMENT si la sauvegarde a réussi (donc _hasChanges est false)
                Navigator.of(context).pop(!_hasChanges);
              },
            ),
          ],
        );
      },
    );

    // Retourner la décision de la popup (true pour quitter, false pour rester)
    return shouldPop ?? false; // Retourner false par défaut si la popup est fermée autrement
  }


  @override
  Widget build(BuildContext context) {
    // Utiliser WillPopScope pour intercepter la navigation retour
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_pageTitle),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save_alt_outlined),
                // Désactiver si pas de changements ou si chargement en cours
                onPressed: (_hasChanges && !_isLoading) ? _savePalette : null,
                tooltip: "Sauvegarder les modifications",
              )
          ],
        ),
        body: Stack( // Utiliser Stack pour le loading indicator
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey, // La clé de formulaire est ici
                child: InlinePaletteEditorWidget(
                  // Donner une clé unique si la source de données (journal/modèle) peut changer PENDANT que cette page est ouverte
                  // key: ValueKey(widget.journalToUpdatePaletteFor?.id ?? widget.paletteModelToEdit?.id ?? 'new'),
                  initialPaletteName: _currentPaletteName,
                  initialColors: _currentColors,
                  onPaletteNameChanged: (newName) {
                    // Mettre à jour l'état local ET marquer les changements
                    if (_currentPaletteName != newName) {
                      setState(() {
                        _currentPaletteName = newName;
                      });
                      _markChanges();
                    }
                  },
                  onColorsChanged: (newColors) {
                    // Mettre à jour l'état local ET marquer les changements
                    // Comparaison plus robuste serait bien, mais pour l'instant on marque au moindre appel
                    setState(() {
                      _currentColors = newColors;
                    });
                    _markChanges();
                  },
                ),
              ),
            ),
            // Indicateur de chargement en superposition
            if (_isLoading) const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
