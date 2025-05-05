// lib/screens/logged_homepage.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import des providers et services nécessaires
import '../providers/active_agenda_provider.dart';
import '../services/firestore_service.dart';

// AuthService n'est plus nécessaire ici directement pour l'AppBar
// import '../services/auth_service.dart';

// Import des modèles de données
import '../models/agenda.dart';
import '../models/color_data.dart';
import '../models/note.dart';

// Import du widget AppBar réutilisable
import '../widgets/dynamic_agenda_app_bar.dart';

// EditPaletteModelPage n'est plus nécessaire ici directement pour l'AppBar
// import 'edit_palette_model_page.dart';

class LoggedHomepage extends StatefulWidget {
  const LoggedHomepage({Key? key}) : super(key: key);

  @override
  State<LoggedHomepage> createState() => _LoggedHomepageState();
}

class _LoggedHomepageState extends State<LoggedHomepage> {
  bool _isLoadingAgenda = true; // État pour gérer l'indicateur de chargement initial

  @override
  void initState() {
    super.initState();
    // Planifie l'exécution de _loadInitialAgenda après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Utiliser context.read ici car c'est dans initState/callback
      if (context.read<ActiveAgendaNotifier>().activeAgendaId == null) {
        _loadInitialAgenda();
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAgenda = false;
          });
        }
      }
    });
  }

  /// Charge le premier agenda disponible pour l'utilisateur comme agenda actif initial.
  Future<void> _loadInitialAgenda() async {
    // (Logique inchangée par rapport à la version précédente)
    if (!mounted) return;
    final firestoreService = context.read<FirestoreService>();
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();
    final user = context.read<User?>();

    if (user != null) {
      try {
        List<Agenda> userAgendas = await firestoreService.getUserAgendasStream(user.uid).first;
        Agenda? initialAgenda;
        if (userAgendas.isNotEmpty) {
          initialAgenda = userAgendas.first;
        }
        if (mounted) {
          activeAgendaNotifier.setActiveAgenda(initialAgenda);
        }
      } catch (e) {
        print("Erreur chargement agenda initial: $e");
        if (mounted) {
          activeAgendaNotifier.setActiveAgenda(null);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur chargement agendas: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingAgenda = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingAgenda = false;
        });
        activeAgendaNotifier.setActiveAgenda(null);
      }
    }
  }

  // La méthode _signOut n'est plus nécessaire ici, elle est dans l'AppBar

  /// Affiche une boîte de dialogue pour créer une nouvelle note associée à une couleur.
  void _showCreateNoteDialog(BuildContext context, ColorData colorData, String agendaId) {
    // (Logique inchangée par rapport à la version précédente)
    final TextEditingController commentController = TextEditingController();
    Color color;
    try {
      color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey;
      print("Erreur parsing couleur pour dialog: ${colorData.hexValue} - ${e}");
    }
    final firestoreService = context.read<FirestoreService>();
    final user = context.read<User?>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [Container(width: 20, height: 20, color: color), const SizedBox(width: 10), Expanded(child: Text('Note pour "${colorData.title}"', overflow: TextOverflow.ellipsis))],
          ),
          content: TextField(
            controller: commentController,
            autofocus: true,
            maxLength: 256,
            decoration: const InputDecoration(hintText: 'Entrez votre commentaire...', labelText: 'Commentaire'),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
            ElevatedButton(
              child: const Text('Enregistrer'),
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isNotEmpty) {
                  if (user != null) {
                    final newNote = Note(id: '', agendaId: agendaId, userId: user.uid, colorSnapshot: colorData, comment: comment, createdAt: Timestamp.now(), commentUpdatedAt: Timestamp.now());
                    try {
                      await firestoreService.createNote(newNote);
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note enregistrée !'), duration: Duration(seconds: 2)));
                      }
                    } catch (e) {
                      print("Error saving note: $e");
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                      }
                    }
                  } else {
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur: Utilisateur déconnecté.'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Écouter les changements nécessaires pour le corps de la page ---
    final activeAgendaNotifier = context.watch<ActiveAgendaNotifier>();
    final Agenda? currentAgenda = activeAgendaNotifier.currentAgenda;
    final List<ColorData> currentColors = currentAgenda?.embeddedPaletteInstance.colors ?? [];

    return Scaffold(
      // ================== Utilisation de l'AppBar Réutilisable ==================
      appBar: const DynamicAgendaAppBar(), // Simplement instancier le widget
      // ========================================================================

      // --- Corps de la page (logique inchangée) ---
      body:
          _isLoadingAgenda
              ? const Center(child: CircularProgressIndicator())
              : (currentAgenda == null
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "Aucun agenda sélectionné ou trouvé.\n\nAllez dans l'onglet 'Agendas' pour en créer ou en sélectionner un.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                  : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: <Widget>[
                      if (currentColors.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
                          child: Center(
                            child: Text(
                              'Cette palette est vide.\nModifiez-la en cliquant sur l\'icône 🖌️\nen haut à droite.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 100.0, crossAxisSpacing: 10.0, mainAxisSpacing: 10.0, childAspectRatio: 1.1),
                            itemCount: currentColors.length,
                            itemBuilder: (context, index) {
                              final colorData = currentColors[index];
                              Color color;
                              try {
                                color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));
                              } catch (e) {
                                color = Colors.grey;
                                print("Erreur parsing couleur grille: ${colorData.hexValue} - ${e}");
                              }

                              return InkWell(
                                onTap: () {
                                  _showCreateNoteDialog(context, colorData, currentAgenda.id);
                                },
                                borderRadius: BorderRadius.circular(8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(color: Colors.black38, width: 0.5),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(1, 1))],
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Text(
                                        colorData.title,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  )),
    );
  }
}
