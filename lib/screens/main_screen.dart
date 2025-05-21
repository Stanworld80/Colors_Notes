// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:colors_notes/l10n/app_localizations.dart'; // AJOUTÉ

import 'logged_homepage.dart';
import 'note_list_page.dart';
import 'journal_management_page.dart';

import '../providers/active_journal_provider.dart';
import '../widgets/dynamic_journal_app_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> _buildWidgetOptions(String? activeJournalId) {
    final options = <Widget>[const LoggedHomepage()];
    if (activeJournalId != null) {
      options.add(NoteListPage(journalId: activeJournalId));
    }
    options.add(const JournalManagementPage()); // Modifié pour être const
    return options;
  }

  void _onItemTapped(int index) {
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
    final l10n = AppLocalizations.of(context)!;

    final List<Widget> currentWidgetOptions = _buildWidgetOptions(journalId);

    List<BottomNavigationBarItem> navBarItems = [
      BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: l10n.bottomNavHome), // MODIFIÉ
    ];

    if (journalId != null) {
      navBarItems.insert(1, BottomNavigationBarItem(icon: const Icon(Icons.list_alt_outlined), activeIcon: const Icon(Icons.list_alt), label: l10n.bottomNavNotes)); // MODIFIÉ
    }
    navBarItems.add(BottomNavigationBarItem(icon: const Icon(Icons.book_outlined), activeIcon: const Icon(Icons.book), label: l10n.bottomNavJournals)); // MODIFIÉ

    int clampedSelectedIndexForNavBar = _selectedIndex;
    if (clampedSelectedIndexForNavBar >= navBarItems.length) {
      clampedSelectedIndexForNavBar = navBarItems.length - 1;
      if (clampedSelectedIndexForNavBar < 0) {
        clampedSelectedIndexForNavBar = 0;
      }
    }

    int bodyWidgetIndex;
    if (journalId == null) {
      if (_selectedIndex == 0) {
        bodyWidgetIndex = 0;
      } else {
        bodyWidgetIndex = 1;
      }
    } else {
      bodyWidgetIndex = _selectedIndex;
    }

    if (bodyWidgetIndex >= currentWidgetOptions.length) {
      bodyWidgetIndex = currentWidgetOptions.isNotEmpty ? currentWidgetOptions.length - 1 : 0;
      if (bodyWidgetIndex < 0) bodyWidgetIndex = 0;
    }

    return Scaffold(
      appBar: const DynamicJournalAppBar(),
      body: Center(child: currentWidgetOptions[bodyWidgetIndex]),
      bottomNavigationBar: BottomNavigationBar(
        items: navBarItems,
        currentIndex: clampedSelectedIndexForNavBar,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
