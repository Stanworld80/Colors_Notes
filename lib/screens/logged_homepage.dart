import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/journal.dart';
import '../models/note.dart';
import 'note_list_page.dart';
import 'entry_page.dart';
import 'create_journal_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0));
const _uuid = Uuid();

class LoggedHomepage extends StatelessWidget {
  LoggedHomepage({Key? key}) : super(key: key);

  Future<void> _addQuickNote(BuildContext context, Journal activeJournal, String userId) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    if (activeJournal.palette.colors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("La palette de ce journal est vide. Ajoutez des couleurs d'abord.")),
      );
      return;
    }

    final defaultColorElementId = activeJournal.palette.colors.first.paletteElementId;

    final Note quickNote = Note(
      id: _uuid.v4(),
      journalId: activeJournal.id,
      userId: userId,
      content: "Note rapide du ${DateFormat('dd/MM HH:mm', 'fr_FR').format(DateTime.now())}",
      paletteElementId: defaultColorElementId,
      eventTimestamp: Timestamp.now(),
      createdAt: Timestamp.now(),
      lastUpdatedAt: Timestamp.now(),
    );

    try {
      await firestoreService.createNote(quickNote);
      _loggerPage.i("Note rapide ajoutée au journal ${activeJournal.name}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Note rapide ajoutée !")),
        );
      }
    } catch (e) {
      _loggerPage.e("Erreur ajout note rapide: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur ajout note rapide: ${e.toString()}")),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);

    final user = authService.currentUser;
    final Journal? activeJournal = activeJournalNotifier.activeJournal;
    final String? currentUserId = user?.uid;


    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (user?.displayName != null && user!.displayName!.isNotEmpty)
                Text(
                  'Bienvenue, ${user.displayName}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  'Bienvenue !',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 20),
              if (activeJournalNotifier.isLoading)
                CircularProgressIndicator()
              else if (activeJournal != null && currentUserId != null) ...[
                Text(
                  'Journal Actif: ${activeJournal.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Palette: ${activeJournal.palette.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.center,
                  children: activeJournal.palette.colors.map((colorData) {
                    return Chip(
                      avatar: CircleAvatar(backgroundColor: colorData.color, radius: 10),
                      label: Text(colorData.title, style: TextStyle(fontSize: 12)),
                      backgroundColor: colorData.color.withOpacity(0.1),
                    );
                  }).toList(),
                ),
                SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: Icon(Icons.list_alt_outlined),
                  label: Text('Voir les notes de "${activeJournal.name}"'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteListPage(journalId: activeJournal.id),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(minimumSize: Size(200, 45)),
                ),
                SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: Icon(Icons.flash_on_outlined),
                  label: Text('Ajouter une "Note Rapide"'),
                  onPressed: () => _addQuickNote(context, activeJournal, currentUserId),
                  style: OutlinedButton.styleFrom(minimumSize: Size(200, 45)),
                ),

              ] else if (activeJournalNotifier.errorMessage != null) ... [
                Icon(Icons.error_outline, color: Colors.red, size: 50),
                SizedBox(height: 10),
                Text(
                  "Erreur de chargement du journal:",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                Text(
                  activeJournalNotifier.errorMessage!,
                  style: TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateJournalPage()),
                    );
                  },
                  child: Text('Créer un nouveau journal'),
                ),

              ] else ...[
                Icon(Icons.menu_book_outlined, size: 50, color: Theme.of(context).colorScheme.primary),
                SizedBox(height: 10),
                Text(
                  'Aucun journal actif.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'Sélectionnez un journal existant ou créez-en un nouveau pour commencer.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateJournalPage()),
                    );
                  },
                  child: Text('Créer ou choisir un journal'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(200, 45)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
