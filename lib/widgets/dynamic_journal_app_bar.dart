import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../screens/journal_management_page.dart';
import '../screens/palette_model_management_page.dart';
import '../screens/edit_palette_model_page.dart'; // Import pour éditer la palette du journal

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
    final Journal? activeJournal = activeJournalNotifier.activeJournal; // Obtenir le journal actif

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
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book_outlined, size: 20),
                SizedBox(width: 8),
                Text(displayTitle),
              ],
            );
          }

          final journals = snapshot.data!;
          return PopupMenuButton<String>(
            tooltip: "Changer de journal",
            onSelected: (String journalId) {
              if (journalId == 'manage_journals') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => JournalManagementPage()));
              } else if (journalId == 'manage_palette_models') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PaletteModelManagementPage()));
              } else {
                activeJournalNotifier.setActiveJournal(journalId, currentUserId);
                _loggerAppBar.i("Journal actif changé via Titre AppBar: $journalId");
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuItem<String>> items = journals.map((Journal journal) {
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
              items.add(const PopupMenuItem<String>(value: 'manage_journals', child: Text('Gérer les journaux...')));
              return items;
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.book_outlined, size: 20),
                SizedBox(width: 8),
                Text(displayTitle),
                Icon(Icons.arrow_drop_down, size: 24),
              ],
            ),
          );
        },
      ),
      centerTitle: true,
      actions: <Widget>[
        // --- Bouton pour éditer la palette du journal ACTIF ---
        if (activeJournal != null) // Afficher seulement si un journal est actif
          IconButton(
            icon: Icon(Icons.palette_outlined), // Icône Palette
            tooltip: "Modifier la palette de '${activeJournal.name}'",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPaletteModelPage(
                    // Passer le journal actif pour éditer sa palette
                    journalToUpdatePaletteFor: activeJournal,
                  ),
                ),
              );
            },
          ),
        // --- Fin Bouton Palette ---

        // Menu d'actions simplifié (peut contenir gestion modèles, etc.)
        if (currentUserId != null)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_outlined),
            tooltip: "Options",
            onSelected: (value) {
              if (value == 'manage_palette_models') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => PaletteModelManagementPage()));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'manage_palette_models',
                child: Text('Gérer les modèles'),
              ),
            ],
          ),
        IconButton(
          icon: Icon(Icons.logout_outlined),
          tooltip: "Déconnexion",
          onPressed: () async {
            await authService.signOut();
            _loggerAppBar.i("Déconnexion demandée.");
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
