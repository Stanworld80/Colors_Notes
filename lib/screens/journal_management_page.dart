// lib/screens/journal_management_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../models/journal.dart';
import 'create_journal_page.dart';
import 'unified_palette_editor_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

class JournalManagementPage extends StatelessWidget {
  JournalManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      _loggerPage.w("JournalManagementPage: currentUserId est null.");
      return Scaffold(
          appBar: AppBar(title: const Text('Gérer les Journaux')),
          body: const Center(child: Text("Utilisateur non connecté.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Journaux'),
      ),
      body: StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Erreur chargement journaux: ${snapshot.error}");
            return Center(child: Text('Erreur de chargement des journaux: ${snapshot.error.toString()}'));
          }

          final journals = snapshot.data ?? [];
          final DateFormat dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR'); // yyyy pour l'année complète

          // La carte de création est toujours présente en haut
          Widget createJournalCard = Card(
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Marge ajustée
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateJournalPage()),
                );
              },
              borderRadius: BorderRadius.circular(10.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0), // Padding ajusté
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 32, color: Theme.of(context).colorScheme.primary), // Taille icône ajustée
                    const SizedBox(width: 12),
                    Text(
                      'Créer un nouveau journal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith( // Style de texte ajusté
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Si pas de journaux existants (en dehors de la carte de création)
          if (journals.isEmpty) {
            return Column(
              children: [
                createJournalCard,
                const Expanded( // Pour centrer le message "Aucun journal"
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_outlined, size: 50, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun journal existant.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Commencez par en créer un ci-dessus.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Si des journaux existent, afficher la carte de création, puis la section des journaux existants
          return ListView.builder(
            itemCount: journals.length + 2, // +1 pour la carte de création, +1 pour le titre de section et le Divider
            itemBuilder: (context, index) {
              if (index == 0) {
                return createJournalCard;
              }
              if (index == 1) {
                // Titre de section et Divider
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Journaux existants :",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 12, thickness: 1),
                    ],
                  ),
                );
              }

              // Pour les autres éléments, afficher les journaux existants
              // L'index réel du journal est index - 2
              final journalIndex = index - 2;
              final journal = journals[journalIndex];
              final bool isActive = journal.id == activeJournalNotifier.activeJournalId;

              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: isActive
                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  leading: Icon(
                      isActive ? Icons.menu_book_rounded : Icons.book_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28
                  ),
                  title: Text(journal.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 17)),
                  subtitle: Text('Créé le: ${dateFormat.format(journal.createdAt.toDate().toLocal())}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: "Modifier la palette de '${journal.name}'",
                        child: IconButton(
                          icon: const Icon(Icons.palette_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UnifiedPaletteEditorPage(
                                  journalToUpdatePaletteFor: journal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Tooltip(
                        message: "Modifier le nom / Options...",
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editJournalNameDialog(context, journal, firestoreService, activeJournalNotifier, currentUserId),
                        ),
                      ),
                    ],
                  ),
                  selected: isActive,
                  onTap: () {
                    if (!isActive) {
                      activeJournalNotifier.setActiveJournal(journal.id, currentUserId);
                      _loggerPage.i("Journal actif changé vers: ${journal.name}");
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editJournalNameDialog(BuildContext context, Journal journal, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId) async {
    final TextEditingController nameController = TextEditingController(text: journal.name);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Options du journal'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                  labelText: "Nouveau nom du journal",
                  hintText: "Entrez le nouveau nom ici",
                  border: OutlineInputBorder()
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le nom ne peut pas être vide.';
                }
                if (value.trim() == journal.name) {
                  return 'Le nouveau nom est identique à l\'ancien.';
                }
                if (value.length > 70) {
                  return 'Le nom du journal est trop long (max 70).';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Supprimer le journal'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteJournalDialog(context, journal, firestoreService, activeJournalNotifier, currentUserId);
              },
            ),
            ElevatedButton(
              child: const Text('Sauvegarder le nom'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  Navigator.of(dialogContext).pop();

                  if (newName.isNotEmpty && newName != journal.name) {
                    try {
                      bool nameExists = await firestoreService.checkJournalNameExists(newName, currentUserId);
                      if (nameExists && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Un journal nommé "$newName" existe déjà.'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      await firestoreService.updateJournalName(journal.id, newName);
                      _loggerPage.i("Nom du journal ${journal.id} mis à jour vers '$newName'");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nom du journal mis à jour.')),
                        );
                      }
                    } catch (e) {
                      _loggerPage.e("Erreur màj nom journal: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: ${e.toString()}')),
                        );
                      }
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteJournalDialog(BuildContext context, Journal journalToDelete, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: Text('Supprimer le journal "${journalToDelete.name}" ?'),
          content: const Text('Toutes les notes de ce journal seront également supprimées définitivement. Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogCtx).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Supprimer'),
              onPressed: () {
                Navigator.of(dialogCtx).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    final TextEditingController confirmTextController = TextEditingController();
    final GlobalKey<FormState> deleteFormKey = GlobalKey<FormState>();

    final bool? finalConfirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogCtx) {
          return AlertDialog(
            title: Text('CONFIRMATION FINALE pour "${journalToDelete.name}"'),
            content: Form(
              key: deleteFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Pour confirmer la suppression, veuillez taper 'SUPPRIMER' dans le champ ci-dessous."),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmTextController,
                    decoration: const InputDecoration(
                      labelText: 'Tapez SUPPRIMER ici',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != 'SUPPRIMER') {
                        return 'Texte de confirmation incorrect.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Annuler'),
                onPressed: () => Navigator.of(dialogCtx).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('CONFIRMER LA SUPPRESSION'),
                onPressed: () {
                  if (deleteFormKey.currentState!.validate()) {
                    Navigator.of(dialogCtx).pop(true);
                  }
                },
              ),
            ],
          );
        });

    if (finalConfirm == true) {
      bool wasActive = activeJournalNotifier.activeJournalId == journalToDelete.id;
      try {
        await firestoreService.deleteJournal(journalToDelete.id, currentUserId);
        _loggerPage.i("Journal ${journalToDelete.id} supprimé.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Journal "${journalToDelete.name}" supprimé.')),
          );
        }

        if (wasActive) {
          _loggerPage.i("Rechargement du journal initial après suppression du journal actif.");
          final journals = await firestoreService.getJournalsStream(currentUserId).first;
          if (context.mounted) {
            if (journals.isNotEmpty) {
              await activeJournalNotifier.setActiveJournal(journals.first.id, currentUserId);
            } else {
              activeJournalNotifier.clearActiveJournalState();
            }
          }
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression journal: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de suppression: ${e.toString()}')),
          );
        }
      }
    }
  }
}
