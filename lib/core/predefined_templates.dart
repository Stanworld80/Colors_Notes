// lib/core/predefined_templates.dart

import '../models/palette_model.dart';
import '../models/color_data.dart';
import 'package:uuid/uuid.dart';

/// Generates a unique ID for new ColorData instances within predefined palettes.
/// This ensures that each color definition within a template has a stable, unique identifier.
String _generateColorId() => const Uuid().v4();

/// List of predefined palette models available to all users.
/// These palettes serve as starting points for creating new journals.
List<PaletteModel> predefinedPalettes = [
  // Palette par défaut (existante)
  PaletteModel(
    id: 'default_palette_1', // ID for the PaletteModel itself
    name: 'Palette par Défaut',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Content', hexCode: '#FFEB3B'), // Jaune
      ColorData(paletteElementId: _generateColorId(), title: 'Normal', hexCode: '#AED581'), // Vert clair
      ColorData(paletteElementId: _generateColorId(), title: 'Fatigué', hexCode: '#FF7043'), // Orange corail
      ColorData(paletteElementId: _generateColorId(), title: 'Stressé', hexCode: '#F44336'), // Rouge
      ColorData(paletteElementId: _generateColorId(), title: 'Inspiré', hexCode: '#2196F3'), // Bleu
    ],
  ),

  // Thème Sport
  PaletteModel(
    id: 'sport_palette_theme',
    name: 'Thème : Sport',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Force', hexCode: '#B71C1C'), // Rouge Foncé
      ColorData(paletteElementId: _generateColorId(), title: 'Endurance', hexCode: '#FF9800'), // Orange
      ColorData(paletteElementId: _generateColorId(), title: 'Cardio', hexCode: '#FFEE58'), // Jaune Vif
      ColorData(paletteElementId: _generateColorId(), title: 'Étirement', hexCode: '#81D4FA'), // Bleu Ciel
      ColorData(paletteElementId: _generateColorId(), title: 'Récupération', hexCode: '#AED581'), // Vert Clair
    ],
  ),

  // Thème Santé
  PaletteModel(
    id: 'sante_palette_theme',
    name: 'Thème : Santé',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'RDV Médecin', hexCode: '#64B5F6'), // Bleu Hôpital
      ColorData(paletteElementId: _generateColorId(), title: 'Examen Médical', hexCode: '#81C784'), // Vert Pharmacie
      ColorData(paletteElementId: _generateColorId(), title: 'Traitement', hexCode: '#FFB74D'), // Orange Doux
      ColorData(paletteElementId: _generateColorId(), title: 'Bien-être', hexCode: '#4DB6AC'), // Turquoise
      ColorData(paletteElementId: _generateColorId(), title: 'Urgence', hexCode: '#E53935'), // Rouge Vif
    ],
  ),

  // Thème Humeur
  PaletteModel(
    id: 'humeur_palette_theme',
    name: 'Thème : Humeur',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Joyeux', hexCode: '#FFF176'), // Jaune Soleil
      ColorData(paletteElementId: _generateColorId(), title: 'Calme', hexCode: '#9FA8DA'), // Bleu Lavande
      ColorData(paletteElementId: _generateColorId(), title: 'Neutre', hexCode: '#E0E0E0'), // Gris Clair
      ColorData(paletteElementId: _generateColorId(), title: 'Triste', hexCode: '#3949AB'), // Bleu Foncé
      ColorData(paletteElementId: _generateColorId(), title: 'Colère', hexCode: '#F44336'), // Rouge Vif
      ColorData(paletteElementId: _generateColorId(), title: 'Stressé', hexCode: '#FB8C00'), // Orange Foncé
    ],
  ),

  // Thème Finance
  PaletteModel(
    id: 'finance_palette_theme',
    name: 'Thème : Finance',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Revenu', hexCode: '#66BB6A'), // Vert Clair
      ColorData(paletteElementId: _generateColorId(), title: 'Dépense', hexCode: '#FF7043'), // Orange
      ColorData(paletteElementId: _generateColorId(), title: 'Épargne', hexCode: '#1565C0'), // Bleu Profond
      ColorData(paletteElementId: _generateColorId(), title: 'Investissement', hexCode: '#2E7D32'), // Vert Foncé
      ColorData(paletteElementId: _generateColorId(), title: 'Crédit', hexCode: '#C62828'), // Rouge Brique
    ],
  ),

  // Thème Formation
  PaletteModel(
    id: 'formation_palette_theme',
    name: 'Thème : Formation',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Apprentissage', hexCode: '#4FC3F7'), // Bleu Ciel
      ColorData(paletteElementId: _generateColorId(), title: 'Cours', hexCode: '#FFF59D'), // Jaune Pâle
      ColorData(paletteElementId: _generateColorId(), title: 'Exercice', hexCode: '#80CBC4'), // Vert Menthe
      ColorData(paletteElementId: _generateColorId(), title: 'Révision', hexCode: '#FFCC80'), // Orange Clair
      ColorData(paletteElementId: _generateColorId(), title: 'Projet', hexCode: '#7E57C2'), // Violet
    ],
  ),

  // Thème Loisirs
  PaletteModel(
    id: 'loisirs_palette_theme',
    name: 'Thème : Loisirs',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Sorties', hexCode: '#EC407A'), // Rose Vif
      ColorData(paletteElementId: _generateColorId(), title: 'Jeux', hexCode: '#FFA726'), // Orange Ludique
      ColorData(paletteElementId: _generateColorId(), title: 'Lecture', hexCode: '#A5D6A7'), // Vert Sauge
      ColorData(paletteElementId: _generateColorId(), title: 'Créativité', hexCode: '#BA68C8'), // Violet Clair
      ColorData(paletteElementId: _generateColorId(), title: 'Voyage', hexCode: '#29B6F6'), // Bleu Azur
    ],
  ),

  // Palette Générique "Trio Éclatant"
  PaletteModel(
    id: 'generic_flashy_trio',
    name: 'Palette : Trio Éclatant',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Éclat 1', hexCode: '#FF00FF'), // Magenta Électrique
      ColorData(paletteElementId: _generateColorId(), title: 'Éclat 2', hexCode: '#39FF14'), // Vert Fluo
      ColorData(paletteElementId: _generateColorId(), title: 'Éclat 3', hexCode: '#00FFFF'), // Cyan Intense
    ],
  ),

  // Palette Générique "Douze Tons en Dégradé" (Arc-en-ciel)
  PaletteModel(
    id: 'generic_gradient_dozen',
    name: 'Palette : Douze Tons en Dégradé',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 1 (Rouge)', hexCode: '#FF0000'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 2', hexCode: '#FF4500'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 3 (Orange)', hexCode: '#FF7F00'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 4', hexCode: '#FFBF00'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 5 (Jaune)', hexCode: '#FFFF00'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 6', hexCode: '#BFFF00'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 7 (Vert)', hexCode: '#00FF00'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 8', hexCode: '#00FF7F'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 9 (Cyan)', hexCode: '#00FFFF'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 10', hexCode: '#007FFF'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 11 (Bleu)', hexCode: '#0000FF'),
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 12 (Violet)', hexCode: '#8B00FF'),
    ],
  ),

  // Palette Générique "Nuances de Bleu"
  PaletteModel(
    id: 'generic_monochromatic_blue',
    name: 'Palette : Nuances de Bleu',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Nuit', hexCode: '#001A33'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Foncé', hexCode: '#003366'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Profond', hexCode: '#0052A3'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Moyen', hexCode: '#337DCC'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Ciel', hexCode: '#66A9E0'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Clair', hexCode: '#99D5FF'),
    ],
  ),

  // Palette Générique "Tons Pastel"
  PaletteModel(
    id: 'generic_pastel_tones',
    name: 'Palette : Tons Pastel',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Rose Pâle', hexCode: '#FFD1DC'),
      ColorData(paletteElementId: _generateColorId(), title: 'Pêche Douce', hexCode: '#FFDEAD'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Vanille', hexCode: '#FFFACD'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Menthe', hexCode: '#98FB98'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Bébé', hexCode: '#E0FFFF'),
      ColorData(paletteElementId: _generateColorId(), title: 'Lilas Clair', hexCode: '#E6E6FA'),
    ],
  ),

  // NOUVEAU: Dégradés Arc-en-ciel (48 couleurs)
  PaletteModel(
    id: 'rainbow_gradients_48',
    name: 'Dégradés Arc-en-ciel (48)',
    isPredefined: true,
    colors: [
      // Rouge (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Pâle', hexCode: '#FFEBEE'),
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Clair', hexCode: '#FFCDD2'),
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge', hexCode: '#EF9A9A'),
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Moyen', hexCode: '#E57373'),
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Foncé', hexCode: '#EF5350'),
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Profond', hexCode: '#F44336'),
      // Orange (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Pâle', hexCode: '#FFF3E0'),
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Clair', hexCode: '#FFE0B2'),
      ColorData(paletteElementId: _generateColorId(), title: 'Orange', hexCode: '#FFCC80'),
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Moyen', hexCode: '#FFB74D'),
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Foncé', hexCode: '#FFA726'),
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Profond', hexCode: '#FF9800'),
      // Jaune (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Pâle', hexCode: '#FFFDE7'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Clair', hexCode: '#FFF9C4'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune', hexCode: '#FFF59D'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Moyen', hexCode: '#FFF176'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Foncé', hexCode: '#FFEE58'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Profond', hexCode: '#FFEB3B'),
      // Vert Lime (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Pâle', hexCode: '#F9FBE7'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Clair', hexCode: '#F0F4C3'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime', hexCode: '#E6EE9C'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Moyen', hexCode: '#DCE775'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Foncé', hexCode: '#D4E157'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Profond', hexCode: '#CDDC39'),
      // Vert (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Pâle', hexCode: '#E8F5E9'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Clair', hexCode: '#C8E6C9'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert', hexCode: '#A5D6A7'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Moyen', hexCode: '#81C784'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Foncé', hexCode: '#66BB6A'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Profond', hexCode: '#4CAF50'),
      // Cyan (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Pâle', hexCode: '#E0F7FA'),
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Clair', hexCode: '#B2EBF2'),
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan', hexCode: '#80DEEA'),
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Moyen', hexCode: '#4DD0E1'),
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Foncé', hexCode: '#26C6DA'),
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Profond', hexCode: '#00BCD4'),
      // Bleu (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Pâle', hexCode: '#E3F2FD'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Clair', hexCode: '#BBDEFB'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu', hexCode: '#90CAF9'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Moyen', hexCode: '#64B5F6'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Foncé', hexCode: '#42A5F5'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Profond', hexCode: '#2196F3'),
      // Violet (6 nuances)
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Pâle', hexCode: '#F3E5F5'),
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Clair', hexCode: '#E1BEE7'),
      ColorData(paletteElementId: _generateColorId(), title: 'Violet', hexCode: '#CE93D8'),
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Moyen', hexCode: '#BA68C8'),
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Foncé', hexCode: '#AB47BC'),
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Profond', hexCode: '#9C27B0'),
    ],
  ),

  // NOUVEAU: Contraste Intense (16 couleurs)
  PaletteModel(
    id: 'high_contrast_16',
    name: 'Contraste Intense (16)',
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Vif', hexCode: '#FF0000'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Roi', hexCode: '#0000CD'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Émeraude', hexCode: '#009B77'),
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Citron', hexCode: '#FFFACD'), // LemonChiffon
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Brûlé', hexCode: '#CC5500'),
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Améthyste', hexCode: '#9966CC'),
      ColorData(paletteElementId: _generateColorId(), title: 'Rose Foncé', hexCode: '#FF1493'), // DeepPink
      ColorData(paletteElementId: _generateColorId(), title: 'Turquoise Foncé', hexCode: '#00CED1'),
      ColorData(paletteElementId: _generateColorId(), title: 'Or Pur', hexCode: '#FFD700'),
      ColorData(paletteElementId: _generateColorId(), title: 'Marron Chocolat', hexCode: '#7B3F00'),
      ColorData(paletteElementId: _generateColorId(), title: 'Noir Profond', hexCode: '#000000'),
      ColorData(paletteElementId: _generateColorId(), title: 'Blanc Neige', hexCode: '#FFFFFF'),
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Vif', hexCode: '#32CD32'),
      ColorData(paletteElementId: _generateColorId(), title: 'Magenta Éclatant', hexCode: '#FF00FF'),
      ColorData(paletteElementId: _generateColorId(), title: 'Gris Ardoise', hexCode: '#708090'),
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Ciel Clair', hexCode: '#87CEEB'),
    ],
  ),
  // Ajoutez d'autres modèles prédéfinis ici si nécessaire
];
