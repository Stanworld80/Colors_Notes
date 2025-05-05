// lib/screens/note_list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Pour formater les dates
import 'package:firebase_auth/firebase_auth.dart'; // Pour User

// Import des providers et services
import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';

// AuthService n'est plus nécessaire ici directement pour l'AppBar
// import '../services/auth_service.dart';

// Import des modèles
import '../models/note.dart';
import '../models/agenda.dart'; // Besoin pour le corps de la page

// Import du widget AppBar réutilisable
import '../widgets/dynamic_agenda_app_bar.dart';

// EditPaletteModelPage n'est plus nécessaire ici directement pour l'AppBar
// import 'edit_palette_model_page.dart';

class NoteListPage extends StatelessWidget {
  const NoteListPage({Key? key}) : super(key: key);

  // --- Méthodes pour les Dialogues (Modification et Suppression de Note) ---
  // (Logique inchangée par rapport à la version précédente)

  /// Affiche une boîte de dialogue pour modifier le commentaire d'une note existante.
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
                if (updatedComment.isNotEmpty && updatedComment != note.comment) {
                  try {
                    await firestoreService.updateNoteComment(note.id, updatedComment);
                    Navigator.of(dialogContext).pop();
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
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Affiche une boîte de dialogue pour confirmer la suppression d'une note.
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

  // La méthode _signOut n'est plus nécessaire ici, elle est dans l'AppBar

  @override
  Widget build(BuildContext context) {
    // --- Récupérer les informations nécessaires pour le corps de la page ---
    final activeAgendaNotifier = context.watch<ActiveAgendaNotifier>();
    final String? agendaId = activeAgendaNotifier.activeAgendaId; // ID de l'agenda actif
    final firestoreService = context.read<FirestoreService>(); // Lire le service

    return Scaffold(
      // ================== Utilisation de l'AppBar Réutilisable ==================
      appBar: const DynamicAgendaAppBar(), // Simplement instancier le widget
      // ========================================================================

      // --- Corps de la page (logique inchangée) ---
      body:
          agendaId == null
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
                      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt.toDate());

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
                                tooltip: 'Modifier le commentaire',
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
