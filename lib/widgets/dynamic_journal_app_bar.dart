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
import '../screens/settings_page.dart';
import 'package:colors_notes/l10n/app_localizations.dart';

/// Logger instance for this AppBar widget.
final _loggerAppBar = Logger(printer: PrettyPrinter(methodCount: 0));

class DynamicJournalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? defaultTitleText; // Made nullable

  const DynamicJournalAppBar({super.key, this.defaultTitleText}); // Updated constructor

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? currentUserId = authService.currentUser?.uid;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;
    final l10n = AppLocalizations.of(context)!;

    // Title logic wrapped in StreamBuilder to correctly use journalsSnapshot.data
    Widget titleWidget;
    if (currentUserId == null) {
      // If no user, display default or app name
      titleWidget = Text(widget.defaultTitleText ?? l10n.appName, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis);
    } else {
      titleWidget = StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, journalsSnapshot) {
          String displayTitle = widget.defaultTitleText ?? l10n.appName;

          if (activeJournalNotifier.isLoading) {
            displayTitle = l10n.loadingTitle;
          } else if (activeJournal != null) {
            displayTitle = activeJournal.name;
          } else if (activeJournalNotifier.errorMessage != null) {
            displayTitle = l10n.errorTitle;
          } else if (activeJournalNotifier.activeJournalId == null &&
                     journalsSnapshot.hasData &&
                     journalsSnapshot.data != null &&
                     journalsSnapshot.data!.isNotEmpty) {
            // Show "Choose a journal" only if there are journals and none is active
            displayTitle = l10n.chooseJournalTitle;
          }
          // Otherwise, it remains defaultTitleText or l10n.appName

          if (!journalsSnapshot.hasData || journalsSnapshot.data == null || journalsSnapshot.data!.isEmpty) {
            // If no journals, display the title without dropdown
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.book_outlined, size: 20),
                const SizedBox(width: 8),
                Flexible(child: Text(displayTitle, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis)),
              ],
            );
          }

          final journals = journalsSnapshot.data!;
          return PopupMenuButton<String>(
            tooltip: l10n.changeJournalTooltip,
            onSelected: (String journalId) {
              if (journalId.isNotEmpty) {
                activeJournalNotifier.setActiveJournal(journalId, currentUserId);
                _loggerAppBar.i("Active journal changed via AppBar Title: $journalId"); // Log in English
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
      );
    }

    return AppBar(
      title: titleWidget,
      centerTitle: true,
      actions: <Widget>[
        if (activeJournal != null)
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: l10n.editPaletteTooltip(activeJournal.name),
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
                tooltip: l10n.optionsAppBarTooltip, // Changed to optionsAppBarTooltip
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
                      _loggerAppBar.i("Sign out requested."); // Log in English
                    }).catchError((e) {
                      _loggerAppBar.e("Sign out error: $e"); // Log in English
                      if(context.mounted){
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.signOutErrorSnackbar(e.toString()))) // Used signOutErrorSnackbar
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
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
