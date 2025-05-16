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
import '../models/color_data.dart';

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
/// A global Uuid instance for generating unique IDs.
const _uuid = Uuid();

/// A StatefulWidget screen for creating or editing a [Note].
///
/// This page allows users to input the content of a note, associate it with a
/// color from the journal's palette, and set an event timestamp.
/// It can be used to create a new note or edit an existing one.
class EntryPage extends StatefulWidget {
  /// The ID of the journal to which this note belongs or will belong.
  final String journalId;
  /// The [Note] object to be edited. If null, a new note is being created.
  final Note? noteToEdit;
  /// An optional initial palette element ID to pre-select a color,
  /// typically used when creating a new note from a context where a color is already chosen.
  final String? initialPaletteElementId;

  /// Creates an instance of [EntryPage].
  ///
  /// [journalId] is required.
  /// [noteToEdit] is optional; if provided, the page operates in edit mode.
  /// [initialPaletteElementId] is optional; used for pre-selecting a color for new notes.
  const EntryPage({
    super.key,
    required this.journalId,
    this.noteToEdit,
    this.initialPaletteElementId,
  });

  @override
  _EntryPageState createState() => _EntryPageState();
}

/// The state for the [EntryPage].
///
/// Manages the form for note content, color selection, date/time picking,
/// loading journal details, and saving the note.
class _EntryPageState extends State<EntryPage> {
  /// Global key for the form to manage validation and state.
  final _formKey = GlobalKey<FormState>();
  /// Controller for the note content text field.
  late TextEditingController _contentController;
  /// The ID of the selected [ColorData] (palette element) for the note.
  String? _selectedPaletteElementId;
  /// The selected date for the note's event timestamp.
  DateTime _selectedEventDate = DateTime.now();
  /// The selected time for the note's event timestamp.
  TimeOfDay _selectedEventTime = TimeOfDay.now();

  /// Details of the current journal, including its palette.
  Journal? _currentJournalDetails;
  /// Flag to indicate if journal details are currently being loaded.
  bool _isLoadingJournalDetails = true;
  /// The ID of the current authenticated user.
  String? _userId;
  /// Flag to indicate if a save operation (update or create) is in progress.
  bool _isSaving = false;
  /// Flag to indicate if a "save as new" operation is in progress.
  bool _isSavingAsNew = false;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    _contentController = TextEditingController(text: widget.noteToEdit?.content);

    if (widget.noteToEdit != null) {
      // Editing an existing note
      _selectedPaletteElementId = widget.noteToEdit!.paletteElementId;
      _selectedEventDate = widget.noteToEdit!.eventTimestamp.toDate();
      _selectedEventTime = TimeOfDay.fromDateTime(_selectedEventDate);
    } else {
      // Creating a new note
      _selectedPaletteElementId = widget.initialPaletteElementId;
      // For a new note, _selectedEventDate and _selectedEventTime are already initialized to DateTime.now()
    }
    _loadJournalDetails();
  }

  /// Loads the details of the current journal, primarily its palette.
  ///
  /// This is necessary to populate the color selector. It also handles cases
  /// where the initially selected color for an existing note might no longer
  /// be valid in the current palette.
  Future<void> _loadJournalDetails() async {
    if (!mounted) return;
    setState(() { _isLoadingJournalDetails = true; });
    try {
      final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
      // Attempt to get journal details from ActiveJournalNotifier first for efficiency
      if (activeJournalNotifier.activeJournalId == widget.journalId && activeJournalNotifier.activeJournal != null) {
        _currentJournalDetails = activeJournalNotifier.activeJournal;
      } else {
        // Fallback to fetching directly from FirestoreService
        final firestoreService = Provider.of<FirestoreService>(context, listen: false);
        final journalDoc = await firestoreService.getJournalStream(widget.journalId).first;
        if (journalDoc.exists && journalDoc.data() != null) {
          _currentJournalDetails = Journal.fromMap(journalDoc.data() as Map<String, dynamic>, journalDoc.id);
        } else {
          throw Exception("Journal non trouvé ou inaccessible.");
        }
      }

      // Logic for default color selection or handling missing colors
      if (widget.noteToEdit == null && _selectedPaletteElementId == null && _currentJournalDetails != null && _currentJournalDetails!.palette.colors.isNotEmpty) {
        // For a new note with no initial color, pick the default or first color from the palette.
        final defaultColor = _currentJournalDetails!.palette.colors.firstWhere((c) => c.isDefault, orElse: () => _currentJournalDetails!.palette.colors.first);
        _selectedPaletteElementId = defaultColor.paletteElementId;
      }
      else if (widget.noteToEdit != null && _currentJournalDetails != null) {
        // For an existing note, check if its saved color still exists in the palette.
        bool currentPaletteElementExists = _currentJournalDetails!.palette.colors.any((c) => c.paletteElementId == _selectedPaletteElementId);
        if (!currentPaletteElementExists && _currentJournalDetails!.palette.colors.isNotEmpty) {
          // If the color is missing, select the first available color and notify the user.
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
          // If the palette is empty, no color can be selected.
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

  /// Shows a date picker dialog to allow the user to select the event date.
  Future<void> _selectEventDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEventDate,
      firstDate: DateTime(DateTime.now().year - 50), // Allow dates up to 50 years in the past
      lastDate: DateTime(DateTime.now().year + 50),  // Allow dates up to 50 years in the future
      locale: const Locale('fr', 'FR'), // Set locale for French date picker
    );
    if (picked != null && picked != _selectedEventDate) {
      if (mounted) {
        setState(() {
          _selectedEventDate = picked;
        });
      }
    }
  }

  /// Shows a time picker dialog to allow the user to select the event time.
  Future<void> _selectEventTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEventTime,
      builder: (BuildContext context, Widget? child) {
        // Force 24-hour format for the time picker.
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

  /// Sets the selected event date and time to the current moment.
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

  /// Saves the current note (either creates a new one or updates an existing one).
  ///
  /// Validates the form and selected color. If successful, interacts with
  /// [FirestoreService] to persist the note and then navigates back.
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
        // Creating a new note
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
        // Updating an existing note
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
      if (mounted) Navigator.of(context).pop(); // Go back after successful save
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

  /// Saves the current note content as a new note, regardless of whether
  /// the page was opened for editing an existing note.
  ///
  /// This is useful for duplicating a note or creating a new one based on an old one.
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
        id: _uuid.v4(), // Generate a new ID
        journalId: widget.journalId,
        userId: _userId!,
        content: _contentController.text.trim(),
        paletteElementId: _selectedPaletteElementId!,
        eventTimestamp: eventTimestamp,
        createdAt: Timestamp.now(), // New creation timestamp
        lastUpdatedAt: Timestamp.now(), // New update timestamp
      );
      await firestoreService.createNote(newNote);
      _loggerPage.i("Note sauvegardée comme nouvelle: ${newNote.id}");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Note sauvegardée comme nouvelle.")));
      if (mounted) Navigator.of(context).pop(); // Go back after successful save
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
    // Date formatter for displaying the selected event date.
    final DateFormat dateFormat = DateFormat('EEEE dd MMMM yyyy', 'fr_FR'); // Changed to yyyy for full year
    final bool isEditing = widget.noteToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la Note' : 'Nouvelle Note'),
        actions: [
          // Show a loading indicator in AppBar if saving
          if (_isSaving || _isSavingAsNew)
            const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
            )
          else
          // Save button
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
          ? Center( // Display error if journal details could not be loaded
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
          : SingleChildScrollView( // Main content form
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Color selector dropdown
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
                          Text(colorData.title), // Display color title or default
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
              // Message if palette has no colors
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Aucune couleur disponible dans la palette de ce journal. Veuillez d'abord ajouter des couleurs à la palette.",
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 20),

              // Note content text field
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
                  if (value == null || value.trim().isEmpty) { // Also check for empty after trim
                    return 'Veuillez entrer le contenu de la note.';
                  }
                  if (value.length > 1024) {
                    return 'Le contenu est trop long (max 1024 caractères).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Event date and time selection row
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateFormat.format(_selectedEventDate)),
                      onPressed: () => _selectEventDate(context),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).dividerColor)
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.access_time_outlined),
                      label: Text(_selectedEventTime.format(context)),
                      onPressed: () => _selectEventTime(context),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).dividerColor)
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // "Set to Now" button
                  Tooltip(
                    message: "Régler sur maintenant",
                    child: IconButton(
                      icon: const Icon(Icons.arrow_circle_left_outlined), // Icon can be changed e.g. Icons.update
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

              // Main save/update button
              ElevatedButton.icon(
                icon: Icon(_isSaving ? Icons.hourglass_empty_outlined : (isEditing ? Icons.sync_alt_outlined : Icons.save_outlined)),
                label: Text(_isSaving ? "Sauvegarde..." : (isEditing ? 'Mettre à jour la Note' : 'Sauvegarder la Note')),
                onPressed: (_isSaving || _isSavingAsNew || _selectedPaletteElementId == null) ? null : _saveNote,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 16)
                ),
              ),
              // "Save as New" button, only visible when editing an existing note
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
