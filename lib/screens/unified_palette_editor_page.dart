import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../models/journal.dart';
import '../models/palette.dart';
import '../models/palette_model.dart';
import '../models/color_data.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../widgets/inline_palette_editor.dart';
import '../widgets/loading_indicator.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 1, printTime: true));
const _uuid = Uuid();

class UnifiedPaletteEditorPage extends StatefulWidget {
  final Journal? journalToUpdatePaletteFor;
  final PaletteModel? paletteModelToEdit;

  const UnifiedPaletteEditorPage({Key? key, this.journalToUpdatePaletteFor, this.paletteModelToEdit}) : super(key: key);

  @override
  _UnifiedPaletteEditorPageState createState() => _UnifiedPaletteEditorPageState();
}

class _UnifiedPaletteEditorPageState extends State<UnifiedPaletteEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late String _currentPaletteName;
  late List<ColorData> _currentColors;

  late String _initialPaletteNameToCompare;
  late List<ColorData> _initialColorsToCompare;

  bool _isLoading = false;
  String? _userId;
  bool _isEditingModel = false;
  String _pageTitle = "";
  bool _hasMadeChangesSinceLastSave = false;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;

    if (widget.journalToUpdatePaletteFor != null) {
      _isEditingModel = false;
      final palette = widget.journalToUpdatePaletteFor!.palette;
      _currentPaletteName = palette.name;
      _currentColors = palette.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Palette: ${widget.journalToUpdatePaletteFor!.name}";
    } else if (widget.paletteModelToEdit != null) {
      _isEditingModel = true;
      final model = widget.paletteModelToEdit!;
      _currentPaletteName = model.name;
      _currentColors = model.colors.map((c) => c.copyWith()).toList();
      _pageTitle = "Modèle: ${model.name}";
    } else {
      _isEditingModel = true;
      _currentPaletteName = "Nouveau Modèle de Palette";
      _currentColors = [];
      _pageTitle = "Nouveau Modèle de Palette";
      _hasMadeChangesSinceLastSave = true;
    }
    _initialPaletteNameToCompare = _currentPaletteName;
    _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
  }

  bool _checkForActualChanges() {
    if (_currentPaletteName != _initialPaletteNameToCompare) return true;
    if (_currentColors.length != _initialColorsToCompare.length) return true;
    for (int i = 0; i < _currentColors.length; i++) {
      if (_currentColors[i].paletteElementId != _initialColorsToCompare[i].paletteElementId ||
          _currentColors[i].title != _initialColorsToCompare[i].title ||
          _currentColors[i].hexCode != _initialColorsToCompare[i].hexCode) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _canDeleteColor(String paletteElementId) async {
    if (widget.journalToUpdatePaletteFor == null || _userId == null) {
      return true;
    }
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final isUsed = await firestoreService.isPaletteElementUsedInNotes(widget.journalToUpdatePaletteFor!.id, paletteElementId);
      return !isUsed;
    } catch (e) {
      _loggerPage.e("Erreur vérification utilisation couleur: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur vérification utilisation couleur: ${e.toString()}'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _triggerAutomaticSave() async {
    if (!_checkForActualChanges() && !_hasMadeChangesSinceLastSave) {
      _loggerPage.i("Aucun changement réel détecté, sauvegarde automatique annulée.");
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _loggerPage.w("Validation du formulaire (nom palette) échouée lors de la sauvegarde auto.");
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (_currentColors.isEmpty && _isEditingModel) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Un modèle de palette doit avoir au moins $MIN_COLORS_IN_PALETTE_EDITOR couleur."), backgroundColor: Colors.orange));
      _hasMadeChangesSinceLastSave = true;
      return;
    } else if (_currentColors.isNotEmpty) {}

    if (_currentColors.length > MAX_COLORS_IN_PALETTE_EDITOR) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Une palette ne peut pas avoir plus de $MAX_COLORS_IN_PALETTE_EDITOR couleurs."), backgroundColor: Colors.orange));
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié."), backgroundColor: Colors.red));
      _hasMadeChangesSinceLastSave = true;
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    bool saveSucceeded = false;
    PaletteModel? createdModel;

    try {
      if (!_isEditingModel && widget.journalToUpdatePaletteFor != null) {
        List<String> attemptedDeletionsFailed = [];
        for (var initialColor in _initialColorsToCompare) {
          if (!_currentColors.any((currentColor) => currentColor.paletteElementId == initialColor.paletteElementId)) {
            final bool canActuallyDelete = await _canDeleteColor(initialColor.paletteElementId);
            if (!canActuallyDelete) {
              attemptedDeletionsFailed.add(initialColor.title);
            }
          }
        }
        if (attemptedDeletionsFailed.isNotEmpty) {
          throw Exception("Sauvegarde bloquée : La/les couleur(s) '${attemptedDeletionsFailed.join(', ')}' est/sont utilisée(s) et ne peuvent être supprimées.");
        }
      }

      if (_isEditingModel) {
        if (widget.paletteModelToEdit == null) {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!);
          if (nameExists) throw Exception("Un modèle de palette avec ce nom existe déjà.");

          createdModel = PaletteModel(id: _uuid.v4(), name: _currentPaletteName, colors: _currentColors, userId: _userId!, isPredefined: false);
          await firestoreService.createPaletteModel(createdModel);
          _loggerPage.i("Nouveau modèle de palette créé: ${createdModel.name}");
          if (mounted && _pageTitle == "Nouveau Modèle de Palette") {
            setState(() {
              _pageTitle = "Modèle: ${createdModel!.name}";
            });
          }
        } else {
          bool nameExists = await firestoreService.checkPaletteModelNameExists(_currentPaletteName, _userId!, excludeId: widget.paletteModelToEdit!.id);
          if (nameExists) throw Exception("Un autre modèle de palette avec ce nom existe déjà.");

          final updatedModel = widget.paletteModelToEdit!.copyWith(name: _currentPaletteName, colors: _currentColors);
          await firestoreService.updatePaletteModel(updatedModel);
          _loggerPage.i("Modèle de palette mis à jour: ${updatedModel.name}");
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modèle de palette sauvegardé."), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        saveSucceeded = true;
      } else if (widget.journalToUpdatePaletteFor != null) {
        final Journal currentJournal = widget.journalToUpdatePaletteFor!;
        final Palette updatedPaletteInstance = currentJournal.palette.copyWith(name: _currentPaletteName, colors: _currentColors);
        await firestoreService.updateJournalPaletteInstance(currentJournal.id, updatedPaletteInstance);
        _loggerPage.i("Palette du journal ${currentJournal.name} mise à jour.");

        final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
        if (activeJournalNotifier.activeJournalId == currentJournal.id) {
          await activeJournalNotifier.setActiveJournal(currentJournal.id, _userId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Palette du journal sauvegardée."), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        saveSucceeded = true;
      }

      if (saveSucceeded) {
        if (mounted) {
          setState(() {
            _hasMadeChangesSinceLastSave = false;
            _initialPaletteNameToCompare = _currentPaletteName;
            _initialColorsToCompare = _currentColors.map((c) => c.copyWith()).toList();
          });
        }
      } else {
        _hasMadeChangesSinceLastSave = true;
      }
    } catch (e) {
      _loggerPage.e("Erreur sauvegarde palette: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur de sauvegarde: ${e.toString()}"), backgroundColor: Colors.red));
      _hasMadeChangesSinceLastSave = true;
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<bool> _handleDeleteAllColorsRequested() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié.")));
      return false;
    }

    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer toutes les couleurs ?'),
          content: Text(
            !_isEditingModel && widget.journalToUpdatePaletteFor != null
                ? 'Cela supprimera toutes les couleurs de la palette du journal "${widget.journalToUpdatePaletteFor!.name}". ATTENTION : Toutes les notes de ce journal seront également DÉFINITIVEMENT supprimées.'
                : 'Voulez-vous vraiment supprimer toutes les couleurs de ce modèle de palette ?',
          ),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer Tout'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (firstConfirm != true) return false;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(!_isEditingModel ? 'CONFIRMATION FINALE' : 'Confirmer la suppression'),
          content: Text(
            !_isEditingModel
                ? 'Êtes-vous absolument certain(e) ? La suppression des couleurs de cette palette entraînera la suppression IRRÉVERSIBLE de TOUTES les notes de ce journal.'
                : 'Confirmez-vous la suppression de toutes les couleurs de ce modèle ?',
          ),
          actions: <Widget>[
            TextButton(child: const Text('NON, ANNULER'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('OUI, TOUT SUPPRIMER'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (secondConfirm != true) return false;

    if (mounted)
      setState(() {
        _isLoading = true;
      });
    try {
      if (!_isEditingModel && widget.journalToUpdatePaletteFor != null) {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        await firestoreService.deleteAllNotesInJournal(widget.journalToUpdatePaletteFor!.id, _userId!);
        _loggerPage.i("Toutes les notes du journal ${widget.journalToUpdatePaletteFor!.id} ont été supprimées avant de vider la palette.");
      }
      return true;
    } catch (e) {
      _loggerPage.e("Erreur lors de la suppression de toutes les couleurs/notes: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  Future<bool> _onWillPop() async {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegarde en cours, veuillez patienter..."), duration: Duration(seconds: 1)));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_pageTitle),
              actions: [if (_isLoading) const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)))],
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: InlinePaletteEditorWidget(
                      key: ValueKey(widget.journalToUpdatePaletteFor?.id ?? widget.paletteModelToEdit?.id ?? 'new_palette_editor_autosave_instance'),
                      initialPaletteName: _currentPaletteName,
                      initialColors: _currentColors,
                      isEditingJournalPalette: !_isEditingModel,
                      canDeleteColorCallback: !_isEditingModel ? _canDeleteColor : null,
                      onPaletteNameChanged: (newName) {
                        if (_currentPaletteName != newName) {
                          if (mounted) {
                            setState(() {
                              _currentPaletteName = newName;
                              _hasMadeChangesSinceLastSave = true;
                            });
                          }
                        }
                      },
                      onColorsChanged: (newColors) {
                        if (mounted) {
                          setState(() {
                            _currentColors = newColors;
                            _hasMadeChangesSinceLastSave = true;
                          });
                        }
                      },
                      onPaletteNeedsSave: _triggerAutomaticSave,
                      showNameEditor: _isEditingModel,
                      onDeleteAllColorsRequested: _handleDeleteAllColorsRequested,
                    ),
                  ),
                ),
                if (_isLoading) const LoadingIndicator(),
              ],
            ),
          ),
        );
      }
    );
  }
}
