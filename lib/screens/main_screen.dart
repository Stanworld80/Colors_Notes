import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'logged_homepage.dart';
import 'note_list_page.dart';
import 'journal_management_page.dart';

import '../providers/active_journal_provider.dart';
import '../widgets/dynamic_journal_app_bar.dart';

/// The main screen of the application after the user is authenticated.
///
/// This screen uses a [BottomNavigationBar] to switch between different
/// primary sections of the app:
/// - [LoggedHomepage]: Displays the active journal's palette for quick note creation.
/// - [NoteListPage]: Lists notes for the active journal (only available if a journal is active).
/// - [JournalManagementPage]: Allows users to manage their journals.
///
/// The [DynamicJournalAppBar] is used as the AppBar for this screen.
class MainScreen extends StatefulWidget {
  /// Creates an instance of [MainScreen].
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

/// The state for the [MainScreen].
///
/// Manages the selected index of the [BottomNavigationBar] and dynamically
/// builds the list of available screen options based on whether a journal is active.
class _MainScreenState extends State<MainScreen> {
  /// The currently selected index in the [BottomNavigationBar].
  int _selectedIndex = 0;

  /// Builds the list of widget options for the [BottomNavigationBar] based on
  /// the presence of an active journal.
  ///
  /// [activeJournalId] The ID of the currently active journal. If null,
  /// the 'Notes' tab ([NoteListPage]) is not included.
  /// Returns a list of [Widget]s to be displayed.
  List<Widget> _buildWidgetOptions(String? activeJournalId) {
    final options = <Widget>[const LoggedHomepage()]; // Index 0: Homepage
    if (activeJournalId != null) {
      options.add(NoteListPage(journalId: activeJournalId)); // Index 1 (if active): Notes
    }
    // JournalManagementPage is always added. Its index will be 1 if no active journal, or 2 if active.
    options.add(JournalManagementPage());
    return options;
  }

  /// Handles tap events on the [BottomNavigationBar] items.
  ///
  /// Updates the [_selectedIndex] to navigate to the corresponding screen.
  /// The logic to determine the actual widget to display based on `_selectedIndex`
  /// and `activeJournalId` is handled in the `build` method.
  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to ActiveJournalNotifier to rebuild when activeJournalId changes.
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? journalId = activeJournalNotifier.activeJournalId;
    // Get the current list of screen widgets based on active journal state.
    final List<Widget> currentWidgetOptions = _buildWidgetOptions(journalId);

    // Dynamically define BottomNavigationBar items.
    List<BottomNavigationBarItem> navBarItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
      // The 'Notes' tab is conditionally added if a journal is active.
      // The 'Journals' tab is always present.
    ];

    if (journalId != null) {
      // Insert 'Notes' tab at index 1 if a journal is active.
      navBarItems.insert(1, const BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Notes'));
    }
    // Add 'Journals' tab. Its actual index in navBarItems depends on whether 'Notes' was added.
    navBarItems.add(const BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Journaux'));

    // Determine the correct index for `currentWidgetOptions` based on `_selectedIndex`
    // and whether the 'Notes' tab is currently present.
    int bodyIndexToShow = _selectedIndex;

    // Safety check: Ensure bodyIndexToShow is within the bounds of currentWidgetOptions.
    // This should ideally not be necessary if the logic above is correct.
    if (bodyIndexToShow >= currentWidgetOptions.length) {
      bodyIndexToShow = 0; // Fallback to the first screen (LoggedHomepage).
    }

    return Scaffold(
      appBar: const DynamicJournalAppBar(), // Custom AppBar that might change based on context.
      body: Center(child: currentWidgetOptions[bodyIndexToShow]),
      bottomNavigationBar: BottomNavigationBar(
        items: navBarItems,
        currentIndex: _selectedIndex, // The index of the currently selected tab in navBarItems.
        type: BottomNavigationBarType.fixed, // Ensures all items are visible and have labels.
        onTap: _onItemTapped, // Callback for when a tab is tapped.
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Example if a FAB were used.
    );
  }
}
