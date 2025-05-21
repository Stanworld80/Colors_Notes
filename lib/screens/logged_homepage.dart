// lib/screens/logged_homepage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:colors_notes/l10n/app_localizations.dart'; // AJOUTÉ

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
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
    final l10n = AppLocalizations.of(context)!; // AJOUTÉ

    final user = authService.currentUser;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;
    final String? currentUserId = user?.uid;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (user?.displayName != null && user!.displayName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(l10n.welcomeUser(user.displayName!), style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), // MODIFIÉ
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(l10n.welcomeGuest, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), // MODIFIÉ
                ),

              if (activeJournalNotifier.isLoading && activeJournal == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (activeJournal != null && currentUserId != null) ...[
                Expanded(
                  child:
                  activeJournal.palette.colors.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        l10n.paletteIsEmptyMessage, // MODIFIÉ
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                      : LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
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

                      double fontSize = 12.0;
                      if (gridCrossAxisCount > 6) fontSize = 10.0;
                      if (gridCrossAxisCount > 7) fontSize = 9.0;

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCrossAxisCount,
                          crossAxisSpacing: 6.0,
                          mainAxisSpacing: 6.0,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: activeJournal.palette.colors.length,
                        itemBuilder: (context, index) {
                          final colorData = activeJournal.palette.colors[index];
                          final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

                          return ElevatedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => EntryPage(journalId: activeJournal.id, initialPaletteElementId: colorData.paletteElementId)));
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorData.color,
                              foregroundColor: textColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              padding: const EdgeInsets.all(4),
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
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text(l10n.errorLoadingJournal, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red), textAlign: TextAlign.center), // MODIFIÉ
                      Text(activeJournalNotifier.errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJournalPage()));
                        },
                        child: Text(l10n.createNewJournalButton), // MODIFIÉ
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 50, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text(l10n.noActiveJournalTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), // MODIFIÉ
                      const SizedBox(height: 5),
                      Text(
                        l10n.noActiveJournalMessage, // MODIFIÉ
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateJournalPage()));
                        },
                        style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                        child: Text(l10n.chooseOrCreateJournalButton), // MODIFIÉ
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
