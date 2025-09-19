// lib/screens/note_list_page.dart
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting.
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';
import 'entry_page.dart'; // Pour la navigation vers la page d'édition
import '../services/auth_service.dart'; // Used to get currentUserId for deleting all notes.
import '../widgets/notes_display_widget.dart'; // Import the new reusable widget

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: false));

/// A StatefulWidget that displays a list of notes for a given journal.
///
/// This page allows users to view notes in either a list or grid format,
/// sort them by different criteria (event timestamp, palette color order),
/// delete individual notes, or delete all notes in the journal.
class NoteListPage extends StatefulWidget {
  /// The ID of the journal whose notes are to be displayed.
  final String? journalId;

  /// Creates an instance of [NoteListPage].
  ///
  /// [journalId] is required to fetch and display the relevant notes.
  const NoteListPage({super.key, this.journalId});

  @override
  _NoteListPageState createState() => _NoteListPageState();
}

/// The state for the [NoteListPage].
///
/// Manages the display of notes, including sorting, view mode (list/grid),
/// and deletion functionalities.
class _NoteListPageState extends State<NoteListPage> {
  // We keep the sorting and view state here as NoteListPage is the "main" display for notes.
  String _sortBy = 'eventTimestamp';
  bool _sortDescending = true;
  bool _isGridView = false; // This state will now control NotesDisplayWidget
  bool _isDeletingAllNotes = false; // Specific to this page's functionality

  /// Shows a confirmation dialog and deletes a note if confirmed.
  /// This logic remains here as it's a specific action for NoteListPage.
  Future<void> _confirmDeleteNote(BuildContext context, FirestoreService firestoreService, String noteId) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.confirmDeleteDialogTitle),
          content: Text(l10n.confirmDeleteNoteDialogContent),
          actions: <Widget>[
            TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.deleteButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deleteNote(noteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noteDeletedSuccessSnackbar)));
        }
      } catch (e) {
        _loggerPage.e("Error deleting note: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorDeletingNoteSnackbar(e.toString()))));
        }
      }
    }
  }

  /// Shows a two-step confirmation dialog and deletes all notes in the journal if confirmed.
  /// This logic remains here as it's a specific action for NoteListPage.
  Future<void> _confirmDeleteAllNotes(BuildContext context, FirestoreService firestoreService, String journalId, String userId) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isDeletingAllNotes) return;

    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteAllNotesDialogTitle),
          content: Text(l10n.deleteAllNotesDialogContent),
          actions: <Widget>[
            TextButton(child: Text(l10n.cancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(l10n.deleteAllButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (firstConfirm != true) return;

    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.finalDeleteAllConfirmationDialogTitle),
          content: Text(l10n.finalDeleteAllConfirmationDialogContent),
          actions: <Widget>[
            TextButton(child: Text(l10n.noCancelButtonLabel), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(l10n.yesDeleteAllNotesButtonLabel),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (secondConfirm == true) {
      if (mounted) {
        setState(() {
          _isDeletingAllNotes = true;
        });
      }
      try {
        await firestoreService.deleteAllNotesInJournal(journalId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.allNotesDeletedSnackbar), backgroundColor: Colors.green));
        }
      } catch (e) {
        _loggerPage.e("Error deleting all notes: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorDeletingAllNotesSnackbar(e.toString())), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeletingAllNotes = false;
          });
        }
      }
    }
  }

  // Helper method to build a sort button that controls this page's state.
  Widget _buildNoteListPageSortButton(BuildContext context, String sortType, IconData mainIcon, String tooltip) {
    final l10n = AppLocalizations.of(context)!;
    bool isActive = _sortBy == sortType;
    const double directionIconSize = 16.0;
    String currentSortDirectionTooltip = isActive
        ? (_sortDescending ? l10n.sortDirectionDescending : l10n.sortDirectionAscending)
        : "";

    return IconButton(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mainIcon),
          if (isActive)
            Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Icon(_sortDescending ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: directionIconSize)
            ),
        ],
      ),
      tooltip: tooltip + currentSortDirectionTooltip,
      color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
      onPressed: () {
        if (mounted) {
          setState(() {
            if (isActive) {
              _sortDescending = !_sortDescending;
            } else {
              _sortBy = sortType;
              if (sortType == 'eventTimestamp' || sortType == 'createdAt') {
                _sortDescending = true;
              } else {
                _sortDescending = false; // e.g., for paletteOrder or content
              }
            }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = context.watch<ActiveJournalNotifier>();
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.uid;

    final String? journalIdToUse = widget.journalId ?? activeJournalNotifier.activeJournalId;

    if (journalIdToUse == null) {
      return Scaffold(
        body: Center(
          child: Text(l10n.noJournalSelected),
        ),
      );
    }
    
    final Journal? journalForPalette = activeJournalNotifier.activeJournalId == journalIdToUse ? activeJournalNotifier.activeJournal : null;
    
    if (currentUserId == null) {
      return Center(child: Text(l10n.userNotConnectedError));
    }

    return Scaffold(
      body: Column(
        children: [
          // Action bar with view toggle, sort buttons, and delete all notes button.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // "Delete All Notes" button, shown if user is logged in and notes exist.
                StreamBuilder<List<Note>>(
                  stream: firestoreService.getJournalNotesStream(journalIdToUse, sortBy: 'eventTimestamp', descending: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    final notes = snapshot.data ?? [];
                    if (currentUserId != null && notes.isNotEmpty) {
                      return Tooltip(
                        message: l10n.deleteAllNotesTooltip,
                        child: IconButton(
                          icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                          onPressed: _isDeletingAllNotes ? null : () => _confirmDeleteAllNotes(context, firestoreService, journalIdToUse, currentUserId),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Loading indicator if deleting all notes.
                if (_isDeletingAllNotes) const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))),

                // View toggle button (list/grid).
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                  tooltip: _isGridView ? l10n.viewAsListTooltip : l10n.viewAsGridTooltip,
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _isGridView = !_isGridView; // Toggle the state in NoteListPage
                      });
                    }
                  },
                ),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 0,
                    runSpacing: 0,
                    children: [
                      _buildNoteListPageSortButton(context, 'eventTimestamp', Icons.event_note_outlined, l10n.sortByEventDateTooltip),
                      _buildNoteListPageSortButton(context, 'paletteOrder', Icons.palette_outlined, l10n.sortByPaletteColorTooltip),
                      _buildNoteListPageSortButton(context, 'content', Icons.sort_by_alpha_outlined, l10n.sortByContentTooltip),
                  //    _buildNoteListPageSortButton(context, 'createdAt', Icons.add_circle_outline, l10n.sortByCreationDateTooltip),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded( // The actual notes display area using the new widget
            child: NotesDisplayWidget(
              journalId: journalIdToUse,
              userId: currentUserId,
              journalForPalette: journalForPalette,
              showSortingControls: false, // NoteListPage handles sorting UI externally
              showViewToggle: false,     // NoteListPage handles view toggle UI externally
              externalIsGridView: _isGridView, // Pass NoteListPage's _isGridView state
              externalSortBy: _sortBy,         // Pass NoteListPage's _sortBy state
              externalSortDescending: _sortDescending, // Pass NoteListPage's _sortDescending state
              enableNoteTaps: true, // Enable tapping to edit
              showDeleteButtons: true, // Enable delete buttons on notes
              onNoteTap: (note) {
                // Navigate to EntryPage to edit the tapped note
                Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: journalIdToUse, noteToEdit: note)));
              },
              onNoteDelete: (note) {
                // Call the local delete confirmation function when delete button is pressed
                _confirmDeleteNote(context, firestoreService, note.id);
              },
            ),
          ),
        ],
      ),
    );
  }
}
