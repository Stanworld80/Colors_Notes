// lib/screens/main_screen.dart
// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import des autres écrans et widgets nécessaires
import 'package:colors_notes/screens/logged_homepage.dart';
// Correction de l'import pour note_list_page.dart : utilisation d'un import de package
import 'package:colors_notes/screens/note_list_page.dart';
import 'package:colors_notes/screens/entry_page.dart';
import 'package:colors_notes/screens/journal_management_page.dart';

import 'package:colors_notes/providers/active_journal_provider.dart';
import 'package:colors_notes/widgets/dynamic_journal_app_bar.dart';

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
    // JournalManagementPage est toujours ajouté, que activeJournalId soit null ou non.
    // Sa position dans la liste `options` dépendra de la présence de `NoteListPage`.
    options.add(JournalManagementPage());
    return options;
  }

  void _onItemTapped(int index) {
    // final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
    // final bool notesTabExists = activeJournalNotifier.activeJournalId != null;

    // int targetWidgetIndex = index;
    // if (!notesTabExists && index == 1) {
    //   targetWidgetIndex = 1;
    // } else if (notesTabExists && index == 2) {
    //   targetWidgetIndex = 2;
    // }

    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? journalId = activeJournalNotifier.activeJournalId;
    final List<Widget> currentWidgetOptions = _buildWidgetOptions(journalId);

    List<BottomNavigationBarItem> navBarItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.list_alt_outlined),
        activeIcon: Icon(Icons.list_alt),
        label: 'Notes',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.book_outlined),
        activeIcon: Icon(Icons.book),
        label: 'Journals',
      ),
    ];

    // Déterminer quel widget afficher en fonction de l'index sélectionné
    // et de la présence de l'onglet Notes
    int bodyIndexToShow = _selectedIndex;

    if (journalId == null) { // Pas de journal actif
      if (_selectedIndex == 1) { // Si l'utilisateur clique sur l'onglet "Notes" (qui est visuellement le 2ème)
        bodyIndexToShow = 1; // Afficher JournalManagementPage (qui est à l'index 1 de currentWidgetOptions)
      } else if (_selectedIndex == 2) { // Si l'utilisateur clique sur l'onglet "Journals" (qui est visuellement le 3ème)
        bodyIndexToShow = 1; // Afficher aussi JournalManagementPage
      }
      // Si _selectedIndex == 0 (Accueil), bodyIndexToShow reste 0.
    } else { // Un journal est actif
      // Les index de la BottomNavigationBar correspondent directement aux index de currentWidgetOptions
      // _selectedIndex 0 -> Accueil (index 0)
      // _selectedIndex 1 -> Notes (index 1)
      // _selectedIndex 2 -> Journals (index 2)
      bodyIndexToShow = _selectedIndex;
    }


    // S'assurer que bodyIndexToShow est valide pour éviter les erreurs de plage.
    if (bodyIndexToShow >= currentWidgetOptions.length) {
      bodyIndexToShow = 0; // Fallback sur le premier widget (Accueil) en cas de problème.
    }

    return Scaffold(
      appBar: DynamicJournalAppBar(),
      body: Center(
        child: currentWidgetOptions[bodyIndexToShow],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: navBarItems,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Assure que tous les labels sont visibles
        onTap: _onItemTapped,
      ),
      // Le FloatingActionButton a été retiré précédemment, donc pas de FAB ici.
    );
  }
}
