// lib/screens/entry_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../providers/active_journal_provider.dart';
import '../models/color_data.dart';
import '../widgets/notes_display_widget.dart'; // Import the new reusable widget

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

class EntryPage extends StatefulWidget {
  final String journalId;
  final Note? noteToEdit;
  final String? initialPaletteElementId;

  const EntryPage({super.key, required this.journalId, this.noteToEdit, this.initialPaletteElementId});

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
    }
    _loadJournalDetails();
  }

  Future<void> _loadJournalDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoadingJournalDetails = true;
    });

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
          throw Exception("Journal details could not be loaded.");
        }
      }

      if (widget.noteToEdit == null && _selectedPaletteElementId == null && _currentJournalDetails != null && _currentJournalDetails!.palette.colors.isNotEmpty) {
        final defaultColor = _currentJournalDetails!.palette.colors.firstWhere((c) => c.isDefault, orElse: () => _currentJournalDetails!.palette.colors.first);
        _selectedPaletteElementId = defaultColor.paletteElementId;
      } else if (widget.noteToEdit != null && _currentJournalDetails != null) {
        bool currentPaletteElementExists = _currentJournalDetails!.palette.colors.any((c) => c.paletteElementId == _selectedPaletteElementId);
        if (!currentPaletteElementExists && _currentJournalDetails!.palette.colors.isNotEmpty) {
          _selectedPaletteElementId = _currentJournalDetails!.palette.colors.first.paletteElementId;
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final l10nCallback = AppLocalizations.of(context);
                if (l10nCallback != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10nCallback.entryPageOriginalColorMissingSnackbar), backgroundColor: Colors.orange),
                  );
                }
              }
            });
          }
        } else if (!currentPaletteElementExists && _currentJournalDetails!.palette.colors.isEmpty) {
          _selectedPaletteElementId = null;
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final l10nCallback = AppLocalizations.of(context);
                if (l10nCallback != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10nCallback.entryPagePaletteEmptySnackbar), backgroundColor: Colors.red),
                  );
                }
              }
            });
          }
        }
      }
    } catch (e) {
      _loggerPage.e("Erreur chargement détails journal: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final l10nCallback = AppLocalizations.of(context);
            final errorMessage = l10nCallback?.entryPageJournalDetailsLoadError ?? "Error loading journal details";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$errorMessage: ${e.toString()}")));
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingJournalDetails = false;
        });
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
      locale: Localizations.localeOf(context),
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
        return MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!);
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

  void _setDateTimeToNow() {
    final l10n = AppLocalizations.of(context)!;
    if (mounted) {
      final now = DateTime.now();
      setState(() {
        _selectedEventDate = now;
        _selectedEventTime = TimeOfDay.fromDateTime(now);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageDateTimeSetToNowSnackbar), duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _saveNote() async {
    final l10n = AppLocalizations.of(context)!;
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageUserNotIdentifiedError)));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPaletteElementId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageNoColorSelectedError)));
      return;
    }

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final eventTimestamp = Timestamp.fromDate(DateTime(_selectedEventDate.year, _selectedEventDate.month, _selectedEventDate.day, _selectedEventTime.hour, _selectedEventTime.minute));

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
        _loggerPage.i("Note created: ${newNote.id}"); // Log in English
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageNoteSavedSuccess)));
      } else {
        final updatedNote = widget.noteToEdit!.copyWith(
          content: _contentController.text.trim(),
          paletteElementId: _selectedPaletteElementId,
          eventTimestamp: eventTimestamp,
          lastUpdatedAt: Timestamp.now(),
        );
        await firestoreService.updateNote(updatedNote);
        _loggerPage.i("Note updated: ${updatedNote.id}"); // Log in English
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageNoteUpdatedSuccess)));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _loggerPage.e("Error saving note: $e"); // Log in English
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageGenericSaveError(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveAsNewNote() async {
    final l10n = AppLocalizations.of(context)!;
    if (_userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageUserNotIdentifiedError)));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedPaletteElementId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageNoColorSelectedError)));
      return;
    }

    if (mounted) {
      setState(() {
        _isSavingAsNew = true;
      });
    }

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final eventTimestamp = Timestamp.fromDate(DateTime(_selectedEventDate.year, _selectedEventDate.month, _selectedEventDate.day, _selectedEventTime.hour, _selectedEventTime.minute));

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
      _loggerPage.i("Note saved as new: ${newNote.id}"); // Log in English
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageNoteSavedAsNewSuccess)));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _loggerPage.e("Error saving as new note: $e"); // Log in English
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.entryPageGenericSaveError(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAsNew = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final DateFormat dateFormat = DateFormat('EEEE dd MMMM y HH:mm', l10n.localeName);
    final bool isEditing = widget.noteToEdit != null;

    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final Journal? journalForPalette = activeJournalNotifier.activeJournalId == widget.journalId ? activeJournalNotifier.activeJournal : null;

    if (_userId == null) {
      return Center(child: Text(l10n.userNotConnectedError));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.entryPageEditTitle : l10n.entryPageNewTitle),
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
            Text(l10n.entryPageJournalDetailsLoadError),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadJournalDetails, child: Text(l10n.entryPageJournalDetailsRetryButton)),
          ],
        ),
      )
          : Column(
        // Main Column to hold both form and notes display
        children: [
          Expanded(
            // Make the form scrollable and take available space
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_currentJournalDetails!.palette.colors.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedPaletteElementId,
                        decoration: InputDecoration(labelText: l10n.entryPageAssociatedColorLabel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
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
                        validator: (value) => value == null ? l10n.entryPageSelectColorValidator : null,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          l10n.entryPagePaletteEmptySnackbar,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: l10n.entryPageContentLabel,
                        hintText: l10n.entryPageContentHint,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value != null && value.length > 1024) {
                          return l10n.entryPageContentValidatorTooLong;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
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
                              side: BorderSide(color: Theme.of(context).dividerColor),
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
                              side: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: l10n.entryPageDateTimeSetToNowSnackbar,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_circle_left_outlined),
                            onPressed: _setDateTimeToNow,
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                              side: BorderSide(color: Theme.of(context).dividerColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: Icon(_isSaving ? Icons.hourglass_empty_outlined : (isEditing ? Icons.sync_alt_outlined : Icons.save_outlined)),
                      label: Text(_isSaving ? l10n.entryPageSavingButton : (isEditing ? l10n.entryPageSaveButtonUpdate : l10n.entryPageSaveButtonCreate)),
                      onPressed: (_isSaving || _isSavingAsNew || _selectedPaletteElementId == null) ? null : _saveNote,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), textStyle: const TextStyle(fontSize: 16)),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 15),
                      OutlinedButton.icon(
                        icon: Icon(_isSavingAsNew ? Icons.hourglass_empty_outlined : Icons.add_circle_outline),
                        label: Text(_isSavingAsNew ? l10n.entryPageSavingButton : l10n.entryPageSaveAsNewButton),
                        onPressed: (_isSaving || _isSavingAsNew || _selectedPaletteElementId == null) ? null : _saveAsNewNote,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 16),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30), // Space between the form and the notes list
          Divider(height: 20, thickness: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              l10n.existingNotesTitle, // "Notes existantes" (Add to ARB files)
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            // The NotesDisplayWidget should be within an Expanded to take remaining space
            child: NotesDisplayWidget(
              journalId: widget.journalId,
              userId: _userId!,
              // Ensure userId is not null here, or handle it with a loader/error
              journalForPalette: journalForPalette,
              // Pass the journal for palette resolution
              showSortingControls: true,
              // Only chronological/anti-chronological
              showViewToggle: true,
              // Allow grid/list view
              enableNoteTaps: true, // Notes are now tappable
              showDeleteButtons: false, // No delete buttons here
              filterByPaletteElementId: _selectedPaletteElementId, // Pass the selected color for filtering
              onNoteTap: (note) {
                // Navigate to a new EntryPage to edit the tapped note
                Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: widget.journalId, noteToEdit: note)));
              },
            ),
          ),
        ],
      ),
    );
  }
}
