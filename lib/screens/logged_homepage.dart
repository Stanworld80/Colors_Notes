import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math'; // Pour Random et fonctions mathématiques
import 'package:flutter/material.dart';

class LoggedHomepage extends StatefulWidget {
  const LoggedHomepage({Key? key}) : super(key: key);

  @override
  _LoggedHomepageState createState() => _LoggedHomepageState();
}

class _LoggedHomepageState extends State<LoggedHomepage> {
  List<Color> _arrangedColors = [];
  final int _gridWidth = 7;
  final int _gridHeight = 5;
  // Seuil de contraste minimum souhaité (WCAG AA pour les grands éléments graphiques)
  final double _minContrastRatio = 3.0;

  @override
  void initState() {
    super.initState();
    _initializeColors();
  }

  // Initialise la génération et l'arrangement des couleurs
  void _initializeColors() {
    final int totalCells = _gridWidth * _gridHeight;
    // Générer plus de couleurs que nécessaire pour avoir plus de choix lors de l'arrangement
    // et compenser les éventuels doublons supprimés par le Set.
    final List<Color> distinctColors = _generateUniqueDistinctColors(totalCells * 3, totalCells); // Augmenter le facteur initial
    setState(() {
      // Essayer d'arranger les couleurs pour maximiser le contraste adjacent
      _arrangedColors = _arrangeColorsForContrast(distinctColors, totalCells);
    });
  }

  // Génère une liste de couleurs visuellement distinctes et uniques en utilisant l'espace HSL et un Set
  List<Color> _generateUniqueDistinctColors(int initialCount, int targetCount) {
    Set<Color> uniqueColors = {}; // Utiliser un Set pour garantir l'unicité
    final random = Random();
    int generationAttempts = 0;
    const int maxAttempts = 5; // Limite pour éviter une boucle infinie si la génération est difficile

    // Essayer de générer jusqu'à obtenir assez de couleurs uniques, ou atteindre la limite d'essais
    while (uniqueColors.length < targetCount && generationAttempts < maxAttempts) {
      // Générer un lot de couleurs
      for (int i = 0; i < initialCount; i++) {
        // Utiliser une approche légèrement différente pour varier les tentatives
        final double hue = random.nextDouble() * 360; // Teinte aléatoire
        final double saturation = 0.6 + random.nextDouble() * 0.4; // Saturation entre 0.6 et 1.0
        final double lightness = 0.4 + random.nextDouble() * 0.3; // Luminosité entre 0.4 et 0.7
        uniqueColors.add(HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor());

        // Arrêter si on a assez de couleurs
        if (uniqueColors.length >= targetCount) break;
      }
      generationAttempts++;
      // Augmenter potentiellement initialCount si on n'a pas assez de couleurs après une tentative
      initialCount = (initialCount * 1.2).toInt();
    }


    // Convertir le Set en List et mélanger
    List<Color> colors = uniqueColors.toList();
    // Si on n'a toujours pas assez de couleurs (très improbable avec les paramètres actuels),
    // compléter avec des couleurs aléatoires (qui pourraient être des doublons mais c'est un fallback)
    while (colors.length < targetCount) {
      colors.add(Color((random.nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0));
    }
    // Tronquer si on en a généré trop
    if (colors.length > targetCount) {
      colors = colors.sublist(0, targetCount);
    }

    colors.shuffle(random); // Mélanger pour éviter les motifs initiaux évidents
    return colors;
  }

  // Calcule le ratio de contraste entre deux couleurs en utilisant la luminance relative (Standard WCAG)
  double _calculateContrastRatio(Color color1, Color color2) {
    // Calcule la luminance relative pour chaque couleur (valeur entre 0 et 1)
    // computeLuminance() implémente la formule standard WCAG.
    final double lum1 = color1.computeLuminance();
    final double lum2 = color2.computeLuminance();

    // La formule du ratio de contraste est (L1 + 0.05) / (L2 + 0.05),
    // où L1 est la luminance de la couleur la plus claire et L2 celle de la plus sombre.
    final double contrast = (max(lum1, lum2) + 0.05) / (min(lum1, lum2) + 0.05);
    // Gérer le cas où les couleurs sont identiques (division par zéro potentiel)
    if (contrast.isNaN || contrast.isInfinite) {
      return 1.0; // Contraste de 1:1 si les couleurs sont identiques
    }
    return contrast;
  }


  // Algorithme "glouton" pour essayer d'arranger les couleurs pour un meilleur contraste adjacent
  List<Color> _arrangeColorsForContrast(List<Color> availableColors, int totalCells) {
    if (availableColors.isEmpty) return [];

    // La grille, initialement vide (null)
    List<Color?> grid = List.filled(totalCells, null);
    // La réserve de couleurs disponibles
    List<Color> pool = List.from(availableColors);
    final random = Random();

    // Remplir la grille cellule par cellule
    for (int i = 0; i < totalCells; i++) {
      int row = i ~/ _gridWidth;
      int col = i % _gridWidth;

      Color? bestColorChoice; // La meilleure couleur trouvée pour cette cellule
      double maxMinContrastFound = -1.0; // Le plus grand "plus petit contraste" trouvé
      int bestColorIndexInPool = -1; // L'index de la meilleure couleur dans la réserve

      // Mélanger légèrement la réserve pour varier l'ordre de test
      pool.shuffle(random);

      // Tester chaque couleur restante dans la réserve
      for (int j = 0; j < pool.length; j++) {
        Color candidateColor = pool[j];
        double currentMinContrastWithNeighbors = double.infinity; // Le plus petit contraste de cette candidate avec ses voisins
        bool meetsMinContrastThreshold = true;

        // Vérifier le contraste avec le voisin de gauche (si existant et déjà placé)
        if (col > 0 && grid[i - 1] != null) {
          // Éviter de comparer une couleur avec elle-même si elle a été placée par erreur
          if (grid[i-1]!.value == candidateColor.value) {
            currentMinContrastWithNeighbors = 1.0; // Contraste nul
            meetsMinContrastThreshold = false;
          } else {
            double contrastLeft = _calculateContrastRatio(candidateColor, grid[i - 1]!);
            currentMinContrastWithNeighbors = min(currentMinContrastWithNeighbors, contrastLeft);
            if (contrastLeft < _minContrastRatio) meetsMinContrastThreshold = false;
          }
        }

        // Vérifier le contraste avec le voisin du haut (si existant et déjà placé)
        if (row > 0 && grid[i - _gridWidth] != null) {
          if (grid[i - _gridWidth]!.value == candidateColor.value) {
            currentMinContrastWithNeighbors = 1.0; // Contraste nul
            meetsMinContrastThreshold = false;
          } else {
            double contrastTop = _calculateContrastRatio(candidateColor, grid[i - _gridWidth]!);
            currentMinContrastWithNeighbors = min(currentMinContrastWithNeighbors, contrastTop);
            if (contrastTop < _minContrastRatio) meetsMinContrastThreshold = false;
          }
        }

        // Logique de sélection (inchangée)
        if (meetsMinContrastThreshold) {
          if (bestColorChoice == null || currentMinContrastWithNeighbors > maxMinContrastFound) {
            maxMinContrastFound = currentMinContrastWithNeighbors;
            bestColorChoice = candidateColor;
            bestColorIndexInPool = j;
          }
        } else if (bestColorChoice == null) {
          if (currentMinContrastWithNeighbors > maxMinContrastFound) {
            maxMinContrastFound = currentMinContrastWithNeighbors;
            bestColorChoice = candidateColor;
            bestColorIndexInPool = j;
          }
        }
      } // Fin de la boucle sur les couleurs candidates


      // Assignation de la couleur à la cellule (inchangée)
      if (bestColorChoice == null && pool.isNotEmpty) {
        bestColorChoice = pool.removeAt(0);
      } else if (bestColorIndexInPool != -1 && bestColorIndexInPool < pool.length) { // Ajouter vérification index
        // Retirer la couleur choisie de la réserve
        pool.removeAt(bestColorIndexInPool);
      } else if (bestColorChoice == null && pool.isEmpty) {
        // Cas très improbable où on n'a plus de couleurs
        bestColorChoice = Colors.grey;
      }


      // Placer la couleur choisie (ou gris si erreur) dans la grille
      grid[i] = bestColorChoice ?? Colors.grey;
    } // Fin de la boucle sur les cellules de la grille

    // Convertir la liste de couleurs potentiellement nulles en liste non-nulle
    return grid.map((c) => c ?? Colors.grey).toList();
  }


  // Méthode de déconnexion (inchangée)
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
      }
    } catch (e) {
      print("Error signing out: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Obtenir la largeur de l'écran pour dimensionner la grille
    final screenWidth = MediaQuery.of(context).size.width;
    // Définir la largeur souhaitée pour la grille (ex: 60% de l'écran)
    final gridTargetWidth = screenWidth * 0.45; // Ajustez ce facteur (0.6 = 60%)

    return Scaffold(
      appBar: AppBar(title: const Text('Logged In Homepage')),
      // Utiliser ListView pour permettre le défilement si nécessaire
      body: ListView(
        children: <Widget>[
          // Conserver le message de bienvenue et infos utilisateur
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome!',
                    style: TextStyle(fontSize: 24),
                  ),
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'You are logged in as: ${user.email}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _signOut(context),
                    child: const Text('Sign Out'),
                  ),
                ]
            ),
          ),

          const SizedBox(height: 20), // Espacement

          // --- Section de la Grille de Couleurs (Centrée et Réduite) ---
          // Center widget pour centrer horizontalement son enfant
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              // Container pour limiter la largeur de la grille
              child: Container(
                width: gridTargetWidth, // Appliquer la largeur cible
                child: AspectRatio( // Conserver le ratio 8/6 à l'intérieur de la largeur limitée
                  aspectRatio: _gridWidth / _gridHeight,
                  child: _arrangedColors.isEmpty
                  // Indicateur de chargement pendant la génération des couleurs
                      ? const Center(child: CircularProgressIndicator())
                  // La grille une fois les couleurs prêtes
                      : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridWidth, // Nombre de colonnes
                      mainAxisSpacing: 2.0,       // Espace vertical réduit
                      crossAxisSpacing: 2.0,      // Espace horizontal réduit
                    ),
                    itemCount: _arrangedColors.length, // Nombre total d'éléments
                    // Désactiver le défilement interne de la grille (géré par ListView)
                    physics: const NeverScrollableScrollPhysics(),
                    // Construire chaque cellule de la grille
                    itemBuilder: (context, index) {
                      final color = _arrangedColors[index];
                      return GestureDetector(
                        onTap: () {
                          // Action lors du clic sur une couleur
                          print('Tapped color index: $index, color: $color');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Couleur cliquée : ${color.toString()}'),
                              backgroundColor: color, // Fond du snackbar avec la couleur
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        // Le carré de couleur
                        child: Container(
                          decoration: BoxDecoration(
                              color: color,
                              // Optionnel : bordure pour mieux séparer visuellement
                              border: Border.all(color: Colors.black54, width: 0.5),
                              borderRadius: BorderRadius.circular(2.0) // Coins réduits
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Possibilité d'ajouter d'autres widgets sous la grille ici
        ],
      ),
    );
  }
}