// lib/widgets/dynamic_journal_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import des providers et services
import '../providers/active_journal_provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

// Import des modèles
import '../models/journal.dart';

// Import pour la navigation
import '../screens/edit_palette_model_page.dart'; // Pour l'action "Modifier Palette"

/// Un widget AppBar réutilisable qui affiche le nom de l'journal actif
/// et permet de le changer via un PopupMenuButton.
/// Inclut également les actions courantes (Modifier Palette, Déconnexion).
class DynamicJournalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DynamicJournalAppBar({Key? key}) : super(key: key);

  /// Gère la déconnexion de l'utilisateur.
  Future<void> _signOut(BuildContext context) async {
    // Utiliser context.read car on est dans une méthode helper
    final authService = context.read<AuthService>();
    final activeJournalNotifier = context.read<ActiveJournalNotifier>();
    try {
      await authService.signOut();
      activeJournalNotifier.clearActiveJournal();
    } catch (e) {
      print("Error signing out from AppBar: $e");
      // Utiliser le context original passé pour le ScaffoldMessenger
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Récupérer les informations nécessaires depuis Provider ---
    final activeJournalNotifier = context.watch<ActiveJournalNotifier>();
    final Journal? currentJournal = activeJournalNotifier.currentJournal;
    final String? userId = context.watch<User?>()?.uid;
    final firestoreService = context.read<FirestoreService>();

    return AppBar(
      // --- Titre dynamique avec sélection d'journal ---
      title:
          (userId == null) // Si pas connecté, titre simple
              ? const Text('Colors & Notes')
              : StreamBuilder<List<Journal>>(
                // Écoute les journals de l'utilisateur
                stream: firestoreService.getUserJournalsStream(userId),
                builder: (context, snapshot) {
                  // --- Gestion des états du Stream ---
                  if (snapshot.connectionState == ConnectionState.waiting && currentJournal == null) {
                    return const Text('Chargement...');
                  }
                  if (snapshot.hasError) {
                    print("Erreur Stream Journals AppBar (Widget): ${snapshot.error}");
                    return Text(currentJournal?.name ?? 'Erreur Journals');
                  }
                  // Si pas de données ou liste vide, afficher nom courant ou indication
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text(currentJournal?.name ?? 'Aucun Journal');
                  }

                  // --- Stream OK ---
                  final journals = snapshot.data!;
                  final currentJournalName = currentJournal?.name ?? 'Sélectionner Journal';

                  // --- PopupMenuButton pour la sélection ---
                  return PopupMenuButton<String>(
                    tooltip: "Changer l'journal actif",
                    onSelected: (String selectedJournalId) {
                      // Logique de sélection (identique aux versions précédentes)
                      try {
                        final selectedJournal = journals.firstWhere((a) => a.id == selectedJournalId);
                        context.read<ActiveJournalNotifier>().setActiveJournal(selectedJournal);
                      } catch (e) {
                        print("Erreur sélection journal (AppBar Widget): $selectedJournalId non trouvé.");
                        // Utiliser le context du builder pour le ScaffoldMessenger
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur sélection journal.'), backgroundColor: Colors.red));
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      // Construction des items (identique aux versions précédentes)
                      return journals.map((Journal journal) {
                        return PopupMenuItem<String>(
                          value: journal.id,
                          child: Text(journal.name, style: TextStyle(fontWeight: journal.id == currentJournal?.id ? FontWeight.bold : FontWeight.normal)),
                        );
                      }).toList();
                    },
                    // Widget cliquable (identique aux versions précédentes)
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Flexible(child: Text(currentJournalName, overflow: TextOverflow.ellipsis)), const Icon(Icons.arrow_drop_down, color: Colors.white)],
                    ),
                  );
                },
              ),
      // --- Actions de l'AppBar ---
      actions: [
        // Bouton Modifier Palette (si journal actif)
        if (currentJournal != null)
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Modifier la palette de "${currentJournal.name}"',
            onPressed: () {
              // Naviguer vers la page d'édition
              Navigator.push(
                context, // Utiliser le context du build
                MaterialPageRoute(builder: (_) => EditPaletteModelPage(existingJournalInstance: currentJournal)),
              );
            },
          ),
        // Bouton Déconnexion
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Déconnexion',
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }

  /// Définit la hauteur préférée de l'AppBar.
  /// Utilise la constante standard kToolbarHeight.
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
