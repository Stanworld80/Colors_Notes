import '../models/palette_model.dart';
import '../models/color_data.dart';
import 'package:uuid/uuid.dart';

/// Generates a unique ID for new [ColorData] instances within predefined palettes.
///
/// This ensures that each color definition within a template has a stable, unique identifier.
/// While these `paletteElementId`s are unique within their template definition,
/// they are typically replaced with new UUIDs when a template is used to instantiate
/// a new [Palette] for a [Journal], ensuring instance uniqueness for colors in user journals.
String _generateColorId() => const Uuid().v4();

/// A list of predefined [PaletteModel]s available to all users.
///
/// These palettes serve as starting points or templates when users create new
/// journals or new personal palette models. Each model has a unique `id` (for the model itself),
/// a `name` (often in French, reflecting the UI language of the original design),
/// an `isPredefined` flag set to true, and a list of [ColorData] objects.
/// Each [ColorData] within these predefined models is assigned a unique `paletteElementId`
/// via [_generateColorId] at the time of this list's definition.
List<PaletteModel> predefinedPalettes = [
  // Default Palette (existing)
  // This palette provides a basic set of colors for general use.
  PaletteModel(
    id: 'default_palette_1', // Unique ID for this predefined PaletteModel
    name: 'Palette par Défaut', // UI Text in French: "Default Palette"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Content', hexCode: '#FFEB3B'), // Jaune (Yellow)
      ColorData(paletteElementId: _generateColorId(), title: 'Normal', hexCode: '#AED581'), // Vert clair (Light Green)
      ColorData(paletteElementId: _generateColorId(), title: 'Fatigué', hexCode: '#FF7043'), // Orange corail (Coral Orange) - UI Text in French: "Tired"
      ColorData(paletteElementId: _generateColorId(), title: 'Stressé', hexCode: '#F44336'), // Rouge (Red) - UI Text in French: "Stressed"
      ColorData(paletteElementId: _generateColorId(), title: 'Inspiré', hexCode: '#2196F3'), // Bleu (Blue) - UI Text in French: "Inspired"
    ],
  ),

  // Sport Theme Palette
  // A palette designed for logging activities and feelings related to sports.
  PaletteModel(
    id: 'sport_palette_theme',
    name: 'Thème : Sport', // UI Text in French: "Theme: Sport"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Force', hexCode: '#B71C1C'), // Rouge Foncé (Dark Red) - UI Text in French: "Strength"
      ColorData(paletteElementId: _generateColorId(), title: 'Endurance', hexCode: '#FF9800'), // Orange - UI Text in French: "Endurance"
      ColorData(paletteElementId: _generateColorId(), title: 'Cardio', hexCode: '#FFEE58'), // Jaune Vif (Bright Yellow)
      ColorData(paletteElementId: _generateColorId(), title: 'Étirement', hexCode: '#81D4FA'), // Bleu Ciel (Sky Blue) - UI Text in French: "Stretching"
      ColorData(paletteElementId: _generateColorId(), title: 'Récupération', hexCode: '#AED581'), // Vert Clair (Light Green) - UI Text in French: "Recovery"
    ],
  ),

  // Health Theme Palette
  // A palette focused on health-related events and tracking.
  PaletteModel(
    id: 'sante_palette_theme',
    name: 'Thème : Santé', // UI Text in French: "Theme: Health"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'RDV Médecin', hexCode: '#64B5F6'), // Bleu Hôpital (Hospital Blue) - UI Text in French: "Doctor's Appointment"
      ColorData(paletteElementId: _generateColorId(), title: 'Examen Médical', hexCode: '#81C784'), // Vert Pharmacie (Pharmacy Green) - UI Text in French: "Medical Exam"
      ColorData(paletteElementId: _generateColorId(), title: 'Traitement', hexCode: '#FFB74D'), // Orange Doux (Soft Orange) - UI Text in French: "Treatment"
      ColorData(paletteElementId: _generateColorId(), title: 'Bien-être', hexCode: '#4DB6AC'), // Turquoise - UI Text in French: "Well-being"
      ColorData(paletteElementId: _generateColorId(), title: 'Urgence', hexCode: '#E53935'), // Rouge Vif (Bright Red) - UI Text in French: "Emergency"
    ],
  ),

  // Mood Theme Palette
  // A palette for tracking different moods and emotional states.
  PaletteModel(
    id: 'humeur_palette_theme',
    name: 'Thème : Humeur', // UI Text in French: "Theme: Mood"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Joyeux', hexCode: '#FFF176'), // Jaune Soleil (Sunny Yellow) - UI Text in French: "Happy"
      ColorData(paletteElementId: _generateColorId(), title: 'Calme', hexCode: '#9FA8DA'), // Bleu Lavande (Lavender Blue) - UI Text in French: "Calm"
      ColorData(paletteElementId: _generateColorId(), title: 'Neutre', hexCode: '#E0E0E0'), // Gris Clair (Light Gray) - UI Text in French: "Neutral"
      ColorData(paletteElementId: _generateColorId(), title: 'Triste', hexCode: '#3949AB'), // Bleu Foncé (Dark Blue) - UI Text in French: "Sad"
      ColorData(paletteElementId: _generateColorId(), title: 'Colère', hexCode: '#F44336'), // Rouge Vif (Bright Red) - UI Text in French: "Anger"
      ColorData(paletteElementId: _generateColorId(), title: 'Stressé', hexCode: '#FB8C00'), // Orange Foncé (Dark Orange) - UI Text in French: "Stressed"
    ],
  ),

  // Finance Theme Palette
  // A palette for financial tracking, such as income and expenses.
  PaletteModel(
    id: 'finance_palette_theme',
    name: 'Thème : Finance', // UI Text in French: "Theme: Finance"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Revenu', hexCode: '#66BB6A'), // Vert Clair (Light Green) - UI Text in French: "Income"
      ColorData(paletteElementId: _generateColorId(), title: 'Dépense', hexCode: '#FF7043'), // Orange - UI Text in French: "Expense"
      ColorData(paletteElementId: _generateColorId(), title: 'Épargne', hexCode: '#1565C0'), // Bleu Profond (Deep Blue) - UI Text in French: "Savings"
      ColorData(paletteElementId: _generateColorId(), title: 'Investissement', hexCode: '#2E7D32'), // Vert Foncé (Dark Green) - UI Text in French: "Investment"
      ColorData(paletteElementId: _generateColorId(), title: 'Crédit', hexCode: '#C62828'), // Rouge Brique (Brick Red) - UI Text in French: "Credit"
    ],
  ),

  // Training/Education Theme Palette
  // A palette suitable for notes related to learning, courses, and studies.
  PaletteModel(
    id: 'formation_palette_theme',
    name: 'Thème : Formation', // UI Text in French: "Theme: Training/Education"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Apprentissage', hexCode: '#4FC3F7'), // Bleu Ciel (Sky Blue) - UI Text in French: "Learning"
      ColorData(paletteElementId: _generateColorId(), title: 'Cours', hexCode: '#FFF59D'), // Jaune Pâle (Pale Yellow) - UI Text in French: "Course"
      ColorData(paletteElementId: _generateColorId(), title: 'Exercice', hexCode: '#80CBC4'), // Vert Menthe (Mint Green) - UI Text in French: "Exercise"
      ColorData(paletteElementId: _generateColorId(), title: 'Révision', hexCode: '#FFCC80'), // Orange Clair (Light Orange) - UI Text in French: "Revision"
      ColorData(paletteElementId: _generateColorId(), title: 'Projet', hexCode: '#7E57C2'), // Violet (Purple) - UI Text in French: "Project"
    ],
  ),

  // Leisure/Hobbies Theme Palette
  // A palette for activities related to leisure, games, and creativity.
  PaletteModel(
    id: 'loisirs_palette_theme',
    name: 'Thème : Loisirs', // UI Text in French: "Theme: Leisure"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Sorties', hexCode: '#EC407A'), // Rose Vif (Bright Pink) - UI Text in French: "Outings"
      ColorData(paletteElementId: _generateColorId(), title: 'Jeux', hexCode: '#FFA726'), // Orange Ludique (Playful Orange) - UI Text in French: "Games"
      ColorData(paletteElementId: _generateColorId(), title: 'Lecture', hexCode: '#A5D6A7'), // Vert Sauge (Sage Green) - UI Text in French: "Reading"
      ColorData(paletteElementId: _generateColorId(), title: 'Créativité', hexCode: '#BA68C8'), // Violet Clair (Light Purple) - UI Text in French: "Creativity"
      ColorData(paletteElementId: _generateColorId(), title: 'Voyage', hexCode: '#29B6F6'), // Bleu Azur (Azure Blue) - UI Text in French: "Travel"
    ],
  ),

  // Generic Palette: "Flashy Trio"
  // A small, vibrant palette with three contrasting colors.
  PaletteModel(
    id: 'generic_flashy_trio',
    name: 'Palette : Trio Éclatant', // UI Text in French: "Palette: Flashy Trio"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Éclat 1', hexCode: '#FF00FF'), // Magenta Électrique (Electric Magenta) - UI Text in French: "Sparkle 1"
      ColorData(paletteElementId: _generateColorId(), title: 'Éclat 2', hexCode: '#39FF14'), // Vert Fluo (Fluorescent Green) - UI Text in French: "Sparkle 2"
      ColorData(paletteElementId: _generateColorId(), title: 'Éclat 3', hexCode: '#00FFFF'), // Cyan Intense (Intense Cyan) - UI Text in French: "Sparkle 3"
    ],
  ),

  // Generic Palette: "Twelve Gradient Tones" (Rainbow)
  // A larger palette representing a rainbow gradient with twelve distinct tones.
  PaletteModel(
    id: 'generic_gradient_dozen',
    name: 'Palette : Douze Tons en Dégradé', // UI Text in French: "Palette: Twelve Gradient Tones"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 1 (Rouge)', hexCode: '#FF0000'), // UI Text in French: "Tone 1 (Red)"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 2', hexCode: '#FF4500'), // UI Text in French: "Tone 2"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 3 (Orange)', hexCode: '#FF7F00'), // UI Text in French: "Tone 3 (Orange)"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 4', hexCode: '#FFBF00'), // UI Text in French: "Tone 4"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 5 (Jaune)', hexCode: '#FFFF00'), // UI Text in French: "Tone 5 (Yellow)"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 6', hexCode: '#BFFF00'), // UI Text in French: "Tone 6"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 7 (Vert)', hexCode: '#00FF00'), // UI Text in French: "Tone 7 (Green)"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 8', hexCode: '#00FF7F'), // UI Text in French: "Tone 8"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 9 (Cyan)', hexCode: '#00FFFF'), // UI Text in French: "Tone 9 (Cyan)"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 10', hexCode: '#007FFF'), // UI Text in French: "Tone 10"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 11 (Bleu)', hexCode: '#0000FF'), // UI Text in French: "Tone 11 (Blue)"
      ColorData(paletteElementId: _generateColorId(), title: 'Ton 12 (Violet)', hexCode: '#8B00FF'), // UI Text in French: "Tone 12 (Purple)"
    ],
  ),

  // Generic Palette: "Shades of Blue"
  // A monochromatic palette featuring various shades of blue.
  PaletteModel(
    id: 'generic_monochromatic_blue',
    name: 'Palette : Nuances de Bleu', // UI Text in French: "Palette: Shades of Blue"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Nuit', hexCode: '#001A33'), // UI Text in French: "Night Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Foncé', hexCode: '#003366'), // UI Text in French: "Dark Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Profond', hexCode: '#0052A3'), // UI Text in French: "Deep Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Moyen', hexCode: '#337DCC'), // UI Text in French: "Medium Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Ciel', hexCode: '#66A9E0'), // UI Text in French: "Sky Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Clair', hexCode: '#99D5FF'), // UI Text in French: "Light Blue"
    ],
  ),

  // Generic Palette: "Pastel Tones"
  // A palette composed of soft, light pastel colors.
  PaletteModel(
    id: 'generic_pastel_tones',
    name: 'Palette : Tons Pastel', // UI Text in French: "Palette: Pastel Tones"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Rose Pâle', hexCode: '#FFD1DC'), // UI Text in French: "Pale Pink"
      ColorData(paletteElementId: _generateColorId(), title: 'Pêche Douce', hexCode: '#FFDEAD'), // UI Text in French: "Soft Peach"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Vanille', hexCode: '#FFFACD'), // UI Text in French: "Vanilla Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Menthe', hexCode: '#98FB98'), // UI Text in French: "Mint Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Bébé', hexCode: '#E0FFFF'), // UI Text in French: "Baby Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Lilas Clair', hexCode: '#E6E6FA'), // UI Text in French: "Light Lilac"
    ],
  ),

  // NEW: Rainbow Gradients (48 colors)
  // An extensive palette offering a wide range of colors across the rainbow spectrum,
  // with multiple shades for each primary color group. This allows for detailed color coding.
  PaletteModel(
    id: 'rainbow_gradients_48',
    name: 'Dégradés Arc-en-ciel (48)', // UI Text in French: "Rainbow Gradients (48)"
    isPredefined: true,
    colors: [
      // Red (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Pâle', hexCode: '#FFEBEE'), // UI Text in French: "Pale Red"
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Clair', hexCode: '#FFCDD2'), // UI Text in French: "Light Red"
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge', hexCode: '#EF9A9A'), // UI Text in French: "Red"
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Moyen', hexCode: '#E57373'), // UI Text in French: "Medium Red"
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Foncé', hexCode: '#EF5350'), // UI Text in French: "Dark Red"
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Profond', hexCode: '#F44336'), // UI Text in French: "Deep Red"
      // Orange (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Pâle', hexCode: '#FFF3E0'), // UI Text in French: "Pale Orange"
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Clair', hexCode: '#FFE0B2'), // UI Text in French: "Light Orange"
      ColorData(paletteElementId: _generateColorId(), title: 'Orange', hexCode: '#FFCC80'), // UI Text in French: "Orange"
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Moyen', hexCode: '#FFB74D'), // UI Text in French: "Medium Orange"
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Foncé', hexCode: '#FFA726'), // UI Text in French: "Dark Orange"
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Profond', hexCode: '#FF9800'), // UI Text in French: "Deep Orange"
      // Yellow (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Pâle', hexCode: '#FFFDE7'), // UI Text in French: "Pale Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Clair', hexCode: '#FFF9C4'), // UI Text in French: "Light Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune', hexCode: '#FFF59D'), // UI Text in French: "Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Moyen', hexCode: '#FFF176'), // UI Text in French: "Medium Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Foncé', hexCode: '#FFEE58'), // UI Text in French: "Dark Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Profond', hexCode: '#FFEB3B'), // UI Text in French: "Deep Yellow"
      // Lime Green (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Pâle', hexCode: '#F9FBE7'), // UI Text in French: "Pale Lime Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Clair', hexCode: '#F0F4C3'), // UI Text in French: "Light Lime Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime', hexCode: '#E6EE9C'), // UI Text in French: "Lime Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Moyen', hexCode: '#DCE775'), // UI Text in French: "Medium Lime Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Foncé', hexCode: '#D4E157'), // UI Text in French: "Dark Lime Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Profond', hexCode: '#CDDC39'), // UI Text in French: "Deep Lime Green"
      // Green (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Pâle', hexCode: '#E8F5E9'), // UI Text in French: "Pale Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Clair', hexCode: '#C8E6C9'), // UI Text in French: "Light Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert', hexCode: '#A5D6A7'), // UI Text in French: "Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Moyen', hexCode: '#81C784'), // UI Text in French: "Medium Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Foncé', hexCode: '#66BB6A'), // UI Text in French: "Dark Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Profond', hexCode: '#4CAF50'), // UI Text in French: "Deep Green"
      // Cyan (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Pâle', hexCode: '#E0F7FA'), // UI Text in French: "Pale Cyan"
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Clair', hexCode: '#B2EBF2'), // UI Text in French: "Light Cyan"
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan', hexCode: '#80DEEA'), // UI Text in French: "Cyan"
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Moyen', hexCode: '#4DD0E1'), // UI Text in French: "Medium Cyan"
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Foncé', hexCode: '#26C6DA'), // UI Text in French: "Dark Cyan"
      ColorData(paletteElementId: _generateColorId(), title: 'Cyan Profond', hexCode: '#00BCD4'), // UI Text in French: "Deep Cyan"
      // Blue (6 shades)
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Pâle', hexCode: '#E3F2FD'), // UI Text in French: "Pale Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Clair', hexCode: '#BBDEFB'), // UI Text in French: "Light Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu', hexCode: '#90CAF9'), // UI Text in French: "Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Moyen', hexCode: '#64B5F6'), // UI Text in French: "Medium Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Foncé', hexCode: '#42A5F5'), // UI Text in French: "Dark Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Profond', hexCode: '#2196F3'), // UI Text in French: "Deep Blue"
      // Purple (6 shades) - Note: "Violet" is French for Purple.
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Pâle', hexCode: '#F3E5F5'), // UI Text in French: "Pale Purple"
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Clair', hexCode: '#E1BEE7'), // UI Text in French: "Light Purple"
      ColorData(paletteElementId: _generateColorId(), title: 'Violet', hexCode: '#CE93D8'), // UI Text in French: "Purple"
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Moyen', hexCode: '#BA68C8'), // UI Text in French: "Medium Purple"
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Foncé', hexCode: '#AB47BC'), // UI Text in French: "Dark Purple"
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Profond', hexCode: '#9C27B0'), // UI Text in French: "Deep Purple"
    ],
  ),

  // NEW: Intense Contrast (16 colors)
  // A palette featuring a set of 16 high-contrast colors, useful for accessibility
  // or when distinct visual separation is needed.
  PaletteModel(
    id: 'high_contrast_16',
    name: 'Contraste Intense (16)', // UI Text in French: "Intense Contrast (16)"
    isPredefined: true,
    colors: [
      ColorData(paletteElementId: _generateColorId(), title: 'Rouge Vif', hexCode: '#FF0000'), // UI Text in French: "Bright Red"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Roi', hexCode: '#0000CD'), // UI Text in French: "Royal Blue"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Émeraude', hexCode: '#009B77'), // UI Text in French: "Emerald Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Jaune Citron', hexCode: '#FFFACD'), // LemonChiffon - UI Text in French: "Lemon Yellow"
      ColorData(paletteElementId: _generateColorId(), title: 'Orange Brûlé', hexCode: '#CC5500'), // UI Text in French: "Burnt Orange"
      ColorData(paletteElementId: _generateColorId(), title: 'Violet Améthyste', hexCode: '#9966CC'), // UI Text in French: "Amethyst Purple"
      ColorData(paletteElementId: _generateColorId(), title: 'Rose Foncé', hexCode: '#FF1493'), // DeepPink - UI Text in French: "Dark Pink"
      ColorData(paletteElementId: _generateColorId(), title: 'Turquoise Foncé', hexCode: '#00CED1'), // UI Text in French: "Dark Turquoise"
      ColorData(paletteElementId: _generateColorId(), title: 'Or Pur', hexCode: '#FFD700'), // UI Text in French: "Pure Gold"
      ColorData(paletteElementId: _generateColorId(), title: 'Marron Chocolat', hexCode: '#7B3F00'), // UI Text in French: "Chocolate Brown"
      ColorData(paletteElementId: _generateColorId(), title: 'Noir Profond', hexCode: '#000000'), // UI Text in French: "Deep Black"
      ColorData(paletteElementId: _generateColorId(), title: 'Blanc Neige', hexCode: '#FFFFFF'), // UI Text in French: "Snow White"
      ColorData(paletteElementId: _generateColorId(), title: 'Vert Lime Vif', hexCode: '#32CD32'), // UI Text in French: "Bright Lime Green"
      ColorData(paletteElementId: _generateColorId(), title: 'Magenta Éclatant', hexCode: '#FF00FF'), // UI Text in French: "Radiant Magenta"
      ColorData(paletteElementId: _generateColorId(), title: 'Gris Ardoise', hexCode: '#708090'), // UI Text in French: "Slate Gray"
      ColorData(paletteElementId: _generateColorId(), title: 'Bleu Ciel Clair', hexCode: '#87CEEB'), // UI Text in French: "Light Sky Blue"
    ],
  ),
  // Add other predefined models here if necessary
];
