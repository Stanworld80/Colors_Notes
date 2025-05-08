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

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false;
      _currentPaletteName = widget.journalToUpdatePaletteFor!.palette.name;
      // Copie profonde pour l'édition
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
      _currentPaletteName = ""; // Laisser vide pour que l'utilisateur nomme
      _currentColors = [
        // Optionnel: quelques couleurs par défaut pour un nouveau modèle
        // ColorData(paletteElementId: _uuid.v4(), title: "Couleur 1", hexCode: "#FF0000"),
      ];
      _pageTitle = "Nouveau Modèle de Palette";
    }
  }

  Future<void> _savePalette() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur non identifié."), backgroundColor: Colors.red));
      return;
    }

    // Valider le formulaire (qui contient le nom de la palette dans InlinePaletteEditorWidget)
    if (!_formKey.currentState!.validate()) {
      _loggerPage.w("Validation du formulaire échouée.");
      return; // Le TextFormField dans InlinePaletteEditorWidget affichera l'erreur
    }

    // _currentPaletteName est mis à jour par le callback onPaletteNameChanged de InlinePaletteEditorWidget
    // _currentColors est mis à jour par le callback onColorsChanged

    if (_currentPaletteName.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Le nom de la palette ne peut pas être vide."), backgroundColor: Colors.orange));
      return;
    }
    if (_currentColors.length < MIN_COLORS_IN_PALETTE_PREVIEW && _isEditingModel) { // Ajuster la constante si besoin
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle doit avoir au moins $MIN_COLORS_IN_PALETTE_PREVIEW couleurs."), backgroundColor: Colors.orange));
      return;
    }
    if (_currentColors.length > MAX_COLORS_IN_PALETTE_PREVIEW) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Une palette ne peut pas avoir plus de $MAX_COLORS_IN_PALETTE_PREVIEW couleurs."), backgroundColor: Colors.orange));
      return;
    }


    setState(() { _isLoading = true; });
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    try {
      if (_isEditingModel) {
        // Sauvegarde d'un modèle de palette
        if (widget.paletteModelToEdit == null) { // Création
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!);
          if (nameExists) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle de palette avec ce nom existe déjà."), backgroundColor: Colors.orange));
            setState(() { _isLoading = false; });
            return;
          }
          final newModel = PaletteModel(
            id: _uuid.v4(), // Générer un nouvel ID pour le modèle
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
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un autre modèle de palette avec ce nom existe déjà."), backgroundColor: Colors.orange));
            setState(() { _isLoading = false; });
            return;
          }
          final updatedModel = widget.paletteModelToEdit!.copyWith(
            name: _currentPaletteName,
            colors: _currentColors,
          );
          await firestoreService.updatePaletteModel(updatedModel);
          _loggerPage.i("Modèle de palette mis à jour: ${updatedModel.name}");
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Modèle de palette sauvegardé."), backgroundColor: Colors.green));

      } else if (widget.journalToUpdatePaletteFor != null) {
        // Sauvegarde de la palette d'une instance de journal
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(
          name: _currentPaletteName, // Le nom de l'instance de palette peut aussi être modifié
          colors: _currentColors,
        );

        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

        // Mettre à jour le journal actif dans le provider si c'est celui qui a été modifié
        final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
        if (activeJournalNotifier.activeJournalId == currentJournal.id) {
          // Forcer le rechargement du journal actif
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save_alt_outlined),
              onPressed: _savePalette,
              tooltip: "Sauvegarder les modifications",
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // La clé de formulaire est ici
          child: InlinePaletteEditorWidget(
            // Pas besoin de Key ici car la page entière est reconstruite si les args changent
            initialPaletteName: _currentPaletteName,
            initialColors: _currentColors,
            onPaletteNameChanged: (newName) {
              // Le TextFormField dans InlinePaletteEditorWidget a son propre controller.
              // Nous récupérons la valeur finale lors de la sauvegarde.
              // Mais si on veut une validation en temps réel sur cette page, on met à jour l'état.
              setState(() {
                _currentPaletteName = newName;
              });
            },
            onColorsChanged: (newColors) {
              setState(() {
                _currentColors = newColors;
              });
            },
          ),
        ),
      ),
    );
  }
}
