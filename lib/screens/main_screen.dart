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
  final int? initialIndex;
  const MainScreen({super.key, this.initialIndex});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }


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

    );
  }
}
