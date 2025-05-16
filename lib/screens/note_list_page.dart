import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting.
import 'package:logger/logger.dart';

import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';
import 'entry_page.dart';
import '../services/auth_service.dart'; // Used to get currentUserId for deleting all notes.

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: false));

/// A StatefulWidget that displays a list of notes for a given journal.
///
/// This page allows users to view notes in either a list or grid format,
/// sort them by different criteria (event timestamp, palette color order),
/// delete individual notes, or delete all notes in the journal.
class NoteListPage extends StatefulWidget {
  /// The ID of the journal whose notes are to be displayed.
  final String journalId;

  /// Creates an instance of [NoteListPage].
  ///
  /// [journalId] is required to fetch and display the relevant notes.
  const NoteListPage({super.key, required this.journalId});

  @override
  _NoteListPageState createState() => _NoteListPageState();
}

/// The state for the [NoteListPage].
///
/// Manages the display of notes, including sorting, view mode (list/grid),
/// and deletion functionalities.
class _NoteListPageState extends State<NoteListPage> {
  /// The field by which notes are currently sorted.
  /// Defaults to 'eventTimestamp'. Other options can be 'paletteOrder', 'content', 'createdAt'.
  String _sortBy = 'eventTimestamp';
  /// Whether the current sort order is descending.
  /// Defaults to `true` for time-based sorts.
  bool _sortDescending = true;
  /// `true` if notes are displayed in a grid view, `false` for list view.
  bool _isGridView = false;
  /// Flag to indicate if the "delete all notes" operation is in progress.
  /// Used to disable the delete all button and show a loading indicator.
  bool _isDeletingAllNotes = false;

  /// Retrieves [ColorData] for a given [paletteElementId] from the provided [journal]'s palette.
  ///
  /// Returns the [ColorData] if found, otherwise `null`.
  /// [journal] The journal containing the palette.
  /// [paletteElementId] The ID of the color element to find.
  ColorData? _getColorDataById(Journal? journal, String paletteElementId) {
    if (journal == null) return null;
    try {
      return journal.palette.colors.firstWhere((c) => c.paletteElementId == paletteElementId);
    } catch (e) {
      // Log if a color is not found, which might happen if a palette was modified
      // and a note refers to a deleted color.
      _loggerPage.w("ColorData non trouvé pour paletteElementId: $paletteElementId dans le journal ${journal.name}");
      return null; // Return null if not found
    }
  }

  /// Builds a sort button widget.
  ///
  /// The button displays an icon and, if active, a sort direction arrow.
  /// Tapping the button changes the sort criteria or toggles the sort direction.
  ///
  /// [sortType] The string identifier for this sort type (e.g., 'eventTimestamp').
  /// [mainIcon] The main icon for the sort button.
  /// [tooltip] The tooltip text for the button.
  Widget _buildSortButton(String sortType, IconData mainIcon, String tooltip) {
    bool isActive = _sortBy == sortType;
    const double directionIconSize = 16.0; // Size for the up/down arrow icon.

    return IconButton(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mainIcon),
          if (isActive) // Show sort direction arrow only if this sort type is active.
            Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Icon(_sortDescending ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: directionIconSize)
            ),
        ],
      ),
      tooltip: tooltip + (isActive ? (_sortDescending ? " (Décroissant)" : " (Croissant)") : ""), // UI Text in French for tooltip
      color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
      onPressed: () {
        if (mounted) {
          setState(() {
            if (isActive) {
              // If already active, just toggle the sort direction.
              _sortDescending = !_sortDescending;
            } else {
              // If activating a new sort type, set it and default direction.
              _sortBy = sortType;
              // Default sort direction: descending for time-based, ascending for others.
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

  /// Shows a confirmation dialog and deletes a note if confirmed.
  ///
  /// [context] The build context for showing the dialog.
  /// [firestoreService] The service to handle Firestore operations.
  /// [noteId] The ID of the note to be deleted.
  Future<void> _confirmDeleteNote(BuildContext context, FirestoreService firestoreService, String noteId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'), // UI Text in French
          content: const Text('Voulez-vous vraiment supprimer cette note ?'), // UI Text in French
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)), // UI Text in French
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer'), onPressed: () => Navigator.of(dialogContext).pop(true)), // UI Text in French
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await firestoreService.deleteNote(noteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note supprimée avec succès.'))); // UI Text in French
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression note: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression: ${e.toString()}'))); // UI Text in French
        }
      }
    }
  }

  /// Shows a two-step confirmation dialog and deletes all notes in the journal if confirmed.
  ///
  /// [context] The build context for showing dialogs.
  /// [firestoreService] The service for Firestore operations.
  /// [journalId] The ID of the journal whose notes are to be deleted.
  /// [userId] The ID of the current user, for permission validation by Firestore rules (implicitly).
  Future<void> _confirmDeleteAllNotes(BuildContext context, FirestoreService firestoreService, String journalId, String userId) async {
    if (_isDeletingAllNotes) return; // Prevent multiple simultaneous delete operations.

    // First confirmation dialog.
    final bool? firstConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer toutes les notes ?'), // UI Text in French
          content: const Text('Cette action supprimera DÉFINITIVEMENT toutes les notes de ce journal. Voulez-vous continuer ?'), // UI Text in French
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)), // UI Text in French
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Supprimer Tout'), onPressed: () => Navigator.of(dialogContext).pop(true)), // UI Text in French
          ],
        );
      },
    );

    if (firstConfirm != true) return;

    // Second, more explicit confirmation dialog.
    final bool? secondConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('CONFIRMATION FINALE'), // UI Text in French
          content: const Text('Êtes-vous absolument certain(e) ? Cette action est IRRÉVERSIBLE.'), // UI Text in French
          actions: <Widget>[
            TextButton(child: const Text('NON, ANNULER'), onPressed: () => Navigator.of(dialogContext).pop(false)), // UI Text in French
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('OUI, SUPPRIMER TOUTES LES NOTES'), // UI Text in French
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (secondConfirm == true) {
      if (mounted) {
        setState(() {
          _isDeletingAllNotes = true; // Set loading state.
        });
      }
      try {
        await firestoreService.deleteAllNotesInJournal(journalId, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toutes les notes ont été supprimées.'), backgroundColor: Colors.green)); // UI Text in French
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression de toutes les notes: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression de toutes les notes: ${e.toString()}'), backgroundColor: Colors.red)); // UI Text in French
        }
      } finally {
        if (mounted) {
          setState(() {
            _isDeletingAllNotes = false; // Reset loading state.
          });
        }
      }
    }
  }

  /// Builds a single grid item widget for displaying a note.
  ///
  /// [context] The build context.
  /// [note] The [Note] object to display.
  /// [colorData] The [ColorData] associated with the note, used for styling.
  /// [firestoreService] Service for Firestore operations (e.g., deleting the note).
  /// [journal] The current [Journal], used to get color data (though colorData is passed directly).
  Widget _buildNoteGridItem(BuildContext context, Note note, ColorData? colorData, FirestoreService firestoreService, Journal? journal) {
    final DateFormat dateFormat = DateFormat('dd/MM/yy HH:mm', 'fr_FR'); // Date format in French
    final Color cardColor = colorData?.color ?? Colors.grey.shade100; // Default color if colorData is null
    // Determine text color based on card color's luminance for readability.
    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

    // Responsive font sizes and content lines for grid items.
    double titleFontSize = 10.0;
    double contentFontSize = 11.0;
    double dateFontSize = 9.0;
    int maxLinesForContent = 2;

    final screenWidth = MediaQuery.of(context).size.width;
    // Heuristic to adjust font sizes for smaller grid cells.
    // Assumes gridCrossAxisCount increases with screenWidth, so cell width is roughly screenWidth / gridCrossAxisCount.
    // This is a simplified check; a more robust way would be to pass gridCrossAxisCount or cell width.
    if (screenWidth / 9 < 80) { // Example: if 9 columns, cell width is < 80
      titleFontSize = 8.0;
      contentFontSize = 9.0;
      dateFontSize = 7.0;
      maxLinesForContent = 1;
    }

    return Card(
      elevation: 2.0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {
          // Navigate to EntryPage to edit the tapped note.
          Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: widget.journalId, noteToEdit: note)));
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      colorData?.title ?? "Couleur", // UI Text in French (default color title)
                      style: TextStyle(fontSize: titleFontSize, color: subtleTextColor, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Delete button for the note.
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: textColor.withOpacity(0.7), size: 16),
                    padding: EdgeInsets.zero, // Compact padding
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24), // Smaller touch target
                    tooltip: "Supprimer la note", // UI Text in French
                    onPressed: () => _confirmDeleteNote(context, firestoreService, note.id),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded( // Note content.
                child: Text(
                  note.content,
                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: contentFontSize, color: textColor),
                  maxLines: maxLinesForContent,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Event timestamp of the note.
              Text(dateFormat.format(note.eventTimestamp.toDate().toLocal()), style: TextStyle(fontSize: dateFontSize, color: subtleTextColor)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    // Listen to ActiveJournalNotifier to get the current journal's palette for color mapping.
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    // Get the journal details if the currently active journal matches this page's journalId.
    final Journal? journalForPalette = activeJournalNotifier.activeJournalId == widget.journalId ? activeJournalNotifier.activeJournal : null;
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.uid;

    // Determine Firestore query parameters based on current sort state.
    // Some sorting (paletteOrder, content) is done client-side after fetching.
    String firestoreSortField = _sortBy;
    bool firestoreSortDescending = _sortDescending;

    // If sorting by palette order or content, fetch by a default (e.g., eventTimestamp)
    // and then sort locally, as Firestore doesn't directly support these complex sorts.
    if (_sortBy == 'paletteOrder' || _sortBy == 'content') {
      firestoreSortField = 'eventTimestamp'; // Default server-side sort
      firestoreSortDescending = true;        // Most recent first is a common default
    }

    return Scaffold(
      body: StreamBuilder<List<Note>>(
        // Stream notes from Firestore, sorted by the chosen server-side field.
        stream: firestoreService.getJournalNotesStream(widget.journalId, sortBy: firestoreSortField, descending: firestoreSortDescending),
        builder: (context, snapshot) {
          // Show loading indicator if the active journal (for palette info) is still loading.
          if (activeJournalNotifier.isLoading && journalForPalette == null && activeJournalNotifier.activeJournalId == widget.journalId) {
            return const Center(child: CircularProgressIndicator());
          }
          // Show loading indicator if notes stream is waiting and has no data yet.
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Erreur chargement notes: ${snapshot.error}");
            return Center(child: Text('Erreur de chargement des notes. ${snapshot.error}')); // UI Text in French
          }

          List<Note> notes = snapshot.data ?? [];

          // Display message if no notes are found and not in the process of deleting all.
          if (notes.isEmpty && !_isDeletingAllNotes) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notes_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 16),
                  Text('Aucune note dans ce journal.', style: Theme.of(context).textTheme.headlineSmall), // UI Text in French
                ],
              ),
            );
          }

          // Client-side sorting for 'paletteOrder' or 'content'.
          if (_sortBy == 'paletteOrder' && journalForPalette != null) {
            // Create a map for palette color order.
            final paletteOrderMap = {
              for (var i = 0; i < journalForPalette.palette.colors.length; i++)
                journalForPalette.palette.colors[i].paletteElementId: i
            };
            notes.sort((a, b) {
              final indexA = paletteOrderMap[a.paletteElementId] ?? double.maxFinite.toInt(); // Unmapped colors last
              final indexB = paletteOrderMap[b.paletteElementId] ?? double.maxFinite.toInt();
              int comparison = indexA.compareTo(indexB);
              return _sortDescending ? -comparison : comparison; // Apply sort direction
            });
          } else if (_sortBy == 'content') {
            notes.sort((a, b) {
              int comparison = a.content.toLowerCase().compareTo(b.content.toLowerCase());
              return _sortDescending ? -comparison : comparison; // Apply sort direction
            });
          }

          // Log a warning if journal details (for palette) are not available, which might affect color mapping.
          if (journalForPalette == null && activeJournalNotifier.activeJournalId != widget.journalId && !activeJournalNotifier.isLoading) {
            _loggerPage.w("Détails du journal (pour la palette) non disponibles pour ${widget.journalId}. Le tri par couleur peut ne pas fonctionner correctement.");
          }

          // Determine grid column count based on screen width for responsiveness.
          final screenWidth = MediaQuery.of(context).size.width;
          int gridCrossAxisCount;
          if (screenWidth < 400) {
            gridCrossAxisCount = 3;
          } else if (screenWidth < 600) {
            gridCrossAxisCount = 4;
          } else if (screenWidth < 800) {
            gridCrossAxisCount = 5;
          } else if (screenWidth < 1000) {
            gridCrossAxisCount = 6;
          } else if (screenWidth < 1200) {
            gridCrossAxisCount = 7;
          } else if (screenWidth < 1400) {
            gridCrossAxisCount = 8;
          } else {
            gridCrossAxisCount = 9;
          }

          return Column(
            children: [
              // Action bar with view toggle, sort buttons, and delete all notes button.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Align controls to the right
                  children: [
                    // "Delete All Notes" button, shown if user is logged in and notes exist.
                    if (currentUserId != null && notes.isNotEmpty)
                      Tooltip(
                        message: "Supprimer toutes les notes de ce journal", // UI Text in French
                        child: IconButton(
                          icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                          onPressed: _isDeletingAllNotes ? null : () => _confirmDeleteAllNotes(context, firestoreService, widget.journalId, currentUserId),
                        ),
                      ),
                    // Loading indicator if deleting all notes.
                    if (_isDeletingAllNotes) const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0))),
                    // View toggle button (list/grid).
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                      tooltip: _isGridView ? "Afficher en liste" : "Afficher en grille", // UI Text in French
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isGridView = !_isGridView;
                          });
                        }
                      },
                    ),
                    Expanded( // Use Expanded to push sort buttons to the end if space allows.
                      child: Wrap( // Wrap sort buttons to prevent overflow on smaller screens.
                        alignment: WrapAlignment.end,
                        spacing: 0, // No horizontal spacing between buttons in the wrap
                        runSpacing: 0, // No vertical spacing if they wrap to a new line
                        children: [
                          _buildSortButton('eventTimestamp', Icons.event_note_outlined, "Trier par date d'événement"), // UI Text in French
                          _buildSortButton('paletteOrder', Icons.palette_outlined, "Trier par couleur de palette"), // UI Text in French
                          // Add more sort buttons here if needed, e.g., for 'createdAt' or 'content'
                          // _buildSortButton('content', Icons.sort_by_alpha_outlined, "Trier par contenu"),
                          // _buildSortButton('createdAt', Icons.history_toggle_off_outlined, "Trier par date de création"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Display notes in either a GridView or ListView.
              Expanded(
                child: _isGridView
                    ? GridView.builder( // Grid view implementation
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      crossAxisSpacing: 4.0,
                      mainAxisSpacing: 4.0,
                      childAspectRatio: 1.1 // Adjust for desired item shape
                  ),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                    return _buildNoteGridItem(context, note, colorData, firestoreService, journalForPalette);
                  },
                )
                    : ListView.builder( // List view implementation
                  padding: const EdgeInsets.all(8.0),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final colorData = _getColorDataById(journalForPalette, note.paletteElementId);
                    // Date formatter for list view items.
                    final DateFormat dateFormat = DateFormat('EEEE dd MMMM HH:mm', 'fr_FR'); // Using a more complete date format. Note: yyyy was GGGGGy before

                    final Color cardColor = colorData?.color ?? Theme.of(context).cardColor; // Default if colorData is null
                    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

                    return Card(
                      elevation: 2.0,
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0), // Adjusted margin for list items
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12.0),
                        leading: colorData != null
                        // Display a transparent CircleAvatar for alignment if colorData exists,
                        // otherwise a placeholder if color is unknown.
                        // The actual color indication is from the card's background.
                            ? CircleAvatar(backgroundColor: Colors.transparent) // Could also be a colored dot: CircleAvatar(backgroundColor: colorData.color, radius: 10)
                            : const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.help_outline, color: Colors.white)),
                        title: Text(
                            note.content,
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: textColor),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (colorData != null)
                                Text(
                                    colorData.title,
                                    style: TextStyle(fontSize: 12, color: subtleTextColor, fontWeight: FontWeight.bold)
                                ),
                              Text(
                                  'Date: ${dateFormat.format(note.eventTimestamp.toDate().toLocal())}', // UI Text in French
                                  style: TextStyle(fontSize: 12, color: subtleTextColor)
                              ),
                              // Optionally display creation/update timestamps for more detail
                              Text(
                                'Créé le: ${DateFormat('dd/MM/yy HH:mm', 'fr_FR').format(note.createdAt.toDate().toLocal())}', // UI Text in French
                                style: TextStyle(fontSize: 10, color: subtleTextColor.withOpacity(0.8)),
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton( // Delete button for list items
                          icon: Icon(Icons.delete_forever_outlined, color: textColor.withOpacity(0.7)),
                          tooltip: "Supprimer cette note", // UI Text in French
                          onPressed: () => _confirmDeleteNote(context, firestoreService, note.id),
                        ),
                        onTap: () {
                          // Navigate to EntryPage to edit the tapped note.
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: widget.journalId, noteToEdit: note)));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
