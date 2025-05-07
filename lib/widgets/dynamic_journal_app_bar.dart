import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../screens/journal_management_page.dart';
import '../screens/palette_model_management_page.dart';

final _loggerAppBar = Logger(printer: PrettyPrinter(methodCount: 0));

class DynamicJournalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;

  DynamicJournalAppBar({Key? key, this.titleText = "Colors & Notes"}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? currentUserId = authService.currentUser?.uid;

    String displayTitle = titleText;
    if (activeJournalNotifier.isLoading) {
      displayTitle = "Chargement...";
    } else if (activeJournalNotifier.activeJournal != null) {
      displayTitle = activeJournalNotifier.activeJournal!.name;
    } else if (activeJournalNotifier.errorMessage != null) {
      displayTitle = "Erreur";
    } else if (currentUserId != null && activeJournalNotifier.activeJournalId == null) {
      displayTitle = "Sélectionner un journal";
    }


    return AppBar(
      title: Text(displayTitle),
      actions: <Widget>[
        if (currentUserId != null)
          StreamBuilder<List<Journal>>(
            stream: firestoreService.getJournalsStream(currentUserId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty || currentUserId == null) {
                return PopupMenuButton<String>(
                  icon: Icon(Icons.menu_book_outlined), // Icône originale
                  tooltip: "Gérer",
                  onSelected: (value) {
                    if (value == 'manage_journals') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => JournalManagementPage()));
                    } else if (value == 'manage_palette_models') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PaletteModelManagementPage()));
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'manage_journals',
                      child: Text('Gérer les journaux'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'manage_palette_models',
                      child: Text('Gérer les modèles'), // Texte original
                    ),
                  ],
                );
              }

              final journals = snapshot.data!;
              return PopupMenuButton<String>(
                icon: Icon(Icons.swap_horiz_outlined), // Icône originale
                tooltip: "Changer de journal",
                onSelected: (String journalId) {
                  if (journalId == 'manage_journals') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => JournalManagementPage()));
                  } else if (journalId == 'manage_palette_models') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => PaletteModelManagementPage()));
                  } else {
                    activeJournalNotifier.setActiveJournal(journalId, currentUserId);
                    _loggerAppBar.i("Journal actif changé via AppBar: $journalId");
                  }
                },
                itemBuilder: (BuildContext context) {
                  List<PopupMenuEntry<String>> items = journals.map((Journal journal) {
                    return PopupMenuItem<String>(
                      value: journal.id,
                      child: Text(
                        journal.name,
                        style: TextStyle(
                          fontWeight: activeJournalNotifier.activeJournalId == journal.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList();
                  items.add(const PopupMenuDivider());
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'manage_journals',
                      child: Text('Gérer les journaux...'),
                    ),
                  );
                  items.add(
                    const PopupMenuItem<String>(
                      value: 'manage_palette_models',
                      child: Text('Gérer les modèles...'), // Texte original
                    ),
                  );
                  return items;
                },
              );
            },
          ),
        IconButton(
          icon: Icon(Icons.logout_outlined), // Icône originale
          tooltip: "Déconnexion",
          onPressed: () async {
            await authService.signOut();
            _loggerAppBar.i("Déconnexion demandée.");
            // AuthGate gère la navigation
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
