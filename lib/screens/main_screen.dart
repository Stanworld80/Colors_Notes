import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'logged_homepage.dart';
import 'note_list_page.dart';

// CORRECTION: import 'entry_page.dart'; // Supprimé car non utilisé
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
  /// This represents the user's intended tab selection.
  int _selectedIndex = 0;

  /// Builds the list of widget options for the body of the Scaffold,
  /// corresponding to the tabs in the [BottomNavigationBar].
  ///
  /// [activeJournalId] The ID of the currently active journal. If null,
  /// the 'Notes' tab ([NoteListPage]) is not included.
  /// Returns a list of [Widget]s to be displayed.
  List<Widget> _buildWidgetOptions(String? activeJournalId) {
    final options = <Widget>[const LoggedHomepage()]; // Index 0: Homepage
    if (activeJournalId != null) {
      // Index 1 (if activeJournalId is not null): Notes
      options.add(NoteListPage(journalId: activeJournalId));
    }
    // JournalManagementPage is always added.
    // Its index in this list will be 1 if no active journal, or 2 if an active journal exists.
    options.add(JournalManagementPage());
    return options;
  }

  /// Handles tap events on the [BottomNavigationBar] items.
  ///
  /// Updates the [_selectedIndex] to navigate to the corresponding screen.
  /// The [index] provided is based on the `items` list of the `BottomNavigationBar`
  /// at the time of the tap.
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

    // Dynamically build the list of screen widgets based on active journal state.
    final List<Widget> currentWidgetOptions = _buildWidgetOptions(journalId);

    // Dynamically define BottomNavigationBar items.
    List<BottomNavigationBarItem> navBarItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'), // UI Text in French
    ];

    if (journalId != null) {
      // Insert 'Notes' tab at index 1 if a journal is active.
      navBarItems.insert(1, const BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Notes')); // UI Text in French
    }
    // Add 'Journals' tab. Its actual index in navBarItems depends on whether 'Notes' was added.
    navBarItems.add(const BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book), label: 'Journaux')); // UI Text in French

    // Determine the actual index to use for BottomNavigationBar's currentIndex.
    // This must be clamped to be within the bounds of the current navBarItems list.
    int clampedSelectedIndexForNavBar = _selectedIndex;
    if (clampedSelectedIndexForNavBar >= navBarItems.length) {
      clampedSelectedIndexForNavBar = navBarItems.length - 1;
      if (clampedSelectedIndexForNavBar < 0) { // Should not happen if navBarItems always has items
        clampedSelectedIndexForNavBar = 0;
      }
    }

    // Determine the index for the body widget from currentWidgetOptions.
    // This logic maps the _selectedIndex (which reflects the user's last *intended* tab)
    // to the correct widget in currentWidgetOptions, considering that the "Notes" tab is conditional.
    int bodyWidgetIndex;
    if (journalId == null) {
      // No active journal.
      // navBarItems are: [Accueil (0), Journaux (1)]
      // currentWidgetOptions are: [LoggedHomepage (0), JournalManagementPage (1)]
      // If _selectedIndex was 0 (Accueil), show LoggedHomepage (index 0).
      // If _selectedIndex was 1 (intended "Notes" which is gone, or "Journaux" which is now at navBarItems index 1),
      // or if _selectedIndex was 2 (intended "Journaux" from a 3-tab layout),
      // we should show the "Journaux" widget, which is at currentWidgetOptions index 1.
      if (_selectedIndex == 0) {
        bodyWidgetIndex = 0; // Corresponds to LoggedHomepage
      } else {
        // Any other _selectedIndex (1 or a stale 2) maps to the second tab available, which is "Journaux".
        bodyWidgetIndex = 1; // Corresponds to JournalManagementPage
      }
    } else {
      // Active journal exists.
      // navBarItems are: [Accueil (0), Notes (1), Journaux (2)]
      // currentWidgetOptions are: [LoggedHomepage (0), NoteListPage (1), JournalManagementPage (2)]
      // _selectedIndex (0, 1, or 2) directly maps to the widget index.
      bodyWidgetIndex = _selectedIndex;
    }

    // Final safety clamp for bodyWidgetIndex against currentWidgetOptions.
    // This ensures we don't try to access an out-of-bounds index.
    if (bodyWidgetIndex >= currentWidgetOptions.length) {
      bodyWidgetIndex = currentWidgetOptions.isNotEmpty ? currentWidgetOptions.length - 1 : 0;
      if (bodyWidgetIndex < 0) bodyWidgetIndex = 0; // Should not be reachable
    }

    return Scaffold(
      appBar: const DynamicJournalAppBar(), // Custom AppBar.
      body: Center(child: currentWidgetOptions[bodyWidgetIndex]),
      bottomNavigationBar: BottomNavigationBar(
        items: navBarItems,
        currentIndex: clampedSelectedIndexForNavBar, // Use the clamped index for the BottomNavigationBar.
        type: BottomNavigationBarType.fixed, // Ensures all items are visible and have labels.
        onTap: _onItemTapped, // Callback for when a tab is tapped.
      ),
    );
  }
}