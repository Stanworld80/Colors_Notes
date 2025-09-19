// lib/widgets/dynamic_journal_app_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../providers/active_journal_provider.dart';
import '../screens/help_page.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../screens/palette_model_management_page.dart';
import '../screens/unified_palette_editor_page.dart';
import '../screens/about_page.dart';
import '../screens/colors_notes_license_page.dart';
import 'package:colors_notes/l10n/app_localizations.dart';
import '../screens/privacy_policy_page.dart';
import '../screens/create_journal_page.dart'; // Importez la page de création de journal
import '../screens/main_screen.dart';
import '../screens/auth_gate.dart';

/// Logger instance for this AppBar widget.
final _loggerAppBar = Logger(printer: PrettyPrinter(methodCount: 0));

class DynamicJournalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String defaultTitleText;

  const DynamicJournalAppBar({super.key, this.defaultTitleText = "Colors & Notes"});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? currentUserId = authService.currentUser?.uid;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;
    final l10n = AppLocalizations.of(context)!;

    String displayTitle = l10n.appName;
    if (activeJournalNotifier.isLoading) {
      displayTitle = l10n.loadingTitle; // Utilisation de la nouvelle clé
    } else if (activeJournal != null) {
      displayTitle = activeJournal.name;
    } else if (activeJournalNotifier.errorMessage != null) {
      displayTitle = l10n.errorTitle; // Utilisation de la nouvelle clé
    } else if (currentUserId != null && activeJournalNotifier.activeJournalId == null) {
      displayTitle = l10n.chooseJournalTitle; // Utilisation de la nouvelle clé
    }

    return AppBar(
      leading: Tooltip(
        message: l10n.homeButtonTooltip,
        child: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () {
            // Navigate to the home page, which is LoggedHomepage
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
              (Route<dynamic> route) => false, // This predicate removes all routes from the stack
            );
          },
        ),
      ),
      title:
      currentUserId == null
          ? Text(displayTitle)
          : StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            // If no journals or loading, still show a dropdown that leads to 'New Journal'
            return PopupMenuButton<String>(
              tooltip: l10n.changeJournalTooltip,
              onSelected: (String value) {
                if (value == 'new_journal') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJournalPage()));
                } else if (value.isNotEmpty) {
                  activeJournalNotifier.setActiveJournal(value, currentUserId);
                  _loggerAppBar.i("Journal actif changé via Titre AppBar: $value");
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'new_journal',
                    child: ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(l10n.newJournalMenuItem), // Nouvelle clé de localisation
                    ),
                  ),
                  const PopupMenuDivider(),
                  // If no other journals, maybe show a disabled placeholder or just the 'new_journal' option.
                  // For now, if snapshot.data is empty, only 'new_journal' and divider will be shown
                  // by this specific builder path, as journalItems will be empty.
                ];
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.book_outlined, size: 20), const SizedBox(width: 8), Flexible(child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18)))],
              ),
            );
          }

          final journals = snapshot.data!;
          return PopupMenuButton<String>(
            tooltip: l10n.changeJournalTooltip, // Utilisation de la nouvelle clé
            onSelected: (String value) {
              if (value == 'new_journal') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJournalPage()));
              } else if (value.isNotEmpty) {
                activeJournalNotifier.setActiveJournal(value, currentUserId);
                _loggerAppBar.i("Journal actif changé via Titre AppBar: $value");
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuItem<String>> journalItems =
              journals.map((Journal journal) {
                return PopupMenuItem<String>(
                  value: journal.id,
                  child: Text(
                    journal.name,
                    style: TextStyle(
                      fontWeight: activeJournalNotifier.activeJournalId == journal.id ? FontWeight.bold : FontWeight.normal,
                      color: activeJournalNotifier.activeJournalId == journal.id ? Theme
                          .of(context)
                          .colorScheme
                          .primary : null,
                    ),
                  ),
                );
              }).toList();

              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'new_journal',
                  child: ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(l10n.newJournalMenuItem), // Nouvelle clé de localisation
                  ),
                ),
                const PopupMenuDivider(),
                ...journalItems, // Spread operator to add all journal items
              ];
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.book_outlined, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18))),
                const Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          );
        },
      ),
      centerTitle: true,
      actions: <Widget>[
        if (activeJournal != null)
          Tooltip(
            message: l10n.editJournalNameTooltip, // Nouvelle clé de localisation pour l'infobulle
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                // Appel de la fonction de dialogue pour éditer le nom du journal
                if (currentUserId != null && activeJournal != null) {
                  _showEditActiveJournalNameDialog(context, activeJournal, currentUserId, firestoreService, l10n);
                }
              },
            ),
          ),
        if (activeJournal != null)
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: l10n.editPaletteTooltip(activeJournal.name), // Utilisation de la nouvelle clé
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => UnifiedPaletteEditorPage(journalToUpdatePaletteFor: activeJournal)));
            },
          )
        ,

        if (currentUserId != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_outlined),
            tooltip: l10n.optionsTooltip,
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'manage_notes') {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 1)), (route) => false);
              } else if (value == 'manage_journals') {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 2)), (route) => false);
              } else if (value == 'manage_palette_models') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaletteModelManagementPage()));
              } else if (value == 'about') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              } else if (value == 'help') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpPage()));
              } else if (value == 'license') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ColorsNotesLicensePage()));
              } else if (value == 'privacy_policy') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()));
              } else if (value == 'sign_out') {
                authService
                    .signOut()
                    .then((_) {
                  _loggerAppBar.i("Déconnexion demandée.");
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                        (Route<dynamic> route) => false,
                  );
                })
                    .catchError((e) {
                  _loggerAppBar.e("Erreur déconnexion: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${l10n.signOutErrorPrefix}$e")), // Utilisation de la nouvelle clé
                    );
                  }
                });

              }
            },
            itemBuilder:
                (BuildContext context) =>
            <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_outlined), title: Text(l10n.settings))),
              const PopupMenuDivider(),
              PopupMenuItem<String>(value: 'manage_notes', child: ListTile(leading: const Icon(Icons.collections_bookmark_outlined), title: Text(l10n.manageNotes))),
              PopupMenuItem<String>(value: 'manage_journals', child: ListTile(leading: const Icon(Icons.collections_bookmark_outlined), title: Text(l10n.manageJournals))),
              PopupMenuItem<String>(value: 'manage_palette_models', child: ListTile(leading: const Icon(Icons.palette_outlined), title: Text(l10n.managePaletteModels))),
              const PopupMenuDivider(),
              PopupMenuItem<String>(value: 'about', child: ListTile(leading: const Icon(Icons.info_outline), title: Text(l10n.about))),
              PopupMenuItem<String>(value: 'license', child: ListTile(leading: const Icon(Icons.description_outlined), title: Text(l10n.licenseLink))),
              PopupMenuItem<String>(value: 'help', child: ListTile(leading: const Icon(Icons.help_outline), title: Text(l10n.help))),
              PopupMenuItem<String>(value: 'privacy_policy', child: ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(l10n.privacyPolicy),
              ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(value: 'sign_out', child: ListTile(leading: const Icon(Icons.logout_outlined), title: Text(l10n.logout))),
            ],
          ),
      ],
    );
  }

  // Fonction pour afficher le dialogue d'édition du nom du journal actif
  Future<void> _showEditActiveJournalNameDialog(BuildContext context, Journal journal, String userId, FirestoreService firestoreService, AppLocalizations l10n) async {
    final TextEditingController nameController = TextEditingController(text: journal.name);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // L'utilisateur doit appuyer sur un bouton pour fermer
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.journalOptionsDialogTitle), // Réutilise cette clé pour le titre du dialogue
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
            ElevatedButton(
              child: Text(l10n.saveNameButtonLabel),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  Navigator.of(dialogContext).pop(); // Fermer le dialogue

                  if (newName.isNotEmpty && newName != journal.name) {
                    try {
                      bool nameExists = await firestoreService.checkJournalNameExists(newName, userId);
                      if (nameExists && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.journalNameExistsSnackbar(newName)), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      await firestoreService.updateJournalName(journal.id, newName);
                      _loggerAppBar.i("Journal name ${journal.id} updated to '$newName'");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.journalNameUpdatedSnackbar)),
                        );
                      }
                    } catch (e) {
                      _loggerAppBar.e("Error updating journal name: $e");
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

  @override
  Size get preferredSize =>
      const Size.fromHeight(
          kToolbarHeight
      );
}
