// lib/screens/entry_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../providers/active_journal_provider.dart';
import '../models/color_data.dart'; // Importation nécessaire pour le sélecteur de couleur

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

class EntryPage extends StatefulWidget {
  final String journalId;
  final Note? noteToEdit;
  final String? initialPaletteElementId;

  EntryPage({
    Key? key,
    required this.journalId,
    this.noteToEdit,
    this.initialPaletteElementId,
  }) : super(key: key);

  @override
  _EntryPageState createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  String? _selectedPaletteElementId;
  DateTime _selectedEventDate = DateTime.now();
  TimeOfDay _selectedEventTime = TimeOfDay.now();

  Journal? _currentJournalDetails;
  bool _isLoadingJournalDetails = true;
  String? _userId;
  bool _isSaving = false;
  bool _isSavingAsNew = false;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    _contentController = TextEditingController(text: widget.noteToEdit?.content);

    if (widget.noteToEdit != null) {
      _selectedPaletteElementId = widget.noteToEdit!.paletteElementId;
      _selectedEventDate = widget.noteToEdit!.eventTimestamp.toDate();
      _selectedEventTime = TimeOfDay.fromDateTime(_selectedEventDate);
    } else {
      _selectedPaletteElementId = widget.initialPaletteElementId;
      // Pour une nouvelle note, la date et l'heure sont déjà initialisées à "maintenant"
    }
    _loadJournalDetails();
  }

  Future<void> _loadJournalDetails() async {
    if (!mounted) return;
    setState(() { _isLoadingJournalDetails = true; });
    try {
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
      if (activeJournalNotifier.activeJournalId == widget.journalId && activeJournalNotifier.activeJournal != null) {
        _currentJournalDetails = activeJournalNotifier.activeJournal;
      } else {
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        final journalDoc = await firestoreService.getJournalStream(widget.journalId).first;
        if (journalDoc.exists && journalDoc.data() != null) {
          _currentJournalDetails = Journal.fromMap(journalDoc.data() as Map<String, dynamic>, journalDoc.id);
        } else {
          throw Exception("Journal non trouvé ou inaccessible.");
        }
      }

      if (widget.noteToEdit == null && _selectedPaletteElementId == null && _currentJournalDetails != null && _currentJournalDetails!.palette.colors.isNotEmpty) {
        final defaultColor = _currentJournalDetails!.palette.colors.firstWhere((c) => c.isDefault, orElse: () => _currentJournalDetails!.palette.colors.first);
        _selectedPaletteElementId = defaultColor.paletteElementId;
      }
      else if (widget.noteToEdit != null && _currentJournalDetails != null) {
        bool currentPaletteElementExists = _currentJournalDetails!.palette.colors.any((c) => c.paletteElementId == _selectedPaletteElementId);
        if (!currentPaletteElementExists && _currentJournalDetails!.palette.colors.isNotEmpty) {
          _selectedPaletteElementId = _currentJournalDetails!.palette.colors.first.paletteElementId;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("La couleur d'origine de cette note n'existe plus dans la palette. Une couleur par défaut a été sélectionnée."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else if (!currentPaletteElementExists && _currentJournalDetails!.palette.colors.isEmpty) {
          _selectedPaletteElementId = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("La palette de ce journal est vide. Veuillez ajouter des couleurs à la palette pour pouvoir associer cette note."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      _loggerPage.e("Erreur chargement détails journal: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement détails journal: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingJournalDetails = false; });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectEventDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEventDate,
      firstDate: DateTime(DateTime.now().year - 50),
      lastDate: DateTime(DateTime.now().year + 50),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedEventDate) {
      if (mounted) {
        setState(() {
          _selectedEventDate = picked;
        });
      }
    }
  }

  Future<void> _selectEventTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEventTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedEventTime) {
      if (mounted) {
        setState(() {
          _selectedEventTime = picked;
        });
      }
    }
  }

  // NOUVELLE méthode pour régler la date et l'heure sur "maintenant"
  void _setDateTimeToNow() {
    if (mounted) {
      final now = DateTime.now();
      setState(() {
        _selectedEventDate = now;
        _selectedEventTime = TimeOfDay.fromDateTime(now);
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Date et heure réglées sur maintenant."), duration: Duration(seconds: 2))
      );
    }
  }

  Future<void> _saveNote() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPaletteElementId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner une couleur pour la note.")));
      return;
    }

    if (mounted) setState(() { _isSaving = true; });

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final eventTimestamp = Timestamp.fromDate(DateTime(
      _selectedEventDate.year,
      _selectedEventDate.month,
      _selectedEventDate.day,
      _selectedEventTime.hour,
      _selectedEventTime.minute,
    ));

    try {
      if (widget.noteToEdit == null) {
        final newNote = Note(
          id: _uuid.v4(),
          journalId: widget.journalId,
          userId: _userId!,
          content: _contentController.text.trim(),
          paletteElementId: _selectedPaletteElementId!,
          eventTimestamp: eventTimestamp,
          createdAt: Timestamp.now(),
          lastUpdatedAt: Timestamp.now(),
        );
        await firestoreService.createNote(newNote);
        _loggerPage.i("Note créée: ${newNote.id}");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note sauvegardée.")));
      } else {
        final updatedNote = widget.noteToEdit!.copyWith(
          content: _contentController.text.trim(),
          paletteElementId: _selectedPaletteElementId,
          eventTimestamp: eventTimestamp,
          lastUpdatedAt: Timestamp.now(),
        );
        await firestoreService.updateNote(updatedNote);
        _loggerPage.i("Note mise à jour: ${updatedNote.id}");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note mise à jour.")));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _loggerPage.e("Erreur sauvegarde note: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  Future<void> _saveAsNewNote() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPaletteElementId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez sélectionner une couleur pour la nouvelle note.")));
      return;
    }

    if (mounted) setState(() { _isSavingAsNew = true; });

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final eventTimestamp = Timestamp.fromDate(DateTime(
      _selectedEventDate.year,
      _selectedEventDate.month,
      _selectedEventDate.day,
      _selectedEventTime.hour,
      _selectedEventTime.minute,
    ));

    try {
      final newNote = Note(
        id: _uuid.v4(),
        journalId: widget.journalId,
        userId: _userId!,
        content: _contentController.text.trim(),
        paletteElementId: _selectedPaletteElementId!,
        eventTimestamp: eventTimestamp,
        createdAt: Timestamp.now(),
        lastUpdatedAt: Timestamp.now(),
      );
      await firestoreService.createNote(newNote);
      _loggerPage.i("Note sauvegardée comme nouvelle: ${newNote.id}");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note sauvegardée comme nouvelle.")));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _loggerPage.e("Erreur sauvegarde comme nouvelle note: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSavingAsNew = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR'); // Changé pour yyyy pour l'année complète
    final bool isEditing = widget.noteToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la Note' : 'Nouvelle Note'),
        actions: [
          if (_isSaving || _isSavingAsNew)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
            )
          else
            IconButton(
              icon: const Icon(Icons.save_alt_outlined),
              onPressed: _saveNote,
              tooltip: isEditing ? "Mettre à jour la note" : "Sauvegarder la note",
            )
        ],
      ),
      body: _isLoadingJournalDetails
          ? const Center(child: CircularProgressIndicator())
          : _currentJournalDetails == null
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              const Text("Impossible de charger les détails du journal."),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _loadJournalDetails, child: const Text("Réessayer"))
            ],
          ))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_currentJournalDetails!.palette.colors.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedPaletteElementId,
                  decoration: InputDecoration(
                    labelText: 'Couleur associée',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

                  ),
                  items: _currentJournalDetails!.palette.colors.map((ColorData colorData) {
                    return DropdownMenuItem<String>(
                      value: colorData.paletteElementId,
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: colorData.color, radius: 10),
                          const SizedBox(width: 10),
                          Text(colorData.title),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (mounted) {
                      setState(() {
                        _selectedPaletteElementId = newValue;
                      });
                    }
                  },
                  validator: (value) => value == null ? 'Veuillez choisir une couleur.' : null,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Aucune couleur disponible dans la palette de ce journal. Veuillez d'abord ajouter des couleurs à la palette.",
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Contenu de la note...',
                  hintText: 'Décrivez votre pensée, événement, ou tâche...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null ) {
                    return 'Veuillez entrer le contenu de la note.';
                  }
                  if (value.length > 1024) {
                    return 'Le contenu est trop long (max 1024 caractères).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Section pour la date et l'heure
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateFormat.format(_selectedEventDate)),
                      onPressed: () => _selectEventDate(context),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Ajustement du padding
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).dividerColor)
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Espace réduit
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.access_time_outlined),
                      label: Text(_selectedEventTime.format(context)),
                      onPressed: () => _selectEventTime(context),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Ajustement du padding
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).dividerColor)
                      ),
                    ),
                  ),
                  // NOUVEAU BOUTON "Maintenant"
                  const SizedBox(width: 8),
                  Tooltip(
                    message: "Régler sur maintenant",
                    child: IconButton(
                      icon: const Icon(Icons.arrow_circle_left_outlined),
                      onPressed: _setDateTimeToNow,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: Icon(_isSaving ? Icons.hourglass_empty_outlined : (isEditing ? Icons.sync_alt_outlined : Icons.save_outlined)),
                label: Text(_isSaving ? "Sauvegarde..." : (isEditing ? 'Mettre à jour la Note' : 'Sauvegarder la Note')),
                onPressed: (_isSaving || _isSavingAsNew || _selectedPaletteElementId == null) ? null : _saveNote,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 16)
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 15),
                OutlinedButton.icon(
                  icon: Icon(_isSavingAsNew ? Icons.hourglass_empty_outlined : Icons.add_circle_outline),
                  label: Text(_isSavingAsNew ? "Sauvegarde..." : 'Sauvegarder comme nouvelle note'),
                  onPressed: (_isSaving || _isSavingAsNew || _selectedPaletteElementId == null) ? null : _saveAsNewNote,
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary)
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
