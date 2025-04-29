// lib/screens/note_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Pour formater les dates

import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';
import '../models/note.dart';

class NoteListPage extends StatelessWidget {
  // Peut être StatelessWidget
  const NoteListPage({Key? key}) : super(key: key);

  // Dans la classe NoteListPage (ou son State si StatefulWidget)
  // Dans la classe NoteListPage (ou son State si StatefulWidget)

  void _showEditNoteDialog(BuildContext context, Note note) {
    // Pré-remplir le contrôleur avec le commentaire existant
    final TextEditingController commentController = TextEditingController(text: note.comment);
    final color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Container(width: 20, height: 20, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text('Modifier la note (${note.colorSnapshot.title})', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: TextField(
            controller: commentController,
            autofocus: true,
            maxLength: 256,
            decoration: const InputDecoration(hintText: 'Modifiez votre commentaire...', labelText: 'Commentaire'),
            maxLines: 3,
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
                // Vérifier si le commentaire a réellement changé (optionnel mais évite écritures inutiles)
                if (updatedComment.isNotEmpty && updatedComment != note.comment) {
                  final firestoreService = dialogContext.read<FirestoreService>();
                  try {
                    // Appeler la méthode de mise à jour du service
                    await firestoreService.updateNoteComment(note.id, updatedComment);
                    Navigator.of(dialogContext).pop();
                    // Le StreamBuilder mettra à jour l'UI avec le nouveau commentaire
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note modifiée.'), duration: Duration(seconds: 2)));
                    }
                  } catch (e) {
                    print("Error updating note: $e");
                    Navigator.of(dialogContext).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                    }
                  }
                } else {
                  // Si le commentaire est vide ou inchangé, on ferme juste
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette note définitivement ?'),
          // SF-NOTE-04a
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Fermer la popup
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () async {
                final firestoreService = dialogContext.read<FirestoreService>();
                try {
                  await firestoreService.deleteNote(note.id);
                  Navigator.of(dialogContext).pop(); // Fermer la popup
                  // Le StreamBuilder mettra automatiquement à jour la liste
                  if (context.mounted) {
                    // Utiliser le context initial pour le SnackBar
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
    // Récupérer l'agenda actif pour obtenir son ID et son nom
    final activeAgenda = context.watch<ActiveAgendaNotifier>().currentAgenda;
    final agendaId = activeAgenda?.id;
    final agendaName = activeAgenda?.name ?? "Notes"; // Titre par défaut

    return Scaffold(
      appBar: AppBar(
        title: Text('Notes - $agendaName'),
        // leading: IconButton( // Pour un bouton retour si nécessaire
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body:
          agendaId == null
              ? const Center(child: Text('Aucun agenda actif sélectionné.'))
              : StreamBuilder<List<Note>>(
                // Écouter le flux de notes pour l'agenda actif
                stream: context.read<FirestoreService>().getAgendaNotesStream(agendaId),
                builder: (context, snapshot) {
                  // Gérer les états du Stream
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    print("Error loading notes: ${snapshot.error}"); // Debug
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Aucune note dans cet agenda.'));
                  }

                  // Si on a des données, afficher la liste
                  final notes = snapshot.data!;

                  return ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final color = Color(int.parse(note.colorSnapshot.hexValue.replaceFirst('#', 'FF'), radix: 16));
                      // Formater la date (nécessite le package intl)
                      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt.toDate());

                      // Dans itemBuilder de ListView.builder dans note_list_page.dart

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: ListTile(
                          leading: Container(width: 24, height: 24, color: color),
                          title: Text(note.comment),
                          subtitle: Text('Note: ${note.colorSnapshot.title} - $formattedDate'),
                          // --- AJOUT DES ACTIONS ---
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            // Pour que la Row prenne peu de place
                            children: [
                              // Bouton Modifier
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Modifier',
                                onPressed: () {
                                  _showEditNoteDialog(context, note); // Appeler la popup de modification
                                },
                              ),
                              // Bouton Supprimer
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                tooltip: 'Supprimer',
                                onPressed: () {
                                  _showDeleteConfirmDialog(context, note); // Appeler la confirmation de suppression
                                },
                              ),
                            ],
                          ),
                          // Optionnel: rendre toute la tuile cliquable pour modifier
                          // onTap: () => _showEditNoteDialog(context, note),
                          // -----------------------
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
