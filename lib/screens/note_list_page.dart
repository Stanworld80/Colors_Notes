import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/agenda.dart';
import '../widgets/dynamic_agenda_app_bar.dart';
import 'edit_palette_model_page.dart'; // Keep for edit palette action

class NoteListPage extends StatelessWidget {
  const NoteListPage({Key? key}) : super(key: key);

  void _showEditNoteDialog(BuildContext context, Note note) {
    final TextEditingController commentController = TextEditingController(text: note.comment);
    Color color;
    try {
      color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey;
      print("Erreur parsing couleur dialog edit note: ${note.colorSnapshot.hexValue} - ${e}");
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
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
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
                          print("Error updating note details: $e");
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
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
                  print("Error deleting note: $e");
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
      body: agendaId == null
          ? const Center(child: Text('Sélectionnez un agenda pour voir les notes.'))
          : StreamBuilder<List<Note>>(
        stream: firestoreService.getAgendaNotesStream(agendaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error loading notes: ${snapshot.error}");
            return Center(child: Text('Erreur chargement des notes: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune note dans cet agenda.'));
          }

          final notes = snapshot.data!;

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              Color color;
              try {
                color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
              } catch (e) {
                color = Colors.grey;
                print("Erreur parsing couleur note list: ${note.colorSnapshot.hexValue} - ${e}");
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
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Modifier la note',
                        onPressed: () {
                          _showEditNoteDialog(context, note);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Supprimer la note',
                        onPressed: () {
                          _showDeleteConfirmDialog(context, note);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
