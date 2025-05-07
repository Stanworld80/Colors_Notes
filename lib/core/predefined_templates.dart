import '../models/palette_model.dart';
import '../models/color_data.dart';

final List<PaletteModel> predefinedPalettes = [
  PaletteModel(
    id: 'template_default_pastel',
    name: 'Doux Pastel',
    isPredefined: true,
    colors: [
      ColorData(title: 'Rose Pâle', hexCode: 'FFD1DC', isDefault: true),
      ColorData(title: 'Bleu Ciel', hexCode: 'ADD8E6'),
      ColorData(title: 'Vert Menthe', hexCode: '98FB98'),
      ColorData(title: 'Lavande', hexCode: 'E6E6FA'),
      ColorData(title: 'Pêche Claire', hexCode: 'FFDAB9'),
      ColorData(title: 'Jaune Doux', hexCode: 'FFFFE0'),
    ],
  ),
  PaletteModel(
    id: 'template_vibrant_energy',
    name: 'Énergie Vibrante',
    isPredefined: true,
    colors: [
      ColorData(title: 'Rouge Vif', hexCode: 'FF0000', isDefault: true),
      ColorData(title: 'Orange Intense', hexCode: 'FFA500'),
      ColorData(title: 'Jaune Éclatant', hexCode: 'FFFF00'),
      ColorData(title: 'Vert Lime', hexCode: '32CD32'),
      ColorData(title: 'Bleu Électrique', hexCode: '0000FF'),
      ColorData(title: 'Magenta', hexCode: 'FF00FF'),
    ],
  ),
  PaletteModel(
    id: 'template_forest_calm',
    name: 'Calme Forestier',
    isPredefined: true,
    colors: [
      ColorData(title: 'Vert Forêt', hexCode: '228B22', isDefault: true),
      ColorData(title: 'Brun Terreux', hexCode: 'A0522D'),
      ColorData(title: 'Beige Sable', hexCode: 'F5F5DC'),
      ColorData(title: 'Gris Pierre', hexCode: '808080'),
      ColorData(title: 'Bleu Profond', hexCode: '000080'),
      ColorData(title: 'Vert Olive', hexCode: '808000'),
    ],
  ),
  PaletteModel(
    id: 'template_ocean_breeze',
    name: 'Brise Océanique',
    isPredefined: true,
    colors: [
      ColorData(title: 'Turquoise', hexCode: '40E0D0', isDefault: true),
      ColorData(title: 'Bleu Mer', hexCode: '1E90FF'),
      ColorData(title: 'Blanc Écume', hexCode: 'F0FFFF'),
      ColorData(title: 'Corail Doux', hexCode: 'FF7F50'),
      ColorData(title: 'Sable Doré', hexCode: 'F4A460'),
      ColorData(title: 'Gris Dauphin', hexCode: 'A9A9A9'),
    ],
  ),
];
