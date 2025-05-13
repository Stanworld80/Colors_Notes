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
import '../screens/license_page.dart';

final _loggerAppBar = Logger(printer: PrettyPrinter(methodCount: 0));

class DynamicJournalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String defaultTitleText;

  DynamicJournalAppBar({Key? key, this.defaultTitleText = "Colors & Notes"}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? currentUserId = authService.currentUser?.uid;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;

    String displayTitle = defaultTitleText;
    if (activeJournalNotifier.isLoading) {
      displayTitle = "Chargement...";
    } else if (activeJournal != null) {
      displayTitle = activeJournal.name;
    } else if (activeJournalNotifier.errorMessage != null) {
      displayTitle = "Erreur";
    } else if (currentUserId != null && activeJournalNotifier.activeJournalId == null) {
      displayTitle = "Choisir un journal";
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
                Icon(Icons.book_outlined, size: 20),
                SizedBox(width: 8),
                Text(displayTitle, style: TextStyle(fontSize: 18)),
              ],
            );
          }

          final journals = snapshot.data!;
          return PopupMenuButton<String>(
            tooltip: "Changer de journal",
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
                Icon(Icons.book_outlined, size: 20),
                SizedBox(width: 8),
                Flexible(child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18))),
                Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          );
        },
      ),
      centerTitle: true,
      actions: <Widget>[
        if (activeJournal != null)
          IconButton(
            icon: Icon(Icons.palette_rounded),
            tooltip: "Modifier la palette de '${activeJournal.name}'",
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
            icon: Icon(Icons.more_vert_outlined),
            tooltip: "Options",
            onSelected: (value) {
              if (value == 'manage_journals') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => JournalManagementPage()));
              } else if (value == 'manage_palette_models') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PaletteModelManagementPage()));
              } else if (value == 'about') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AboutPage()));
              } else if (value == 'license') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ColorsNotesLicensePage()));
              } else if (value == 'sign_out') {
                authService.signOut().then((_) {
                  _loggerAppBar.i("Déconnexion demandée.");
                }).catchError((e) {
                  _loggerAppBar.e("Erreur déconnexion: $e");
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur lors de la déconnexion: $e"))
                    );
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Options de gestion
              const PopupMenuItem<String>(
                value: 'manage_journals',
                child: ListTile(
                  leading: Icon(Icons.collections_bookmark_outlined),
                  title: Text('Journaux'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage_palette_models',
                child: ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Modèles de palette'),
                ),
              ),
              const PopupMenuDivider(), // Séparateur
              // Nouvelles options
              const PopupMenuItem<String>(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('À Propos'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'license',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Licence'),
                ),
              ),
              const PopupMenuDivider(), // Séparateur
              // Déconnexion
              const PopupMenuItem<String>(
                value: 'sign_out',
                child: ListTile(
                  leading: Icon(Icons.logout_outlined),
                  title: Text('Déconnexion'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
