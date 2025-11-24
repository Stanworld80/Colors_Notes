import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting.
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../providers/active_journal_provider.dart';
import '../models/journal.dart';
import 'create_journal_page.dart';
import 'edit_journal_page.dart';
import 'unified_palette_editor_page.dart';

/// Logger instance for this page.
final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: true));

/// A screen for managing the user's journals.
///
/// This page displays a list of existing journals, allowing the user to:
/// - View and select an active journal.
/// - Create a new journal.
/// - Navigate to an editing page for an existing journal.
/// - Navigate to edit the palette of an existing journal.
class JournalManagementPage extends StatelessWidget {
  /// Creates an instance of [JournalManagementPage].
  const JournalManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context); // listen: true to rebuild on active journal change
    final String? currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      _loggerPage.w("JournalManagementPage: currentUserId is null."); // Log in English
      return Scaffold(
          appBar: AppBar(title: Text(l10n.manageJournalsAppBarTitle)),
          body: Center(child: Text(l10n.userNotConnectedError)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageJournalsAppBarTitle),
      ),
      body: StreamBuilder<List<Journal>>(
        stream: firestoreService.getJournalsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _loggerPage.e("Error loading journals: ${snapshot.error}"); // Log in English
            return Center(child: Text(l10n.errorLoadingJournals(snapshot.error.toString())));
          }

          final journals = snapshot.data ?? [];
          final DateFormat dateFormat = DateFormat('dd MMM yy, HH:mm', l10n.localeName);

          Widget createJournalCard = Card(
            elevation: 3.0,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateJournalPage()),
                );
              },
              borderRadius: BorderRadius.circular(10.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      l10n.createNewJournalCardLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (journals.isEmpty) {
            return Column(
              children: [
                createJournalCard,
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.library_books_outlined, size: 50, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noExistingJournalsMessage,
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            itemCount: journals.length + 2, // +1 for create card, +1 for section header
            itemBuilder: (context, index) {
              if (index == 0) {
                return createJournalCard;
              }
              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.existingJournalsSectionTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 12, thickness: 1),
                    ],
                  ),
                );
              }

              final journalIndex = index - 2;
              final journal = journals[journalIndex];
              final bool isActive = journal.id == activeJournalNotifier.activeJournalId;

              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: isActive ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: isActive
                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  leading: Icon(
                      isActive ? Icons.menu_book_rounded : Icons.book_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28
                  ),
                  title: Text(journal.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 17)),
                  subtitle: Text(l10n.journalCreatedOnDateLabel(dateFormat.format(journal.createdAt.toDate().toLocal())), style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: l10n.editPaletteForJournalTooltip(journal.name),
                        child: IconButton(
                          icon: const Icon(Icons.palette_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UnifiedPaletteEditorPage(
                                  journalToUpdatePaletteFor: journal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Tooltip(
                        message: l10n.editNameOptionsTooltip, // This l10n key is now slightly inaccurate but fine for now.
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditJournalPage(journal: journal),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  selected: isActive,
                  onTap: () {
                    if (!isActive) {
                      activeJournalNotifier.setActiveJournal(journal.id, currentUserId);
                      _loggerPage.i("Active journal changed to: ${journal.name}"); // Log in English
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
