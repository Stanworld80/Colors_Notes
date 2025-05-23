// lib/widgets/dynamic_journal_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../screens/journal_management_page.dart';
import '../screens/palette_model_management_page.dart';
import '../screens/unified_palette_editor_page.dart';
import '../screens/about_page.dart';
import '../screens/colors_notes_license_page.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

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
      title: currentUserId == null
          ? Text(displayTitle)
          : StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.book_outlined, size: 20),
                const SizedBox(width: 8),
                Text(displayTitle, style: const TextStyle(fontSize: 18)),
              ],
            );
          }

          final journals = snapshot.data!;
          return PopupMenuButton<String>(
            tooltip: l10n.changeJournalTooltip, // Utilisation de la nouvelle clé
            onSelected: (String journalId) {
              if (journalId.isNotEmpty) {
                activeJournalNotifier.setActiveJournal(journalId, currentUserId);
                _loggerAppBar.i("Journal actif changé via Titre AppBar: $journalId");
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuItem<String>> journalItems = journals.map((Journal journal) {
                return PopupMenuItem<String>(
                  value: journal.id,
                  child: Text(
                    journal.name,
                    style: TextStyle(
                      fontWeight: activeJournalNotifier.activeJournalId == journal.id
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: activeJournalNotifier.activeJournalId == journal.id
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                );
              }).toList();
              return journalItems;
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.book_outlined, size: 20),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18))
                ),
                const Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          );
        },
      ),
      centerTitle: true,
      actions: <Widget>[
        if (activeJournal != null)
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: l10n.editPaletteTooltip(activeJournal.name), // Utilisation de la nouvelle clé
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UnifiedPaletteEditorPage(
                    journalToUpdatePaletteFor: activeJournal,
                  ),
                ),
              );
            },
          ),

        if (currentUserId != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_outlined),
            tooltip: l10n.optionsTooltip, // MODIFIÉ ICI pour utiliser la nouvelle clé
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              } else if (value == 'manage_journals') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const JournalManagementPage()));
              } else if (value == 'manage_palette_models') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaletteModelManagementPage()));
              } else if (value == 'about') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              } else if (value == 'license') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ColorsNotesLicensePage()));
              } else if (value == 'sign_out') {
                authService.signOut().then((_) {
                  _loggerAppBar.i("Déconnexion demandée.");
                }).catchError((e) {
                  _loggerAppBar.e("Erreur déconnexion: $e");
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${l10n.signOutErrorPrefix}$e")) // Utilisation de la nouvelle clé
                    );
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settings),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'manage_journals',
                child: ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(l10n.manageJournals),
                ),
              ),
              PopupMenuItem<String>(
                value: 'manage_palette_models',
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.managePaletteModels),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'about',
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.about),
                ),
              ),
              PopupMenuItem<String>(
                value: 'license',
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.licenseLink),
                ),
              ),
              PopupMenuItem<String>(
                value: 'help',
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(l10n.help),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'sign_out',
                child: ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: Text(l10n.logout),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
