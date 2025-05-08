import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Pas utilisé directement
// import 'package:uuid/uuid.dart'; // Pas utilisé directement
// import 'package:intl/intl.dart'; // Pas utilisé directement

import '../providers/active_journal_provider.dart';
import '../services/auth_service.dart';
// import '../services/firestore_service.dart'; // Pas utilisé directement
import '../models/journal.dart';
// import '../models/note.dart'; // Pas utilisé directement
import '../models/color_data.dart';
// import 'note_list_page.dart'; // Pas utilisé directement
import 'entry_page.dart';
import 'create_journal_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0, printTime: false));
// const _uuid = Uuid(); // Pas utilisé

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
                      : LayoutBuilder( // Utiliser LayoutBuilder pour obtenir la largeur disponible
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;
                        // Logique similaire à NoteListPage pour déterminer le nombre de colonnes
                        int gridCrossAxisCount;
                        if (screenWidth < 400) gridCrossAxisCount = 4; // Commencer un peu plus dense
                        else if (screenWidth < 600) gridCrossAxisCount = 5;
                        else if (screenWidth < 800) gridCrossAxisCount = 6;
                        else if (screenWidth < 1000) gridCrossAxisCount = 7;
                        else if (screenWidth < 1200) gridCrossAxisCount = 8;
                        else gridCrossAxisCount = 9; // Jusqu'à 9 comme demandé

                        // Ajuster la taille de la police en fonction de la densité
                        double fontSize = 12.0;
                        if (gridCrossAxisCount > 6) fontSize = 10.0;
                        if (gridCrossAxisCount > 7) fontSize = 9.0;


                        return GridView.builder(
                          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCrossAxisCount, // Nombre de colonnes dynamique
                            crossAxisSpacing: 6.0, // Espacement réduit
                            mainAxisSpacing: 6.0,  // Espacement réduit
                            childAspectRatio: 1.1, // Ratio similaire à NoteListPage (ajuster si besoin)
                          ),
                          itemCount: activeJournal.palette.colors.length,
                          itemBuilder: (context, index) {
                            final colorData = activeJournal.palette.colors[index];
                            final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

                            return ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EntryPage(
                                      journalId: activeJournal.id,
                                      initialPaletteElementId: colorData.paletteElementId,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorData.color,
                                foregroundColor: textColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0), // Rayon plus petit
                                ),
                                padding: EdgeInsets.all(4), // Padding réduit
                                elevation: 2.0, // Élévation réduite
                              ),
                              child: Center(
                                child: Text(
                                  colorData.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: fontSize), // Taille de police ajustée
                                  overflow: TextOverflow.ellipsis, // Gérer le dépassement
                                  maxLines: 2, // Permettre 2 lignes si nécessaire
                                ),
                              ),
                            );
                          },
                        );
                      }
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
                          // Naviguer vers la page de gestion pour choisir ou créer
                          Navigator.pushNamed(context, '/main').then((_) {
                            // Naviguer vers l'onglet de gestion des journaux (si MainScreen gère cela)
                            // Ou directement vers CreateJournalPage si c'est plus simple
                            // Exemple simple:
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CreateJournalPage()));
                          });
                        },
                        child: Text('Choisir ou créer un journal'), // Texte modifié
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
