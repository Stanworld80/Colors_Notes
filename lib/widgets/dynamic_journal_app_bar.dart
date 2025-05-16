import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../screens/journal_management_page.dart';
import '../screens/palette_model_management_page.dart';
import '../screens/unified_palette_editor_page.dart';
import '../screens/about_page.dart';
import '../screens/colors_notes_license_page.dart'; // Custom license page

/// Logger instance for this AppBar widget.
final _loggerAppBar = Logger(printer: PrettyPrinter(methodCount: 0));

/// A dynamic AppBar that displays the active journal's name as its title
/// and provides actions relevant to the current authentication and journal state.
///
/// The title can change based on whether a journal is active, loading, or if there's an error.
/// If journals exist, the title becomes a [PopupMenuButton] to switch between them.
/// Actions include editing the active journal's palette and a "more options" menu
/// for navigation to management pages, about, license, and sign-out.
class DynamicJournalAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// The default text to display as the title if no other specific title is determined.
  final String defaultTitleText;

  /// Creates an instance of [DynamicJournalAppBar].
  ///
  /// [defaultTitleText] defaults to "Colors & Notes".
  const DynamicJournalAppBar({super.key, this.defaultTitleText = "Colors & Notes"});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    // Listen to ActiveJournalNotifier to rebuild the AppBar when the active journal changes.
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final String? currentUserId = authService.currentUser?.uid;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;

    // Determine the display title based on the current state.
    String displayTitle = defaultTitleText;
    if (activeJournalNotifier.isLoading) {
      displayTitle = "Chargement..."; // UI Text in French: "Loading..."
    } else if (activeJournal != null) {
      displayTitle = activeJournal.name;
    } else if (activeJournalNotifier.errorMessage != null) {
      displayTitle = "Erreur"; // UI Text in French: "Error"
    } else if (currentUserId != null && activeJournalNotifier.activeJournalId == null) {
      // User is logged in but no journal is active (e.g., after deleting all journals or first login if default creation failed)
      displayTitle = "Choisir un journal"; // UI Text in French: "Choose a journal"
    }

    return AppBar(
      // The title part of the AppBar.
      // If the user is not logged in, it's a simple Text widget.
      // If logged in, it becomes a StreamBuilder to potentially show a journal switcher.
      title: currentUserId == null
          ? Text(displayTitle)
          : StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          // If no journals exist or data is not yet available, display a simple title.
          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.book_outlined, size: 20),
                const SizedBox(width: 8),
                Text(displayTitle, style: const TextStyle(fontSize: 18)),
              ],
            );
          }

          final journals = snapshot.data!;
          // If journals exist, display the title as a PopupMenuButton to switch journals.
          return PopupMenuButton<String>(
            tooltip: "Changer de journal", // UI Text in French: "Change journal"
            onSelected: (String journalId) {
              if (journalId.isNotEmpty) {
                activeJournalNotifier.setActiveJournal(journalId, currentUserId);
                _loggerAppBar.i("Journal actif changé via Titre AppBar: $journalId");
              }
            },
            itemBuilder: (BuildContext context) {
              // Create a list of PopupMenuItems for each journal.
              List<PopupMenuItem<String>> journalItems = journals.map((Journal journal) {
                return PopupMenuItem<String>(
                  value: journal.id,
                  child: Text(
                    journal.name,
                    style: TextStyle(
                      fontWeight: activeJournalNotifier.activeJournalId == journal.id
                          ? FontWeight.bold // Highlight the active journal
                          : FontWeight.normal,
                      color: activeJournalNotifier.activeJournalId == journal.id
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                );
              }).toList();
              return journalItems;
            },
            // The child of PopupMenuButton, which is the visible part of the title.
            child: Row(
              mainAxisSize: MainAxisSize.min, // Keep the row compact.
              children: [
                const Icon(Icons.book_outlined, size: 20),
                const SizedBox(width: 8),
                Flexible( // Allow title to take available space and ellipsis if too long.
                    child: Text(displayTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18))
                ),
                const Icon(Icons.arrow_drop_down, size: 24), // Dropdown indicator.
              ],
            ),
          );
        },
      ),
      centerTitle: true, // Center the title.
      actions: <Widget>[
        // Action button to edit the palette of the active journal.
        // Only shown if a journal is active.
        if (activeJournal != null)
          IconButton(
            icon: const Icon(Icons.palette_rounded),
            tooltip: "Modifier la palette de '${activeJournal.name}'", // UI Text in French
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UnifiedPaletteEditorPage(
                    journalToUpdatePaletteFor: activeJournal,
                  ),
                ),
              );
            },
          ),

        // "More options" menu, shown if a user is logged in.
        if (currentUserId != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_outlined),
            tooltip: "Options", // UI Text in French
            onSelected: (value) {
              // Handle navigation or actions based on the selected menu item value.
              if (value == 'manage_journals') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => JournalManagementPage()));
              } else if (value == 'manage_palette_models') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaletteModelManagementPage()));
              } else if (value == 'about') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
              } else if (value == 'license') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ColorsNotesLicensePage()));
              } else if (value == 'sign_out') {
                authService.signOut().then((_) {
                  _loggerAppBar.i("Déconnexion demandée."); // Log message in French
                  // AuthGate will handle navigation to the sign-in page.
                }).catchError((e) {
                  _loggerAppBar.e("Erreur déconnexion: $e"); // Log message in French
                  if(context.mounted){
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur lors de la déconnexion: $e")) // UI Text in French
                    );
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Menu items for journal and palette model management.
              const PopupMenuItem<String>(
                value: 'manage_journals',
                child: ListTile(
                  leading: Icon(Icons.collections_bookmark_outlined),
                  title: Text('Journaux'), // UI Text in French
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage_palette_models',
                child: ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Modèles de palette'), // UI Text in French
                ),
              ),
              const PopupMenuDivider(), // Visual separator.
              // Menu items for About and License pages.
              const PopupMenuItem<String>(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('À Propos'), // UI Text in French
                ),
              ),
              const PopupMenuItem<String>(
                value: 'license',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Licence'), // UI Text in French
                ),
              ),
              const PopupMenuDivider(), // Visual separator.
              // Sign out option.
              const PopupMenuItem<String>(
                value: 'sign_out',
                child: ListTile(
                  leading: Icon(Icons.logout_outlined),
                  title: Text('Déconnexion'), // UI Text in French
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Defines the preferred size of the AppBar.
  ///
  /// This is required when implementing [PreferredSizeWidget].
  /// It uses the default toolbar height.
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
