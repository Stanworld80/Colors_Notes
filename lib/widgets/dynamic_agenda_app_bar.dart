// lib/widgets/dynamic_agenda_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import des providers et services
import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

// Import des modèles
import '../models/agenda.dart';

// Import pour la navigation
import '../screens/edit_palette_model_page.dart'; // Pour l'action "Modifier Palette"

/// Un widget AppBar réutilisable qui affiche le nom de l'agenda actif
/// et permet de le changer via un PopupMenuButton.
/// Inclut également les actions courantes (Modifier Palette, Déconnexion).
class DynamicAgendaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DynamicAgendaAppBar({Key? key}) : super(key: key);

  /// Gère la déconnexion de l'utilisateur.
  Future<void> _signOut(BuildContext context) async {
    // Utiliser context.read car on est dans une méthode helper
    final authService = context.read<AuthService>();
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();
    try {
      await authService.signOut();
      activeAgendaNotifier.clearActiveAgenda();
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
    final activeAgendaNotifier = context.watch<ActiveAgendaNotifier>();
    final Agenda? currentAgenda = activeAgendaNotifier.currentAgenda;
    final String? userId = context.watch<User?>()?.uid;
    final firestoreService = context.read<FirestoreService>();

    return AppBar(
      // --- Titre dynamique avec sélection d'agenda ---
      title:
          (userId == null) // Si pas connecté, titre simple
              ? const Text('Colors & Notes')
              : StreamBuilder<List<Agenda>>(
                // Écoute les agendas de l'utilisateur
                stream: firestoreService.getUserAgendasStream(userId),
                builder: (context, snapshot) {
                  // --- Gestion des états du Stream ---
                  if (snapshot.connectionState == ConnectionState.waiting && currentAgenda == null) {
                    return const Text('Chargement...');
                  }
                  if (snapshot.hasError) {
                    print("Erreur Stream Agendas AppBar (Widget): ${snapshot.error}");
                    return Text(currentAgenda?.name ?? 'Erreur Agendas');
                  }
                  // Si pas de données ou liste vide, afficher nom courant ou indication
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text(currentAgenda?.name ?? 'Aucun Agenda');
                  }

                  // --- Stream OK ---
                  final agendas = snapshot.data!;
                  final currentAgendaName = currentAgenda?.name ?? 'Sélectionner Agenda';

                  // --- PopupMenuButton pour la sélection ---
                  return PopupMenuButton<String>(
                    tooltip: "Changer l'agenda actif",
                    onSelected: (String selectedAgendaId) {
                      // Logique de sélection (identique aux versions précédentes)
                      try {
                        final selectedAgenda = agendas.firstWhere((a) => a.id == selectedAgendaId);
                        context.read<ActiveAgendaNotifier>().setActiveAgenda(selectedAgenda);
                      } catch (e) {
                        print("Erreur sélection agenda (AppBar Widget): $selectedAgendaId non trouvé.");
                        // Utiliser le context du builder pour le ScaffoldMessenger
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur sélection agenda.'), backgroundColor: Colors.red));
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      // Construction des items (identique aux versions précédentes)
                      return agendas.map((Agenda agenda) {
                        return PopupMenuItem<String>(
                          value: agenda.id,
                          child: Text(agenda.name, style: TextStyle(fontWeight: agenda.id == currentAgenda?.id ? FontWeight.bold : FontWeight.normal)),
                        );
                      }).toList();
                    },
                    // Widget cliquable (identique aux versions précédentes)
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [Flexible(child: Text(currentAgendaName, overflow: TextOverflow.ellipsis)), const Icon(Icons.arrow_drop_down, color: Colors.white)],
                    ),
                  );
                },
              ),
      // --- Actions de l'AppBar ---
      actions: [
        // Bouton Modifier Palette (si agenda actif)
        if (currentAgenda != null)
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Modifier la palette de "${currentAgenda.name}"',
            onPressed: () {
              // Naviguer vers la page d'édition
              Navigator.push(
                context, // Utiliser le context du build
                MaterialPageRoute(builder: (_) => EditPaletteModelPage(existingAgendaInstance: currentAgenda)),
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
