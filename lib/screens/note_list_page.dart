import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';
import '../models/note.dart';
import '../widgets/dynamic_agenda_app_bar.dart';

enum SortOrder { descending, ascending }

class NoteListPage extends StatefulWidget {
  const NoteListPage({Key? key}) : super(key: key);

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  SortOrder _currentSortOrder = SortOrder.descending;
  bool _groupByColor = false;

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

  @override
  Widget build(BuildContext context) {
    final activeAgendaNotifier = context.watch<ActiveAgendaNotifier>();
    final String? agendaId = activeAgendaNotifier.activeAgendaId;
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: const DynamicAgendaAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(_groupByColor ? Icons.list : Icons.list_alt_outlined),
                  label: Text(_groupByColor ? 'Dégrouper' : 'Grouper par couleur'),
                  onPressed: () {
                    setState(() { _groupByColor = !_groupByColor; });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_currentSortOrder == SortOrder.descending ? Icons.arrow_downward: Icons.arrow_upward),
                  tooltip: _currentSortOrder == SortOrder.descending ? 'Trier du plus récent au plus ancien' : 'Trier du plus ancien au plus récent',
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
          Expanded(
            child: agendaId == null
                ? const Center(child: Text('Sélectionnez un agenda pour voir les notes.'))
                : StreamBuilder<List<Note>>(
              stream: firestoreService.getAgendaNotesStream(agendaId, descending: _currentSortOrder == SortOrder.descending),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur chargement des notes: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aucune note dans cet agenda.'));
                }

                final notes = snapshot.data!;

                if (_groupByColor) {
                  final groupedNotes = groupBy<Note, String>(notes, (note) => note.colorSnapshot.title);
                  final sortedGroupKeys = groupedNotes.keys.toList()..sort();

                  return ListView.builder(
                    itemCount: sortedGroupKeys.length,
                    itemBuilder: (context, groupIndex) {
                      final colorTitle = sortedGroupKeys[groupIndex];
                      final notesInGroup = groupedNotes[colorTitle]!;
                      Color groupColor = Colors.grey;
                      try {
                        groupColor = Color(int.parse(notesInGroup.first.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
                      } catch(e) { /* Ignore */ }

                      return ExpansionTile(
                        leading: Container(width: 24, height: 24, color: groupColor),
                        title: Text("$colorTitle (${notesInGroup.length} note${notesInGroup.length > 1 ? 's' : ''})"),
                        initiallyExpanded: true,
                        children: notesInGroup.map((note) {
                          final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(note.eventTimestamp.toDate());
                          return ListTile(
                            title: Text(note.comment),
                            subtitle: Text(formattedDate),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, size: 20), tooltip: 'Modifier la note', onPressed: () { _showEditNoteDialog(context, note); }),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent), tooltip: 'Supprimer la note', onPressed: () { _showDeleteConfirmDialog(context, note); }),
                              ],
                            ),
                            contentPadding: const EdgeInsets.only(left: 40.0, right: 16.0),
                          );
                        }).toList(),
                      );
                    },
                  );
                } else {
                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
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
