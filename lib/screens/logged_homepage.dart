import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../models/journal.dart';

import 'entry_page.dart';
import 'create_journal_page.dart';

/// The main homepage displayed when a user is logged in.
///
/// This page greets the user and displays the color palette of their currently
/// active journal. Each color in the palette is a button that navigates to
/// the [EntryPage] to create a new note associated with that color.
///
/// If no journal is active, or if the active journal's palette is empty,
/// appropriate messages and actions (like creating a new journal) are shown.
class LoggedHomepage extends StatelessWidget {
  /// Creates an instance of [LoggedHomepage].
  const LoggedHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Listen to ActiveJournalNotifier to rebuild when the active journal or its loading state changes.
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);

    final user = authService.currentUser;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;
    final String? currentUserId = user?.uid; // Used for validating active journal context if needed

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Welcome message for the user.
              if (user?.displayName != null && user!.displayName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text('Bienvenue, ${user.displayName}!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), // UI Text in French
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text('Bienvenue !', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), // UI Text in French
                ),

              // Display loading indicator, color palette, or messages based on state.
              if (activeJournalNotifier.isLoading && activeJournal == null)
                // Show loading indicator if the active journal is being loaded.
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (activeJournal != null && currentUserId != null) ...[
                // If an active journal is loaded.
                Expanded(
                  child:
                      activeJournal.palette.colors.isEmpty
                          // If the active journal's palette is empty, show a message.
                          ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Text(
                                "La palette de ce journal est vide.\nModifiez le journal pour ajouter des couleurs, ou choisissez un autre journal.", // UI Text in French
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          )
                          // If the palette has colors, display them in a grid.
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              // Determine the number of columns in the grid based on screen width.
                              int gridCrossAxisCount;
                              if (screenWidth < 400) {
                                gridCrossAxisCount = 4;
                              } else if (screenWidth < 600) {
                                gridCrossAxisCount = 5;
                              } else if (screenWidth < 800) {
                                gridCrossAxisCount = 6;
                              } else if (screenWidth < 1000) {
                                gridCrossAxisCount = 7;
                              } else if (screenWidth < 1200) {
                                gridCrossAxisCount = 8;
                              } else {
                                gridCrossAxisCount = 9;
                              }

                              // Adjust font size for color titles based on grid density.
                              double fontSize = 12.0;
                              if (gridCrossAxisCount > 6) fontSize = 10.0;
                              if (gridCrossAxisCount > 7) fontSize = 9.0;

                              return GridView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCrossAxisCount,
                                  crossAxisSpacing: 6.0,
                                  mainAxisSpacing: 6.0,
                                  childAspectRatio: 1.1, // Adjust aspect ratio for button appearance
                                ),
                                itemCount: activeJournal.palette.colors.length,
                                itemBuilder: (context, index) {
                                  final colorData = activeJournal.palette.colors[index];
                                  // Determine text color based on luminance of the background color for better contrast.
                                  final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

                                  return ElevatedButton(
                                    onPressed: () {
                                      // Navigate to EntryPage to create a new note with the selected color.
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: activeJournal.id, initialPaletteElementId: colorData.paletteElementId)));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorData.color,
                                      foregroundColor: textColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                      padding: const EdgeInsets.all(4),
                                      // Minimal padding
                                      elevation: 2.0,
                                    ),
                                    child: Center(
                                      child: Text(
                                        colorData.title,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: fontSize),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                ),
              ] else if (activeJournalNotifier.errorMessage != null) ...[
                // If there was an error loading the active journal.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text("Erreur de chargement du journal:", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red), textAlign: TextAlign.center), // UI Text in French
                      Text(activeJournalNotifier.errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to CreateJournalPage to allow user to create a new journal.
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJournalPage()));
                        },
                        child: const Text('Créer un nouveau journal'), // UI Text in French
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // If no active journal is selected and no error occurred (e.g., first launch or after logout).
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 50, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text('Aucun journal actif.', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), // UI Text in French
                      const SizedBox(height: 5),
                      Text(
                        'Sélectionnez un journal existant ou créez-en un nouveau pour commencer.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ), // UI Text in French
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to CreateJournalPage (or a journal selection page if that exists).
                          // For now, assuming direct navigation to create/select via drawer or another page.
                          // This button directly goes to CreateJournalPage.
                          // A better UX might be to open the drawer or navigate to JournalManagementPage.
                          // For simplicity, this example navigates to CreateJournalPage.
                          // Consider changing this to open the drawer: Scaffold.of(context).openDrawer();
                          // or navigate to JournalManagementPage.
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJournalPage()));
                        },
                        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                        child: const Text('Choisir ou créer un journal'), // UI Text in French
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
