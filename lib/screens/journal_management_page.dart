import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart'; // For date formatting.

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../models/journal.dart';
import 'create_journal_page.dart';
import 'unified_palette_editor_page.dart';

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

/// A screen for managing the user's journals.
///
/// This page displays a list of existing journals, allowing the user to:
/// - View and select an active journal.
/// - Create a new journal.
/// - Edit the name of an existing journal.
/// - Delete an existing journal (with confirmation).
/// - Navigate to edit the palette of an existing journal.
class JournalManagementPage extends StatelessWidget {
  /// Creates an instance of [JournalManagementPage].
  const JournalManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context); // listen: true to rebuild on active journal change
    final String? currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      _loggerPage.w("JournalManagementPage: currentUserId est null.");
      return Scaffold(
          appBar: AppBar(title: const Text('Gérer les Journaux')), // UI Text in French
          body: const Center(child: Text("Utilisateur non connecté."))); // UI Text in French
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Journaux'), // UI Text in French
      ),
      body: StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Erreur chargement journaux: ${snapshot.error}");
            return Center(child: Text('Erreur de chargement des journaux: ${snapshot.error.toString()}')); // UI Text in French
          }

          final journals = snapshot.data ?? [];
          // Date formatter for displaying creation dates.
          final DateFormat dateFormat = DateFormat('dd MMM yy, HH:mm', 'fr_FR'); // Date format in French. yy for two-digit year.

          // Card for creating a new journal, always displayed at the top.
          Widget createJournalCard = Card(
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Créer un nouveau journal', // UI Text in French
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // If no journals exist, display the creation card and a message.
          if (journals.isEmpty) {
            return Column(
              children: [
                createJournalCard,
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_outlined, size: 50, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun journal existant.', // UI Text in French
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Commencez par en créer un ci-dessus.', // UI Text in French
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

          // If journals exist, display the creation card, a section title, and then the list of journals.
          return ListView.builder(
            itemCount: journals.length + 2, // +1 for create card, +1 for section header
            itemBuilder: (context, index) {
              if (index == 0) {
                return createJournalCard;
              }
              if (index == 1) {
                // Section title for existing journals
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Journaux existants :", // UI Text in French
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

              // Adjust index for accessing the journals list
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
                      : BorderSide.none, // No border for non-active journals
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  leading: Icon(
                      isActive ? Icons.menu_book_rounded : Icons.book_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28
                  ),
                  title: Text(journal.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 17)),
                  subtitle: Text('Créé le: ${dateFormat.format(journal.createdAt.toDate().toLocal())}', style: const TextStyle(fontSize: 12)), // UI Text in French
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: "Modifier la palette de '${journal.name}'", // UI Text in French
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
                        message: "Modifier le nom / Options...", // UI Text in French
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

  /// Displays a dialog to edit the name of a [Journal] or delete it.
  ///
  /// [context] The build context.
  /// [journal] The journal to be edited or deleted.
  /// [firestoreService] Instance of [FirestoreService] for database operations.
  /// [activeJournalNotifier] Instance of [ActiveJournalNotifier] to manage active journal state.
  /// [currentUserId] The ID of the current user.
  Future<void> _editJournalNameDialog(BuildContext context, Journal journal, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId) async {
    final TextEditingController nameController = TextEditingController(text: journal.name);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Options du journal'), // UI Text in French
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                  labelText: "Nouveau nom du journal", // UI Text in French
                  hintText: "Entrez le nouveau nom ici", // UI Text in French
                  border: OutlineInputBorder()
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le nom ne peut pas être vide.'; // UI Text in French
                }
                if (value.trim() == journal.name) {
                  return 'Le nouveau nom est identique à l\'ancien.'; // UI Text in French
                }
                if (value.length > 70) {
                  return 'Le nom du journal est trop long (max 70).'; // UI Text in French
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'), // UI Text in French
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Supprimer le journal'), // UI Text in French
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close edit dialog first
                _deleteJournalDialog(context, journal, firestoreService, activeJournalNotifier, currentUserId);
              },
            ),
            ElevatedButton(
              child: const Text('Sauvegarder le nom'), // UI Text in French
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  Navigator.of(dialogContext).pop(); // Close dialog

                  if (newName.isNotEmpty && newName != journal.name) {
                    try {
                      // Check if a journal with the new name already exists
                      bool nameExists = await firestoreService.checkJournalNameExists(newName, currentUserId);
                      if (nameExists && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Un journal nommé "$newName" existe déjà.'), backgroundColor: Colors.orange), // UI Text in French
                        );
                        return; // Prevent update if name exists
                      }

                      await firestoreService.updateJournalName(journal.id, newName);
                      _loggerPage.i("Nom du journal ${journal.id} mis à jour vers '$newName'");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nom du journal mis à jour.')), // UI Text in French
                        );
                        // The stream builder will automatically reflect the name change.
                        // If this was the active journal, its name in ActiveJournalNotifier might need an update
                        // if the notifier doesn't re-fetch on its own.
                        // However, setActiveJournal is usually called with ID, and it fetches the latest.
                      }
                    } catch (e) {
                      _loggerPage.e("Erreur màj nom journal: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: ${e.toString()}')), // UI Text in French
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

  /// Displays a two-step confirmation dialog to delete a [Journal].
  ///
  /// The first step asks for simple confirmation. The second step requires typing "SUPPRIMER".
  /// If confirmed, the journal and its associated notes are deleted.
  /// If the deleted journal was active, it attempts to set a new active journal.
  ///
  /// [context] The build context.
  /// [journalToDelete] The journal to be deleted.
  /// [firestoreService] Instance of [FirestoreService] for database operations.
  /// [activeJournalNotifier] Instance of [ActiveJournalNotifier] to manage active journal state.
  /// [currentUserId] The ID of the current user.
  Future<void> _deleteJournalDialog(BuildContext context, Journal journalToDelete, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId) async {
    // First confirmation dialog
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: Text('Supprimer le journal "${journalToDelete.name}" ?'), // UI Text in French
          content: const Text('Toutes les notes de ce journal seront également supprimées définitivement. Cette action est irréversible.'), // UI Text in French
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'), // UI Text in French
              onPressed: () {
                Navigator.of(dialogCtx).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Supprimer'), // UI Text in French
              onPressed: () {
                Navigator.of(dialogCtx).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return; // User cancelled the first dialog

    // Second, type-to-confirm dialog
    final TextEditingController confirmTextController = TextEditingController();
    final GlobalKey<FormState> deleteFormKey = GlobalKey<FormState>();

    final bool? finalConfirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogCtx) {
          return AlertDialog(
            title: Text('CONFIRMATION FINALE pour "${journalToDelete.name}"'), // UI Text in French
            content: Form(
              key: deleteFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Pour confirmer la suppression, veuillez taper 'SUPPRIMER' dans le champ ci-dessous."), // UI Text in French
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmTextController,
                    decoration: const InputDecoration(
                      labelText: 'Tapez SUPPRIMER ici', // UI Text in French
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value != 'SUPPRIMER') { // Case-sensitive confirmation
                        return 'Texte de confirmation incorrect.'; // UI Text in French
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Annuler'), // UI Text in French
                onPressed: () => Navigator.of(dialogCtx).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('CONFIRMER LA SUPPRESSION'), // UI Text in French
                onPressed: () {
                  if (deleteFormKey.currentState!.validate()) {
                    Navigator.of(dialogCtx).pop(true);
                  }
                },
              ),
            ],
          );
        });

    if (finalConfirm == true) { // User confirmed deletion by typing "SUPPRIMER"
      bool wasActive = activeJournalNotifier.activeJournalId == journalToDelete.id;
      try {
        await firestoreService.deleteJournal(journalToDelete.id, currentUserId);
        _loggerPage.i("Journal ${journalToDelete.id} supprimé.");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Journal "${journalToDelete.name}" supprimé.')), // UI Text in French
          );
        }

        // If the deleted journal was the active one, try to set a new active journal.
        if (wasActive) {
          _loggerPage.i("Rechargement du journal initial après suppression du journal actif.");
          final journals = await firestoreService.getJournalsStream(currentUserId).first;
          if (context.mounted) {
            if (journals.isNotEmpty) {
              // Set the first available journal as active
              await activeJournalNotifier.setActiveJournal(journals.first.id, currentUserId);
            } else {
              // No other journals left, clear the active journal state
              activeJournalNotifier.clearActiveJournalState();
            }
          }
        }
      } catch (e) {
        _loggerPage.e("Erreur suppression journal: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de suppression: ${e.toString()}')), // UI Text in French
          );
        }
      }
    }
  }
}
