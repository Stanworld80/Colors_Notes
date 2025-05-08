// lib/screens/journal_management_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart'; // Pour le formatage de date

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../models/journal.dart';
import 'create_journal_page.dart';
import 'unified_palette_editor_page.dart'; // Importer la page d'édition de palette unifiée

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));
const _uuid = Uuid();

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
          appBar: AppBar(title: Text('Gérer les Journaux')),
          body: Center(child: Text("Utilisateur non connecté.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Gérer les Journaux'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            tooltip: "Créer un nouveau journal",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateJournalPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Erreur chargement journaux: ${snapshot.error}");
            return Center(child: Text('Erreur de chargement des journaux.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                        SizedBox(height: 16),
                        Text('Aucun journal trouvé.', style: Theme.of(context).textTheme.headlineSmall),
                        SizedBox(height: 8),
                        Text('Créez votre premier journal en utilisant le bouton "+" en haut.', textAlign: TextAlign.center),
                      ]
                  ),
                )
            );
          }

          final journals = snapshot.data!;
          final DateFormat dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR');

          return ListView.builder(
            itemCount: journals.length,
            itemBuilder: (context, index) {
              final journal = journals[index];
              final bool isActive = journal.id == activeJournalNotifier.activeJournalId;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
                child: ListTile(
                  leading: Icon(isActive ? Icons.book : Icons.book_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text(journal.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text('Créé le: ${dateFormat.format(journal.createdAt.toDate().toLocal())}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nouvelle icône pour éditer la palette
                      IconButton(
                        icon: Icon(Icons.palette_outlined),
                        tooltip: "Modifier la palette de '${journal.name}'",
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
                      IconButton(
                        icon: Icon(Icons.edit_outlined),
                        tooltip: "Modifier le nom",
                        onPressed: () => _editJournalNameDialog(context, journal, firestoreService),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                        tooltip: "Supprimer le journal",
                        onPressed: () => _deleteJournalDialog(context, journal, firestoreService, activeJournalNotifier, currentUserId),
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

  Future<void> _editJournalNameDialog(BuildContext context, Journal journal, FirestoreService firestoreService) async {
    final TextEditingController nameController = TextEditingController(text: journal.name);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Modifier le nom du journal'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: "Nouveau nom du journal"),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('Sauvegarder'),
              onPressed: () async {
                final newName = nameController.text.trim();
                Navigator.of(dialogContext).pop();
                if (newName.isNotEmpty && newName != journal.name) {
                  try {
                    await firestoreService.updateJournalName(journal.id, newName);
                    _loggerPage.i("Nom du journal ${journal.id} mis à jour vers '$newName'");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nom du journal mis à jour.')),
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
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteJournalDialog(BuildContext context, Journal journalToDelete, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Supprimer le journal ?'),
          content: Text('"${journalToDelete.name}" et toutes ses notes seront supprimés définitivement. Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Supprimer'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
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
                        Provider.of<ActiveJournalNotifier>(context, listen: false).notifyListeners();
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
              },
            ),
          ],
        );
      },
    );
  }
}
