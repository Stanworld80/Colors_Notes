import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// collection package is no longer needed for groupBy visual grouping
// import 'package:collection/collection.dart';

import '../providers/active_journal_provider.dart'; // Should be active_journal_provider
import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart'; // Should be journal
import '../widgets/dynamic_journal_app_bar.dart'; // Should be dynamic_journal_app_bar
import 'edit_palette_model_page.dart';

// TODO: Rename SortOrder if needed
enum SortOrder { descending, ascending }

// TODO: Rename NoteListPage if desired
class NoteListPage extends StatefulWidget {
  const NoteListPage({Key? key}) : super(key: key);

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  SortOrder _currentSortOrder = SortOrder.descending;
  bool _groupByColor = false; // Now only controls sorting logic
  bool _isGridView = false; // State for view mode

  // _showEditNoteDialog remains unchanged
  void _showEditNoteDialog(BuildContext context, Note note) {
    final TextEditingController commentController = TextEditingController(text: note.comment);
    Color color;
    try {
      color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey;
    }
    final firestoreService = context.read<FirestoreService>();
    DateTime selectedDateTime = note.eventTimestamp.toDate();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (stfContext, stfSetState) {
              Future<void> _selectDate() async {
                final DateTime? pickedDate = await showDatePicker(
                  context: stfContext,
                  initialDate: selectedDateTime,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null) {
                  final newDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, selectedDateTime.hour, selectedDateTime.minute);
                  stfSetState(() { selectedDateTime = newDateTime; });
                }
              }
              Future<void> _selectTime() async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: stfContext,
                  initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                );
                if (pickedTime != null) {
                  final newDateTime = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day, pickedTime.hour, pickedTime.minute);
                  stfSetState(() { selectedDateTime = newDateTime; });
                }
              }
              return AlertDialog(
                title: Row(
                  children: [
                    Container(width: 20, height: 20, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Modifier la note (${note.colorSnapshot.title})', overflow: TextOverflow.ellipsis)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: commentController,
                        autofocus: true,
                        maxLength: 256,
                        decoration: const InputDecoration(hintText: 'Modifiez votre commentaire...', labelText: 'Commentaire'),
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 20),
                      Text("Date et Heure de l'événement:", style: Theme.of(stfContext).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.calendar_today, size: 20), tooltip: 'Choisir la date', onPressed: _selectDate, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              const SizedBox(width: 5),
                              IconButton(icon: const Icon(Icons.access_time, size: 20), tooltip: 'Choisir l\'heure', onPressed: _selectTime, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Supprimer'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showDeleteConfirmDialog(context, note);
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    child: const Text('Annuler'),
                    onPressed: () { Navigator.of(dialogContext).pop(); },
                  ),
                  ElevatedButton(
                    child: const Text('Enregistrer'),
                    onPressed: () async {
                      final updatedComment = commentController.text.trim();
                      final updatedTimestamp = Timestamp.fromDate(selectedDateTime);
                      bool commentChanged = updatedComment.isNotEmpty && updatedComment != note.comment;
                      bool timestampChanged = updatedTimestamp.seconds != note.eventTimestamp.seconds || updatedTimestamp.nanoseconds != note.eventTimestamp.nanoseconds;
                      if (commentChanged || timestampChanged) {
                        try {
                          await firestoreService.updateNoteDetails(
                            note.id,
                            newComment: commentChanged ? updatedComment : null,
                            newEventTimestamp: timestampChanged ? updatedTimestamp : null,
                          );
                          Navigator.of(dialogContext).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note modifiée.'), duration: Duration(seconds: 2)));
                          }
                        } catch (e) {
                          Navigator.of(dialogContext).pop();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                          }
                        }
                      } else {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  // _showDeleteConfirmDialog remains unchanged
  void _showDeleteConfirmDialog(BuildContext context, Note note) {
    final firestoreService = context.read<FirestoreService>();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette note définitivement ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () { Navigator.of(dialogContext).pop(); },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () async {
                try {
                  await firestoreService.deleteNote(note.id);
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note supprimée.'), duration: Duration(seconds: 2)));
                  }
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- Helper method to build a single grid item ---
  Widget _buildNoteGridItem(BuildContext context, Note note) {
    Color color;
    try {
      color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey;
    }
    final formattedDate = DateFormat('dd/MM HH:mm').format(note.eventTimestamp.toDate());
    final textColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white : Colors.black;

    return InkWell(
      onTap: () => _showEditNoteDialog(context, note),
      borderRadius: BorderRadius.circular(8.0),
      child: Card(
        color: color,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  note.comment,
                  style: TextStyle(color: textColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper method to build a single list item ---
  Widget _buildNoteListItem(BuildContext context, Note note) {
    Color color;
    try {
      color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey;
    }
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(note.eventTimestamp.toDate());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Container(width: 24, height: 24, color: color),
        title: Text(note.comment),
        subtitle: Text('Couleur: ${note.colorSnapshot.title} - $formattedDate'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 20), tooltip: 'Modifier la note', onPressed: () { _showEditNoteDialog(context, note); }),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), tooltip: 'Supprimer la note', onPressed: () { _showDeleteConfirmDialog(context, note); }),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // TODO: Rename ActiveJournalNotifier to ActiveJournalNotifier if refactored
    final activeJournalNotifier = context.watch<ActiveJournalNotifier>();
    // TODO: Rename journalId to journalId if refactored
    final String? journalId = activeJournalNotifier.activeJournalId;
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      // TODO: Rename DynamicJournalAppBar to DynamicJournalAppBar if refactored
      appBar: const DynamicJournalAppBar(),
      body: Column(
        children: [
          // --- Options Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Group Button (now only affects sorting)
                TextButton.icon(
                  // Use different icons to indicate sorting mode maybe?
                  icon: Icon(_groupByColor ? Icons.sort_by_alpha : Icons.color_lens_outlined),
                  label: Text(_groupByColor ? 'Trier par couleur' : 'Trier par date'),
                  onPressed: () {
                    setState(() {
                      _groupByColor = !_groupByColor;
                      // *** REMOVED: _isGridView = false; ***
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                // View Mode Button (List/Grid) - *** NOW ALWAYS ENABLED ***
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.view_module),
                  tooltip: _isGridView ? 'Affichage Liste' : 'Affichage Grille',
                  onPressed: () { // Always enabled
                    setState(() { _isGridView = !_isGridView; });
                  },
                  visualDensity: VisualDensity.compact,
                  // color: _groupByColor ? Colors.grey : null, // *** REMOVED color change ***
                ),
                const SizedBox(width: 8),
                // Sort Button (Asc/Desc for secondary sort)
                IconButton(
                  icon: Icon(_currentSortOrder == SortOrder.descending ? Icons.arrow_downward : Icons.arrow_upward),
                  tooltip: _currentSortOrder == SortOrder.descending ? 'Ordre décroissant' : 'Ordre croissant',
                  onPressed: () {
                    setState(() {
                      _currentSortOrder = _currentSortOrder == SortOrder.descending ? SortOrder.ascending : SortOrder.descending;
                    });
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // --- Notes Area ---
          Expanded(
            child: journalId == null
                ? const Center(child: Text('Sélectionnez un journal pour voir les notes.')) // Updated text
                : StreamBuilder<List<Note>>(
              // Stream still fetches sorted by date initially
              // TODO: Rename getJournalNotesStream to getJournalNotesStream if refactored
              stream: firestoreService.getJournalNotesStream(journalId, descending: _currentSortOrder == SortOrder.descending),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur chargement des notes: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aucune note dans ce journal.')); // Updated text
                }

                List<Note> notes = snapshot.data!;

                // --- Apply client-side sorting IF grouping by color is active ---
                if (_groupByColor) {
                  // Create a mutable copy before sorting
                  notes = List<Note>.from(notes);
                  notes.sort((a, b) {
                    // 1. Primary sort: Color Title (case-insensitive)
                    int colorCompare = a.colorSnapshot.title.toLowerCase().compareTo(b.colorSnapshot.title.toLowerCase());
                    if (colorCompare != 0) {
                      return colorCompare;
                    }
                    // 2. Secondary sort: Event Timestamp (respecting _currentSortOrder)
                    if (_currentSortOrder == SortOrder.descending) {
                      return b.eventTimestamp.compareTo(a.eventTimestamp); // Descending
                    } else {
                      return a.eventTimestamp.compareTo(b.eventTimestamp); // Ascending
                    }
                  });
                }
                // If not _groupByColor, 'notes' is already sorted by timestamp from the stream

                // --- Render based on _isGridView ---
                // *** REMOVED the ExpansionTile logic ***
                if (_isGridView) {
                  // Render GridView using the (potentially re-sorted) notes list
                  return GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130.0,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      return _buildNoteGridItem(context, notes[index]);
                    },
                  );
                } else {
                  // Render ListView using the (potentially re-sorted) notes list
                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      return _buildNoteListItem(context, notes[index]);
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
