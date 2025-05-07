import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'logged_homepage.dart';
import 'note_list_page.dart';
import 'entry_page.dart';
import 'journal_management_page.dart';
import 'palette_model_management_page.dart';

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
    final options = <Widget>[
      LoggedHomepage(),
    ];
    if (activeJournalId != null) {
      options.add(NoteListPage(journalId: activeJournalId));
    }
    return options;
  }

  void _onItemTapped(int index) {
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
    final currentOptions = _buildWidgetOptions(activeJournalNotifier.activeJournalId);

    if (index >= currentOptions.length) {
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
      return;
    }

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

    int effectiveSelectedIndex = _selectedIndex;
    if (effectiveSelectedIndex >= currentWidgetOptions.length) {
      effectiveSelectedIndex = 0;
    }

    List<BottomNavigationBarItem> navBarItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Accueil',
      ),
    ];

    if (journalId != null) {
      navBarItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'Notes',
        ),
      );
    }

    Widget? floatingActionButton;
    if (journalId != null && (effectiveSelectedIndex == 0 || (effectiveSelectedIndex == 1 && currentWidgetOptions.length > 1) )) {
      floatingActionButton = FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryPage(journalId: journalId),
            ),
          );
        },
        child: Icon(Icons.add_comment_outlined),
        tooltip: 'Ajouter une note',
      );
    }


    return Scaffold(
      appBar: DynamicJournalAppBar(),
      body: Center(
        child: currentWidgetOptions[effectiveSelectedIndex],
      ),
      bottomNavigationBar: navBarItems.length > 1 ? BottomNavigationBar(
        items: navBarItems,
        currentIndex: effectiveSelectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ) : null,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
