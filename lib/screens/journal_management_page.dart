// lib/screens/journal_management_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journal.dart';
import '../providers/active_journal_provider.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_journal_page.dart';
import 'palette_model_management_page.dart';

class JournalManagementPage extends StatelessWidget {
  const JournalManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final activeJournalNotifier = context.watch<ActiveJournalNotifier>(); // Watch pour l'ID actif
    final userId = context.read<User?>()?.uid; // Lire User depuis Provider

    if (userId == null) {
      return Scaffold(appBar: AppBar(title: const Text('Gérer les journaux')), body: const Center(child: Text("Utilisateur non connecté.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les journaux'),
        // Optionnel: Bouton pour créer un nouveau journal (à implémenter plus tard)
        // actions: [ IconButton(icon: Icon(Icons.add), onPressed: () {/* SF-AGENDA-01 */})],
      ),
      body: Column(
        children: [
          // La liste des journals prend l'espace restant
          Expanded(
            child: StreamBuilder<List<Journal>>(
              stream: firestoreService.getUserJournalsStream(userId),
              builder: (context, snapshot) {
                // Gérer les états du Stream
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Peut arriver brièvement ou si la création par défaut a échoué
                  return const Center(child: Text('Aucun journal trouvé.'));
                }

                // Si on a des données
                final journals = snapshot.data!;

                return ListView.builder(
                  itemCount: journals.length,
                  itemBuilder: (context, index) {
                    final journal = journals[index];
                    final bool isActive = journal.id == activeJournalNotifier.activeJournalId;

                    return Card(
                      color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: Icon((isActive ? Icons.arrow_forward_outlined : null), size: 20),
                        title: Text(journal.name + (isActive ? ' (ACTIF)' : '')),
                        // Sélectionner l'journal actif en tapant dessus
                        onTap: () {
                          // Lire le notifier SANS écouter pour appeler une méthode
                          context.read<ActiveJournalNotifier>().setActiveJournal(journal);
                          // Optionnel : revenir à l'accueil
                          // Provider.of<NavigationState>(context, listen: false).selectedIndex = 0;
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          // Important pour la taille de la Row
                          children: [
                            // Bouton Renommer
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Renommer',
                              // Note: La fonction _showRenameJournalDialog doit être définie
                              // dans la classe JournalManagementPage (ou passée en paramètre)
                              onPressed: () => _showRenameJournalDialog(context, journal),
                            ),
                            // Bouton Supprimer
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: journals.length > 1 ? Colors.redAccent : Colors.grey),
                              tooltip: journals.length > 1 ? 'Supprimer' : 'Impossible de supprimer le dernier journal',
                              // Note: La fonction _showDeleteJournalDialog doit être définie
                              // dans la classe JournalManagementPage (ou passée en paramètre)
                              onPressed: journals.length > 1 ? () => _showDeleteJournalDialog(context, journal, firestoreService) : null, // Désactiver si un seul journal
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ), // Fin de Expanded
          // --- Bouton "Gérer mes Modèles de Palettes" ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 90.0), // Augmentation du padding inférieur
            child: ElevatedButton.icon(
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Gérer mes Modèles de Palettes'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              onPressed: () {
                // Naviguer vers l'écran de gestion des palettes modèles
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaletteModelManagementPage()));
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Nouveau Journal"),
        tooltip: 'Créer un nouveau journal', // Tooltip ajouté
        onPressed: () {
          Navigator.push(
            context,
            // Naviguer vers la page de création d'journal
            MaterialPageRoute(builder: (_) => const CreateJournalPage()),
          );
        },
      ),
    );
  }

  // --- Fonctions pour les Dialogues ---

  void _showRenameJournalDialog(BuildContext context, Journal journal) {
    final TextEditingController nameController = TextEditingController(text: journal.name);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Renommer l\'journal'),
          content: TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Nouveau nom')),
          actions: [
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              child: const Text('Enregistrer'),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != journal.name) {
                  final fs = dialogContext.read<FirestoreService>();
                  try {
                    await fs.updateJournalName(journal.id, newName);
                    // Mettre à jour aussi le nom dans le notifier si c'est l'journal actif
                    final activeNotifier = dialogContext.read<ActiveJournalNotifier>();
                    if (activeNotifier.activeJournalId == journal.id) {
                      // Créer un nouvel objet Journal avec le nom mis à jour pour le notifier
                      final updatedJournal = Journal(id: journal.id, name: newName, userId: journal.userId, embeddedPaletteInstance: journal.embeddedPaletteInstance);
                      activeNotifier.setActiveJournal(updatedJournal);
                    }
                    Navigator.of(dialogContext).pop();
                  } catch (e) {
                    print("Error renaming journal: $e");
                    Navigator.of(dialogContext).pop();
                    // Afficher une erreur
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

  void _showDeleteJournalDialog(BuildContext context, Journal journal, FirestoreService firestoreService) {
    final TextEditingController deleteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Voulez-vous vraiment supprimer l\'journal "${journal.name}" ?'),
              const Text('Toutes les notes associées seront perdues.', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              // Champ pour confirmation renforcée (SF-AGENDA-06a)
              TextField(controller: deleteController, autofocus: true, decoration: const InputDecoration(labelText: 'Tapez "delete" pour confirmer', hintText: 'delete')),
            ],
          ),
          actions: [
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            ValueListenableBuilder<TextEditingValue>(
              // Pour activer/désactiver le bouton
              valueListenable: deleteController,
              builder: (context, value, child) {
                return TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed:
                      value.text.trim().toLowerCase() == 'delete'
                          ? () async {
                            try {
                              // Réinitialiser l'journal actif si c'est celui qu'on supprime
                              final activeNotifier = dialogContext.read<ActiveJournalNotifier>();
                              if (activeNotifier.activeJournalId == journal.id) {
                                activeNotifier.setActiveJournal(null); // Ou choisir un autre journal ?
                              }

                              await firestoreService.deleteJournal(journal.id); // Doit supprimer les notes !
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journal supprimé.'), duration: Duration(seconds: 2)));
                              }
                            } catch (e) {
                              print("Error deleting journal: $e");
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                              }
                            }
                          }
                          : null, // Désactiver si 'delete' n'est pas tapé
                  child: const Text('Supprimer'),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
