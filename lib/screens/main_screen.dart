import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'logged_homepage.dart';
import 'note_list_page.dart';
import 'entry_page.dart';
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

    options.add(JournalManagementPage());
    return options;
  }

  void _onItemTapped(int index) {
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context, listen: false);
    final bool notesTabExists = activeJournalNotifier.activeJournalId != null;

    int targetWidgetIndex = index;
    if (!notesTabExists && index == 1) {
      targetWidgetIndex = 1;
    } else if (notesTabExists && index == 2) {
      targetWidgetIndex = 2;
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

    List<BottomNavigationBarItem> navBarItems = [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
      BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Notes'),
      BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Journals'),
    ];

    int bodyIndexToShow = _selectedIndex;
    if (journalId == null && _selectedIndex > 0) {
      bodyIndexToShow = 1;
    } else if (journalId != null && _selectedIndex == 2) {
      bodyIndexToShow = 2;
    }

    if (bodyIndexToShow >= currentWidgetOptions.length) {
      bodyIndexToShow = 0;
    }

    return Scaffold(
      appBar: DynamicJournalAppBar(),
      body: Center(child: currentWidgetOptions[bodyIndexToShow]),
      bottomNavigationBar: BottomNavigationBar(items: navBarItems, currentIndex: _selectedIndex, type: BottomNavigationBarType.fixed, onTap: _onItemTapped),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
