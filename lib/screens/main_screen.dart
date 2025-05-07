import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'logged_homepage.dart';
import 'note_list_page.dart';
import 'entry_page.dart';
import 'journal_management_page.dart'; // Importer la page de gestion des journaux
// import 'palette_model_management_page.dart'; // Pas directement dans la bottom bar

import '../providers/active_journal_provider.dart';
import '../widgets/dynamic_journal_app_bar.dart';

class MainScreen extends StatefulWidget {
  MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // La liste des widgets principaux affichés dans le corps
  // en fonction de l'onglet sélectionné
  List<Widget> _buildWidgetOptions(String? activeJournalId) {
    final options = <Widget>[
      LoggedHomepage(), // Index 0: Accueil
    ];
    if (activeJournalId != null) {
      // Index 1: Notes (seulement si un journal est actif)
      options.add(NoteListPage(journalId: activeJournalId));
    }
    // Index 2 (ou 1 si pas de journal actif): Gestion des Journaux
    options.add(JournalManagementPage());
    return options;
  }

  void _onItemTapped(int index) {
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
    final bool notesTabExists = activeJournalNotifier.activeJournalId != null;

    // Logique pour mapper l'index de la barre de navigation à l'index de la liste _buildWidgetOptions
    int targetWidgetIndex = index;
    if (!notesTabExists && index == 1) {
      // Si l'onglet Notes n'existe pas et qu'on clique sur l'index 1 (qui serait Journals)
      targetWidgetIndex = 1; // L'index 1 dans _buildWidgetOptions correspond à JournalManagementPage
    } else if (notesTabExists && index == 2) {
      // Si l'onglet Notes existe et qu'on clique sur l'index 2 (Journals)
      targetWidgetIndex = 2; // L'index 2 dans _buildWidgetOptions correspond à JournalManagementPage
    }
    // Si on clique sur Notes (index 1) et qu'il existe, targetWidgetIndex est déjà 1.
    // Si on clique sur Accueil (index 0), targetWidgetIndex est déjà 0.


    if (mounted) {
      setState(() {
        _selectedIndex = index; // L'index sélectionné dans la barre reste celui cliqué
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? journalId = activeJournalNotifier.activeJournalId;
    final List<Widget> currentWidgetOptions = _buildWidgetOptions(journalId);

    // Définir les items de la BottomNavigationBar
    // Ils sont toujours 3, mais l'onglet Notes est conceptuellement
    // lié à l'index 1 du widget body *seulement si* journalId n'est pas null.
    List<BottomNavigationBarItem> navBarItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined), // Icône Accueil originale
        activeIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.list_alt_outlined), // Icône Notes originale
        activeIcon: Icon(Icons.list_alt),
        label: 'Notes',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.book_outlined), // Icône Journals originale
        activeIcon: Icon(Icons.book),
        label: 'Journals',
      ),
    ];

    // Déterminer quel widget afficher en fonction de l'index sélectionné
    // et de la présence de l'onglet Notes
    int bodyIndexToShow = _selectedIndex;
    if (journalId == null && _selectedIndex > 0) {
      // Si pas de journal actif, l'index 1 (Notes) n'existe pas dans le body,
      // donc l'index 1 de la barre (Notes) doit afficher l'index 1 du body (Journals)
      // et l'index 2 de la barre (Journals) doit aussi afficher l'index 1 du body (Journals).
      // Cependant, si on clique sur "Notes" (index 1), on veut afficher Journals (index 1 du body)
      // Si on clique sur "Journals" (index 2), on veut afficher Journals (index 1 du body)
      bodyIndexToShow = 1; // Toujours l'index 1 du body si pas de journal actif et index > 0
    } else if (journalId != null && _selectedIndex == 2) {
      // Si journal actif et on clique sur Journals (index 2), on affiche l'index 2 du body (Journals)
      bodyIndexToShow = 2;
    }
    // Si journal actif et on clique sur Notes (index 1), on affiche l'index 1 du body (Notes) -> bodyIndexToShow = 1
    // Si on clique sur Accueil (index 0), on affiche l'index 0 du body (Accueil) -> bodyIndexToShow = 0

    // S'assurer que bodyIndexToShow est valide
    if (bodyIndexToShow >= currentWidgetOptions.length) {
      bodyIndexToShow = 0; // Fallback sécurité
    }

    return Scaffold(
      appBar: DynamicJournalAppBar(),
      body: Center(
        child: currentWidgetOptions[bodyIndexToShow],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: navBarItems,
        currentIndex: _selectedIndex, // L'index visuel de la barre
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
