import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import des providers et services nécessaires
import '../providers/active_agenda_provider.dart';
import '../services/auth_service.dart'; // Besoin pour signOut
import '../services/firestore_service.dart'; // Besoin pour getUserAgendasStream

// Import des modèles de données
import '../models/agenda.dart';
import '../models/color_data.dart';
import '../models/note.dart';

// Import pour la navigation vers la page d'édition de palette
import 'edit_palette_model_page.dart';

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
      // Charger l'agenda initial seulement si aucun n'est déjà défini dans le provider
      if (context.read<ActiveAgendaNotifier>().activeAgendaId == null) {
        _loadInitialAgenda();
      } else {
        // Si un agenda est déjà chargé (ex: après navigation retour),
        // on n'a pas besoin de le recharger, juste arrêter l'indicateur.
        if (mounted) {
          setState(() {
            _isLoadingAgenda = false;
          });
        }
      }
    });
  }

  /// Charge le premier agenda disponible pour l'utilisateur comme agenda actif initial.
  /// Gère les cas où l'utilisateur n'a pas d'agenda ou si une erreur survient.
  Future<void> _loadInitialAgenda() async {
    // S'assurer que le widget est toujours monté avant de continuer
    if (!mounted) return;

    // Utiliser context.read car on est hors de la méthode build
    final firestoreService = context.read<FirestoreService>();
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();
    final user = context.read<User?>();

    if (user != null) { // Vérifier si l'utilisateur est connecté
      try {
        // Attendre la première liste d'agendas du stream pour l'utilisateur connecté
        List<Agenda> userAgendas = await firestoreService.getUserAgendasStream(user.uid).first;

        Agenda? initialAgenda;
        if (userAgendas.isNotEmpty) {
          // TODO (Amélioration SF-AGENDA-03): Charger le dernier utilisé au lieu du premier
          initialAgenda = userAgendas.first; // Prend le premier agenda trouvé
        }

        // Mettre à jour le notifier avec l'agenda trouvé (ou null si aucun)
        // seulement si le widget est toujours monté
        if (mounted) {
          activeAgendaNotifier.setActiveAgenda(initialAgenda);
        }
      } catch (e) {
        print("Erreur chargement agenda initial: $e");
        if (mounted) {
          // Mettre null en cas d'erreur pour afficher un état cohérent
          activeAgendaNotifier.setActiveAgenda(null);
          // Afficher un message d'erreur à l'utilisateur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur chargement agendas: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        // Arrêter l'indicateur de chargement dans tous les cas (succès ou erreur)
        if (mounted) {
          setState(() {
            _isLoadingAgenda = false;
          });
        }
      }
    } else {
      // Pas d'utilisateur connecté, pas d'agenda à charger
      if (mounted) {
        setState(() {
          _isLoadingAgenda = false;
        });
        // S'assurer que l'agenda est bien null dans le notifier
        activeAgendaNotifier.setActiveAgenda(null);
      }
    }
  }

  /// Gère la déconnexion de l'utilisateur via AuthService.
  Future<void> _signOut(BuildContext context) async {
    // Utiliser context.read pour accéder aux services/notifiers dans une méthode
    final authService = context.read<AuthService>();
    final activeAgendaNotifier = context.read<ActiveAgendaNotifier>();
    try {
      await authService.signOut(); // Appelle la méthode de déconnexion du service
      activeAgendaNotifier.clearActiveAgenda(); // Réinitialise l'agenda actif dans le provider
      // La redirection vers l'écran de connexion sera gérée par EntryPage/AuthGate
      // qui écoute les changements d'état d'authentification.
    } catch (e) {
      print("Error signing out: $e");
      // Afficher une erreur si la déconnexion échoue
      if (mounted) { // Vérifier si le widget est toujours monté
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  /// Affiche une boîte de dialogue pour créer une nouvelle note associée à une couleur.
  void _showCreateNoteDialog(BuildContext context, ColorData colorData, String agendaId) {
    final TextEditingController commentController = TextEditingController();
    // Parse la couleur Hex en objet Color, gère les erreurs potentielles
    Color color;
    try {
      color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));
    } catch (e) {
      color = Colors.grey; // Couleur de secours en cas d'erreur
      print("Erreur parsing couleur pour dialog: ${colorData.hexValue} - ${e}");
    }

    // Lire les dépendances avant d'appeler showDialog pour éviter les lookups dans un contexte asynchrone
    final firestoreService = context.read<FirestoreService>();
    final user = context.read<User?>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Utiliser dialogContext pour les actions internes à la dialog si nécessaire
        return AlertDialog(
          title: Row(
            children: [
              Container(width: 20, height: 20, color: color), // Affiche la couleur
              const SizedBox(width: 10),
              // Affiche le titre de la couleur, gère les textes longs
              Expanded(child: Text('Note pour "${colorData.title}"', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: TextField(
            controller: commentController,
            autofocus: true, // Met le focus directement sur le champ
            maxLength: 256, // Limite de caractères (SF-NOTE-01)
            decoration: const InputDecoration(
              hintText: 'Entrez votre commentaire...',
              labelText: 'Commentaire',
            ),
            maxLines: 3, // Permet plusieurs lignes pour le commentaire
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(), // Ferme la dialog
            ),
            ElevatedButton(
              child: const Text('Enregistrer'), // Bouton pour sauvegarder (SF-NOTE-01)
              onPressed: () async {
                final comment = commentController.text.trim(); // Récupère et nettoie le commentaire
                if (comment.isNotEmpty) { // Vérifie si le commentaire n'est pas vide
                  if (user != null) { // Vérifie si l'utilisateur est toujours connecté
                    // Crée l'objet Note avec les données requises (SF-NOTE-02)
                    final newNote = Note(
                      id: '', // L'ID sera généré par Firestore
                      agendaId: agendaId,
                      userId: user.uid,
                      colorSnapshot: colorData, // Copie les détails de la couleur
                      comment: comment,
                      createdAt: Timestamp.now(), // Date de création
                      commentUpdatedAt: Timestamp.now(), // Date de dernière modif (identique à création ici)
                    );
                    try {
                      // Appelle le service Firestore pour créer la note
                      await firestoreService.createNote(newNote);
                      Navigator.of(dialogContext).pop(); // Ferme la dialog après succès
                      // Affiche une confirmation à l'utilisateur sur le Scaffold principal
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note enregistrée !'), duration: Duration(seconds: 2)),
                        );
                      }
                    } catch (e) {
                      // Gère les erreurs de sauvegarde Firestore
                      print("Error saving note: $e");
                      Navigator.of(dialogContext).pop(); // Ferme quand même la dialog
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    // Cas où l'utilisateur se serait déconnecté pendant la saisie
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erreur: Utilisateur déconnecté.'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
                // Si le commentaire est vide, on ne fait rien (l'utilisateur peut corriger ou annuler)
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // --- Écouter les changements de l'utilisateur et de l'agenda actif ---
    // context.watch reconstruit le widget si ces valeurs changent
    final user = context.watch<User?>();
    final activeAgendaNotifier = context.watch<ActiveAgendaNotifier>();
    final Agenda? currentAgenda = activeAgendaNotifier.currentAgenda; // Peut être null
    final List<ColorData> currentColors = currentAgenda?.embeddedPaletteInstance.colors ?? []; // Liste vide si pas d'agenda
    final String? userId = user?.uid; // Obtenir userId pour le StreamBuilder de l'AppBar

    // --- Lire les services (pas besoin de watch, ils ne changent pas) ---
    // context.read récupère une instance sans s'abonner aux changements
    final firestoreService = context.read<FirestoreService>();
    final authService = context.read<AuthService>(); // Pour le bouton logout

    return Scaffold(
      appBar: AppBar(
        // ================== Titre Dynamique avec Sélection d'Agenda ==================
        title: (userId == null || _isLoadingAgenda)
            ? const Text('Colors & Notes') // Titre par défaut pendant chargement ou si déconnecté
            : StreamBuilder<List<Agenda>>(
          // Écoute le stream des agendas de l'utilisateur connecté
          stream: firestoreService.getUserAgendasStream(userId),
          builder: (context, snapshot) {
            // --- Gestion des états du Stream ---
            // 1. En attente ET aucun agenda n'est encore chargé dans le Notifier
            if (snapshot.connectionState == ConnectionState.waiting && currentAgenda == null) {
              return const Text('Chargement...'); // Indicateur textuel simple
            }
            // 2. Erreur pendant le chargement du Stream
            if (snapshot.hasError) {
              print("Erreur Stream Agendas AppBar: ${snapshot.error}");
              // Affiche le nom de l'agenda potentiellement déjà chargé, sinon un message d'erreur
              return Text(currentAgenda?.name ?? 'Erreur Agendas');
            }
            // 3. Stream actif mais pas (encore) de données OU stream terminé sans données
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Si un agenda est actif (ex: vient d'être créé mais le stream n'est pas à jour), on affiche son nom.
              // Sinon, on indique qu'il n'y a pas d'agenda.
              return Text(currentAgenda?.name ?? 'Aucun Agenda');
            }

            // --- Stream OK et contient des données ---
            final agendas = snapshot.data!; // La liste des agendas de l'utilisateur
            // Récupérer le nom de l'agenda actuellement actif depuis le Notifier
            final currentAgendaName = currentAgenda?.name ?? 'Sélectionner Agenda';

            // Construire le PopupMenuButton pour permettre la sélection
            return PopupMenuButton<String>( // La valeur sélectionnée sera l'ID (String) de l'agenda
              tooltip: "Changer l'agenda actif", // Aide visuelle au survol
              // Callback exécuté lorsqu'un item du menu est sélectionné
              onSelected: (String selectedAgendaId) {
                // Trouver l'objet Agenda complet correspondant à l'ID sélectionné dans la liste
                try {
                  final selectedAgenda = agendas.firstWhere((a) => a.id == selectedAgendaId);
                  // Mettre à jour l'agenda actif dans le Provider (utiliser context.read dans un callback)
                  context.read<ActiveAgendaNotifier>().setActiveAgenda(selectedAgenda);
                } catch (e) {
                  // Gérer le cas (improbable) où l'ID sélectionné n'est pas trouvé
                  print("Erreur: Agenda sélectionné ($selectedAgendaId) non trouvé dans la liste.");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de la sélection de l\'agenda.'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              // Fonction qui construit la liste des items dans le menu déroulant
              itemBuilder: (BuildContext context) {
                // Crée une entrée de menu pour chaque agenda de la liste
                return agendas.map((Agenda agenda) {
                  return PopupMenuItem<String>(
                    value: agenda.id, // La valeur associée à cet item est l'ID de l'agenda
                    child: Text(
                      agenda.name, // Texte affiché pour l'item
                      // Optionnel: Mettre en évidence l'agenda actuellement actif
                      style: TextStyle(
                        fontWeight: agenda.id == currentAgenda?.id ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList();
              },
              // Le widget qui est affiché dans l'AppBar et sur lequel on clique pour ouvrir le menu
              child: Row(
                mainAxisSize: MainAxisSize.min, // Pour que la Row prenne juste la place nécessaire
                children: [
                  Flexible( // Empêche le texte du nom de l'agenda de déborder
                    child: Text(
                      currentAgendaName, // Affiche le nom de l'agenda actif
                      overflow: TextOverflow.ellipsis, // Ajoute '...' si le nom est trop long
                    ),
                  ),
                  // Icône indiquant qu'un menu déroulant est disponible
                  const Icon(Icons.arrow_drop_down, color: Colors.white), // Couleur assortie à l'AppBar
                ],
              ),
            );
          },
        ),
        // ================== FIN Titre Dynamique ==================
        actions: [
          // --- Bouton pour Modifier la Palette de l'Agenda Actif ---
          // Afficher ce bouton seulement si un agenda est actif
          if (currentAgenda != null)
            IconButton(
              icon: const Icon(Icons.palette_outlined), // Icône de palette
              tooltip: 'Modifier la palette de "${currentAgenda.name}"', // Aide contextuelle
              onPressed: () {
                // Naviguer vers la page d'édition de palette
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditPaletteModelPage(
                      // IMPORTANT: Passer l'instance de l'agenda actuel
                      // pour indiquer qu'on modifie la palette de CET agenda
                      // et non un modèle.
                      existingAgendaInstance: currentAgenda,
                    ),
                  ),
                );
              },
            ),
          // --- Bouton de Déconnexion ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () => _signOut(context), // Appelle la méthode de déconnexion
          ),
        ],
      ),
      // --- Corps de la page ---
      body: _isLoadingAgenda
          ? const Center(child: CircularProgressIndicator()) // Indicateur pendant le chargement initial
          : (currentAgenda == null
      // --- Cas où aucun agenda n'est actif après le chargement ---
          ? const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
                "Aucun agenda sélectionné ou trouvé.\n\nAllez dans l'onglet 'Agendas' pour en créer ou en sélectionner un.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ))
      // --- Cas où un agenda est actif ---
          : ListView( // Utiliser ListView pour permettre le défilement si la grille est grande
        padding: const EdgeInsets.only(bottom: 80), // Espace en bas pour la BottomNavBar
        children: <Widget>[
          // --- Grille des Couleurs de la Palette Active ---
          // Afficher un message si la palette est vide
          if (currentColors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
              child: Center(
                child: Text(
                    'Cette palette est vide.\nModifiez-la en cliquant sur l\'icône 🖌️\nen haut à droite.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])
                ),
              ),
            )
          // Afficher la grille si la palette contient des couleurs
          else
            Padding(
              padding: const EdgeInsets.all(16.0), // Marge autour de la grille
              child: GridView.builder(
                shrinkWrap: true, // Nécessaire car la GridView est dans un ListView
                physics: const NeverScrollableScrollPhysics(), // Le ListView gère le défilement principal
                // Configuration de l'apparence de la grille
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100.0, // Taille maximale de chaque cellule en largeur
                  // Alternative: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4 ou 5)
                  crossAxisSpacing: 10.0, // Espacement horizontal entre les cellules
                  mainAxisSpacing: 10.0, // Espacement vertical entre les cellules
                  childAspectRatio: 1.1, // Ratio largeur/hauteur des cellules (légèrement plus hautes)
                ),
                itemCount: currentColors.length, // Nombre d'items dans la grille
                // Fonction pour construire chaque cellule de la grille
                itemBuilder: (context, index) {
                  final colorData = currentColors[index]; // Données de la couleur pour cette cellule
                  // Parse la couleur Hex en objet Color, avec gestion d'erreur
                  Color color;
                  try {
                    color = Color(int.parse(colorData.hexValue.replaceFirst('#', 'FF'), radix: 16));
                  } catch (e) {
                    color = Colors.grey; // Couleur de secours si le format hex est invalide
                    print("Erreur parsing couleur grille: ${colorData.hexValue} - ${e}");
                  }

                  // Utiliser InkWell pour un effet visuel au clic (ripple)
                  return InkWell(
                    onTap: () {
                      // Ouvre la dialog de création de note en passant les infos nécessaires (SF-NOTE-01)
                      _showCreateNoteDialog(context, colorData, currentAgenda.id);
                    },
                    borderRadius: BorderRadius.circular(8.0), // Assorti à la décoration du Container
                    child: Container(
                      decoration: BoxDecoration(
                          color: color, // Couleur de fond de la cellule
                          borderRadius: BorderRadius.circular(8.0), // Coins arrondis
                          border: Border.all(color: Colors.black38, width: 0.5), // Légère bordure
                          // Ombre portée pour un effet de relief
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(1, 1), // Décalage de l'ombre
                            )
                          ]
                      ),
                      // Contenu de la cellule (le titre de la couleur)
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4.0), // Petit padding autour du texte
                          child: Text(
                            colorData.title, // Affiche le titre de la couleur (SF-NOTE-01)
                            textAlign: TextAlign.center, // Centre le texte
                            style: TextStyle(
                              // Choisit la couleur du texte (blanc ou noir) pour une meilleure lisibilité
                              color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                  ? Colors.white : Colors.black,
                              fontSize: 11, // Taille de police
                              fontWeight: FontWeight.w500, // Graisse de la police
                            ),
                            overflow: TextOverflow.ellipsis, // Ajoute '...' si le titre est trop long
                            maxLines: 2, // Permet au titre d'occuper jusqu'à 2 lignes
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
