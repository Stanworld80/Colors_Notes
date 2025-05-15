import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'logged_homepage.dart';
import 'note_list_page.dart';

// CORRECTION: import 'entry_page.dart'; // Supprimé car non utilisé
import 'journal_management_page.dart';

import '../providers/active_journal_provider.dart';
import '../widgets/dynamic_journal_app_bar.dart';

class MainScreen extends StatefulWidget {
  MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> _buildWidgetOptions(String? activeJournalId) {
    final options = <Widget>[LoggedHomepage()];
    if (activeJournalId != null) {
      options.add(NoteListPage(journalId: activeJournalId));
    }
    // JournalManagementPage est toujours ajouté après les options conditionnelles
    options.add(JournalManagementPage());
    return options;
  }

  void _onItemTapped(int index) {
    // CORRECTION: La variable locale 'targetWidgetIndex' a été supprimée car elle n'était pas utilisée.
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

    // Définition des items de la barre de navigation
    List<BottomNavigationBarItem> navBarItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
      // L'onglet "Notes" est conditionnel à l'existence d'un journal actif
      // L'onglet "Journals" est toujours présent
    ];

    if (journalId != null) {
      navBarItems.insert(1, const BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Notes'));
    }
    navBarItems.add(const BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Journals'));

    // Logique pour déterminer quel widget afficher en fonction de _selectedIndex et de l'état de journalId
    int bodyIndexToShow = _selectedIndex;

    if (journalId == null) {
      // Pas de journal actif
      // Les options sont: Accueil (0), Journals (1)
      // _selectedIndex vient du tap sur navBarItems qui sont Accueil (0), Journals (1 ou 2 selon construction)
      if (_selectedIndex == 0) {
        // Accueil
        bodyIndexToShow = 0; // LoggedHomepage
      } else {
        // Journals (tappé à l'index 1 de navBarItems si journalId == null)
        bodyIndexToShow = 1; // JournalManagementPage
      }
    } else {
      // Journal actif existe
      // Les options sont: Accueil (0), Notes (1), Journals (2)
      // _selectedIndex vient du tap sur navBarItems qui sont Accueil (0), Notes (1), Journals (2)
      // bodyIndexToShow est déjà égal à _selectedIndex, ce qui est correct.
    }

    // S'assurer que bodyIndexToShow est dans les limites de currentWidgetOptions
    if (bodyIndexToShow >= currentWidgetOptions.length) {
      bodyIndexToShow = 0; // Fallback sûr, bien que la logique ci-dessus devrait l'empêcher
    }

    return Scaffold(
      appBar: DynamicJournalAppBar(),
      body: Center(child: currentWidgetOptions[bodyIndexToShow]),
      bottomNavigationBar: BottomNavigationBar(items: navBarItems, currentIndex: _selectedIndex, type: BottomNavigationBarType.fixed, onTap: _onItemTapped),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Si vous avez un FAB
    );
  }
}
