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
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

class EntryPage extends StatefulWidget {
  final String journalId;
  final Note? noteToEdit;

  EntryPage({Key? key, required this.journalId, this.noteToEdit}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    _contentController = TextEditingController(text: widget.noteToEdit?.content);
    _selectedPaletteElementId = widget.noteToEdit?.paletteElementId;
    if (widget.noteToEdit != null) {
      _selectedEventDate = widget.noteToEdit!.eventTimestamp.toDate();
      _selectedEventTime = TimeOfDay.fromDateTime(_selectedEventDate);
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

      if (widget.noteToEdit == null && _currentJournalDetails != null && _currentJournalDetails!.palette.colors.isNotEmpty) {
        final defaultColor = _currentJournalDetails!.palette.colors.firstWhere((c) => c.isDefault, orElse: () => _currentJournalDetails!.palette.colors.first);
        _selectedPaletteElementId = defaultColor.paletteElementId;
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
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
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

  Future<void> _saveNote() async {
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur non identifié.")));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPaletteElementId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Veuillez sélectionner une couleur.")));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Note sauvegardée.")));
      } else {
        final updatedNote = widget.noteToEdit!.copyWith(
          content: _contentController.text.trim(),
          paletteElementId: _selectedPaletteElementId,
          eventTimestamp: eventTimestamp,
          lastUpdatedAt: Timestamp.now(),
        );
        await firestoreService.updateNote(updatedNote);
        _loggerPage.i("Note mise à jour: ${updatedNote.id}");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Note mise à jour.")));
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

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteToEdit == null ? 'Nouvelle Note' : 'Modifier la Note'),
        actions: [
          if (_isSaving) Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else
            IconButton(
              icon: Icon(Icons.save_alt_outlined),
              onPressed: _saveNote,
              tooltip: "Sauvegarder",
            )
        ],
      ),
      body: _isLoadingJournalDetails
          ? Center(child: CircularProgressIndicator())
          : _currentJournalDetails == null
          ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              SizedBox(height: 8),
              Text("Impossible de charger les détails du journal."),
              SizedBox(height: 8),
              ElevatedButton(onPressed: _loadJournalDetails, child: Text("Réessayer"))
            ],
          )
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: 'Contenu de la note',
                  hintText: 'Décrivez votre humeur, événement, pensée...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le contenu de la note.';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Text("Date et Heure de l'événement:", style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(Icons.calendar_today_outlined),
                      label: Text(dateFormat.format(_selectedEventDate)),
                      onPressed: () => _selectEventDate(context),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(Icons.access_time_outlined),
                      label: Text(_selectedEventTime.format(context)),
                      onPressed: () => _selectEventTime(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text("Couleur / Humeur:", style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 8),
              if (_currentJournalDetails!.palette.colors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Palette vide. Modifiez le journal pour ajouter des couleurs.", textAlign: TextAlign.center),
                )
              else
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _currentJournalDetails!.palette.colors.map((ColorData colorData) {
                    final bool isSelected = colorData.paletteElementId == _selectedPaletteElementId;
                    return ChoiceChip(
                      label: Text(colorData.title),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (mounted) {
                          setState(() {
                            if (selected) {
                              _selectedPaletteElementId = colorData.paletteElementId;
                            }
                          });
                        }
                      },
                      avatar: CircleAvatar(backgroundColor: colorData.color, radius: 12),
                      selectedColor: colorData.color.withAlpha(100),
                      pressElevation: 2.0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? colorData.color : Colors.grey.shade400,
                            width: isSelected ? 2.5 : 1,
                          )
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                            : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey.shade100,
                    );
                  }).toList(),
                ),
              SizedBox(height: 30),
              ElevatedButton.icon(
                icon: Icon(_isSaving ? Icons.hourglass_empty_outlined : Icons.save_outlined),
                label: Text(_isSaving ? "Sauvegarde..." : (widget.noteToEdit == null ? 'Sauvegarder la Note' : 'Mettre à jour la Note')),
                onPressed: _isSaving ? null : _saveNote,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
