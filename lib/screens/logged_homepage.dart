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
import '../models/color_data.dart';
import 'note_list_page.dart';
import 'entry_page.dart';
import 'create_journal_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0));
const _uuid = Uuid();

class LoggedHomepage extends StatelessWidget {
  LoggedHomepage({Key? key}) : super(key: key);

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (user?.displayName != null && user!.displayName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    'Bienvenue, ${user.displayName}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    'Bienvenue !',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (activeJournalNotifier.isLoading)
                Expanded(child: Center(child: CircularProgressIndicator()))
              else if (activeJournal != null && currentUserId != null) ...[

                Expanded(
                  child: activeJournal.palette.colors.isEmpty
                      ? Center(child: Text("La palette de ce journal est vide.\nModifiez le journal pour ajouter des couleurs.", textAlign: TextAlign.center,))
                      : GridView.builder(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      crossAxisSpacing: 10.0,
                      mainAxisSpacing: 10.0,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: activeJournal.palette.colors.length,
                    itemBuilder: (context, index) {
                      final colorData = activeJournal.palette.colors[index];
                      final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

                      return ElevatedButton(
                        onPressed: () {
                          // Naviguer vers EntryPage en passant l'ID du journal et l'ID de la couleur
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EntryPage(
                                journalId: activeJournal.id,
                                // Passer l'ID de la couleur pour présélection
                                initialPaletteElementId: colorData.paletteElementId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorData.color,
                          foregroundColor: textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsets.zero,
                          elevation: 4.0,
                        ),
                        child: Center(
                          child: Text(
                            colorData.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else if (activeJournalNotifier.errorMessage != null) ... [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    ],
                  ),
                )
              ] else ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
