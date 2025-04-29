// lib/screens/agenda_management_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agenda.dart';
import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_agenda_page.dart';
import 'palette_model_management_page.dart';

class AgendaManagementPage extends StatelessWidget {
  const AgendaManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final activeAgendaNotifier =
        context.watch<ActiveAgendaNotifier>(); // Watch pour l'ID actif
    final userId = context.read<User?>()?.uid; // Lire User depuis Provider

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gérer les Agendas')),
        body: const Center(child: Text("Utilisateur non connecté.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Agendas'),
        // Optionnel: Bouton pour créer un nouvel agenda (à implémenter plus tard)
        // actions: [ IconButton(icon: Icon(Icons.add), onPressed: () {/* SF-AGENDA-01 */})],
      ),
      body: Column(
        children: [
          // La liste des agendas prend l'espace restant
          Expanded(
            child: StreamBuilder<List<Agenda>>(
              stream: firestoreService.getUserAgendasStream(userId),
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
                  return const Center(child: Text('Aucun agenda trouvé.'));
                }

                // Si on a des données
                final agendas = snapshot.data!;

                return ListView.builder(
                  itemCount: agendas.length,
                  itemBuilder: (context, index) {
                    final agenda = agendas[index];
                    final bool isActive =
                        agenda.id == activeAgendaNotifier.activeAgendaId;

                    return Card(
                      color:
                          isActive
                              ? Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withOpacity(0.3)
                              : null,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: ListTile(
                        title: Text(agenda.name + (isActive ? ' (Actif)' : '')),
                        // Sélectionner l'agenda actif en tapant dessus
                        onTap: () {
                          // Lire le notifier SANS écouter pour appeler une méthode
                          context.read<ActiveAgendaNotifier>().setActiveAgenda(
                            agenda,
                          );
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
                              // Note: La fonction _showRenameAgendaDialog doit être définie
                              // dans la classe AgendaManagementPage (ou passée en paramètre)
                              onPressed:
                                  () =>
                                      _showRenameAgendaDialog(context, agenda),
                            ),
                            // Bouton Supprimer
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color:
                                    agendas.length > 1
                                        ? Colors.redAccent
                                        : Colors.grey,
                              ),
                              tooltip:
                                  agendas.length > 1
                                      ? 'Supprimer'
                                      : 'Impossible de supprimer le dernier agenda',
                              // Note: La fonction _showDeleteAgendaDialog doit être définie
                              // dans la classe AgendaManagementPage (ou passée en paramètre)
                              onPressed:
                                  agendas.length > 1
                                      ? () => _showDeleteAgendaDialog(
                                        context,
                                        agenda,
                                        firestoreService,
                                      )
                                      : null, // Désactiver si un seul agenda
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
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 16.0,
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Gérer mes Modèles de Palettes'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
              onPressed: () {
                // Naviguer vers l'écran de gestion des palettes modèles
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaletteModelManagementPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Nouvel Agenda"),
        tooltip: 'Créer un nouvel agenda', // Tooltip ajouté
        onPressed: () {
          Navigator.push(
            context,
            // Naviguer vers la page de création d'agenda
            MaterialPageRoute(builder: (_) => const CreateAgendaPage()),
          );
        },
      ),
    );
  }

  // --- Fonctions pour les Dialogues ---

  void _showRenameAgendaDialog(BuildContext context, Agenda agenda) {
    final TextEditingController nameController = TextEditingController(
      text: agenda.name,
    );
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Renommer l\'agenda'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nouveau nom'),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Enregistrer'),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != agenda.name) {
                  final fs = dialogContext.read<FirestoreService>();
                  try {
                    await fs.updateAgendaName(agenda.id, newName);
                    // Mettre à jour aussi le nom dans le notifier si c'est l'agenda actif
                    final activeNotifier =
                        dialogContext.read<ActiveAgendaNotifier>();
                    if (activeNotifier.activeAgendaId == agenda.id) {
                      // Créer un nouvel objet Agenda avec le nom mis à jour pour le notifier
                      final updatedAgenda = Agenda(
                        id: agenda.id,
                        name: newName,
                        userId: agenda.userId,
                        embeddedPaletteInstance: agenda.embeddedPaletteInstance,
                      );
                      activeNotifier.setActiveAgenda(updatedAgenda);
                    }
                    Navigator.of(dialogContext).pop();
                  } catch (e) {
                    print("Error renaming agenda: $e");
                    Navigator.of(dialogContext).pop();
                    // Afficher une erreur
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
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

  void _showDeleteAgendaDialog(
    BuildContext context,
    Agenda agenda,
    FirestoreService firestoreService,
  ) {
    final TextEditingController deleteController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voulez-vous vraiment supprimer l\'agenda "${agenda.name}" ?',
              ),
              const Text(
                'Toutes les notes associées seront perdues.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              // Champ pour confirmation renforcée (SF-AGENDA-06a)
              TextField(
                controller: deleteController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tapez "delete" pour confirmer',
                  hintText: 'delete',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
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
                              // Réinitialiser l'agenda actif si c'est celui qu'on supprime
                              final activeNotifier =
                                  dialogContext.read<ActiveAgendaNotifier>();
                              if (activeNotifier.activeAgendaId == agenda.id) {
                                activeNotifier.setActiveAgenda(
                                  null,
                                ); // Ou choisir un autre agenda ?
                              }

                              await firestoreService.deleteAgenda(
                                agenda.id,
                              ); // Doit supprimer les notes !
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Agenda supprimé.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              print("Error deleting agenda: $e");
                              Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
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
