import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting.
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context); // listen: true to rebuild on active journal change
    final String? currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      _loggerPage.w("JournalManagementPage: currentUserId is null."); // Log in English
      return Scaffold(
          appBar: AppBar(title: Text(l10n.manageJournalsAppBarTitle)),
          body: Center(child: Text(l10n.userNotConnectedError)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageJournalsAppBarTitle),
      ),
      body: StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Error loading journals: ${snapshot.error}"); // Log in English
            return Center(child: Text(l10n.errorLoadingJournals(snapshot.error.toString())));
          }

          final journals = snapshot.data ?? [];
          // Date formatter for displaying creation dates.
          // Using current locale from AppLocalizations for date formatting.
          final DateFormat dateFormat = DateFormat('dd MMM yy, HH:mm', l10n.localeName);

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
                      l10n.createNewJournalCardLabel,
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
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.library_books_outlined, size: 50, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noExistingJournalsMessage,
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.startByCreatingOneMessage,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                        l10n.existingJournalsSectionTitle,
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
                  subtitle: Text(l10n.journalCreatedOnDateLabel(dateFormat.format(journal.createdAt.toDate().toLocal())), style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: l10n.editPaletteForJournalTooltip(journal.name),
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
                        message: l10n.editNameOptionsTooltip,
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editJournalNameDialog(context, journal, firestoreService, activeJournalNotifier, currentUserId, l10n),
                        ),
                      ),
                    ],
                  ),
                  selected: isActive,
                  onTap: () {
                    if (!isActive) {
                      activeJournalNotifier.setActiveJournal(journal.id, currentUserId);
                      _loggerPage.i("Active journal changed to: ${journal.name}"); // Log in English
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
  Future<void> _editJournalNameDialog(BuildContext context, Journal journal, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId, AppLocalizations l10n) async {
    final TextEditingController nameController = TextEditingController(text: journal.name);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext dialogContext) {
        // Note: It's better to get l10n from the parent context if possible,
        // but for dialogs, passing it or getting it from dialogContext is also an option.
        // Here, we are passing it as a parameter.
        return AlertDialog(
          title: Text(l10n.journalOptionsDialogTitle),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                  labelText: l10n.newJournalNameLabel,
                  hintText: l10n.newJournalNameHint,
                  border: const OutlineInputBorder()
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.nameCannotBeEmptyValidator;
                }
                if (value.trim() == journal.name) {
                  return l10n.newNameSameAsOldValidator;
                }
                if (value.length > 70) {
                  return l10n.journalNameTooLongValidator;
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancelButtonLabel),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: Text(l10n.deleteJournalButtonLabel),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close edit dialog first
                _deleteJournalDialog(context, journal, firestoreService, activeJournalNotifier, currentUserId, l10n);
              },
            ),
            ElevatedButton(
              child: Text(l10n.saveNameButtonLabel),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  Navigator.of(dialogContext).pop(); // Close dialog

                  if (newName.isNotEmpty && newName != journal.name) {
                    try {
                      bool nameExists = await firestoreService.checkJournalNameExists(newName, currentUserId);
                      if (nameExists && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.journalNameExistsSnackbar(newName)), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      await firestoreService.updateJournalName(journal.id, newName);
                      _loggerPage.i("Journal name ${journal.id} updated to '$newName'"); // Log in English
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.journalNameUpdatedSnackbar)),
                        );
                      }
                    } catch (e) {
                      _loggerPage.e("Error updating journal name: $e"); // Log in English
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.genericErrorSnackbar(e.toString()))),
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
  Future<void> _deleteJournalDialog(BuildContext context, Journal journalToDelete, FirestoreService firestoreService, ActiveJournalNotifier activeJournalNotifier, String currentUserId, AppLocalizations l10n) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) {
        return AlertDialog(
          title: Text(l10n.deleteJournalDialogTitle(journalToDelete.name)),
          content: Text(l10n.deleteJournalDialogContent),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancelButtonLabel),
              onPressed: () {
                Navigator.of(dialogCtx).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: Text(l10n.deleteButtonLabel),
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
            title: Text(l10n.finalConfirmationDialogTitle(journalToDelete.name)),
            content: Form(
              key: deleteFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.finalConfirmationDialogContent), // This key should include "SUPPRIMER" or be generic
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmTextController,
                    decoration: InputDecoration(
                      labelText: l10n.typeDeleteHereLabel, // Assumes "SUPPRIMER" is part of this label or instruction
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      // The confirmation text 'DELETE' (or localized equivalent) should come from l10n if it's to be localized.
                      // For now, assuming 'DELETE' is the required input string as per previous English key.
                      if (value != 'DELETE') {
                        return l10n.incorrectConfirmationTextValidator;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(l10n.cancelButtonLabel),
                onPressed: () => Navigator.of(dialogCtx).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: Text(l10n.confirmDeletionButtonLabel),
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
        _loggerPage.i("Journal ${journalToDelete.id} deleted."); // Log in English
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.journalDeletedSnackbar(journalToDelete.name))),
          );
        }

        if (wasActive) {
          _loggerPage.i("Reloading initial journal after deleting active journal."); // Log in English
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
        _loggerPage.e("Error deleting journal: $e"); // Log in English
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorDeletingJournalSnackbar(e.toString()))),
          );
        }
      }
    }
  }
}
