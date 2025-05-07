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
import '../models/color_data.dart'; // Import ColorData
import 'note_list_page.dart';
import 'entry_page.dart';
import 'create_journal_page.dart';

final _loggerPage = Logger(printer: PrettyPrinter(methodCount: 0));
const _uuid = Uuid();

class LoggedHomepage extends StatelessWidget {
  LoggedHomepage({Key? key}) : super(key: key);

  // Fonction pour créer une note rapide associée à une couleur spécifique
  Future<void> _addQuickNoteForColor(BuildContext context, Journal activeJournal, ColorData colorData, String userId) async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final Note quickNote = Note(
      id: _uuid.v4(),
      journalId: activeJournal.id,
      userId: userId,
      // Utiliser le titre de la couleur dans le contenu par défaut
      content: "Note rapide - ${colorData.title} (${DateFormat('dd/MM HH:mm', 'fr_FR').format(DateTime.now())})",
      paletteElementId: colorData.paletteElementId, // Utiliser l'ID de la couleur cliquée
      eventTimestamp: Timestamp.now(),
      createdAt: Timestamp.now(),
      lastUpdatedAt: Timestamp.now(),
    );

    try {
      await firestoreService.createNote(quickNote);
      _loggerPage.i("Note rapide (${colorData.title}) ajoutée au journal ${activeJournal.name}");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Note rapide '${colorData.title}' ajoutée !")),
        );
      }
    } catch (e) {
      _loggerPage.e("Erreur ajout note rapide (${colorData.title}): $e");
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
            // Remplacer Center par Column pour permettre le défilement si nécessaire
            // mainAxisAlignment: MainAxisAlignment.center, // Peut être retiré si on veut le contenu en haut
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
              // SizedBox(height: 20), // Ajuster l'espacement
              if (activeJournalNotifier.isLoading)
                Expanded(child: Center(child: CircularProgressIndicator())) // Utiliser Expanded pour centrer si la colonne prend toute la hauteur
              else if (activeJournal != null && currentUserId != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    'Journal Actif: ${activeJournal.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),

                // -- Section Grille de Boutons --
                Expanded( // Utiliser Expanded pour que la grille prenne l'espace restant
                  child: activeJournal.palette.colors.isEmpty
                      ? Center(child: Text("La palette de ce journal est vide.\nModifiez le journal pour ajouter des couleurs.", textAlign: TextAlign.center,))
                      : GridView.builder(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7, // Jusqu'à 7 éléments horizontalement
                      crossAxisSpacing: 10.0, // Espace horizontal entre les carrés
                      mainAxisSpacing: 10.0, // Espace vertical entre les carrés
                      childAspectRatio: 1.0, // Pour rendre les éléments carrés (largeur = hauteur)
                    ),
                    itemCount: activeJournal.palette.colors.length,
                    itemBuilder: (context, index) {
                      final colorData = activeJournal.palette.colors[index];
                      final Color textColor = colorData.color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

                      return ElevatedButton(
                        onPressed: () => _addQuickNoteForColor(context, activeJournal, colorData, currentUserId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorData.color,
                          foregroundColor: textColor, // Couleur du texte et de l'icône
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0), // Coins arrondis
                          ),
                          padding: EdgeInsets.zero, // Pas de padding interne pour que le texte soit centré
                          elevation: 4.0,
                        ),
                        child: Center( // Centrer le texte dans le bouton
                          child: Text(
                            colorData.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12), // Ajuster la taille si nécessaire
                            overflow: TextOverflow.ellipsis, // Gérer les textes longs
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // -- Fin Section Grille de Boutons --


              ] else if (activeJournalNotifier.errorMessage != null) ... [
                Expanded( // Utiliser Expanded pour centrer
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
                Expanded( // Utiliser Expanded pour centrer
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
