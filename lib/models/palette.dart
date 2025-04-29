// lib/models/palette.dart
import 'color_data.dart'; // Assurez-vous d'avoir défini ColorData

class Palette {
  final String name; // Nom de la palette (souvent copié du modèle)
  final List<ColorData> colors;

  Palette({required this.name, required this.colors});

  // Méthode pour convertir cette instance en Map (pour Firestore)
  Map<String, dynamic> toJson() {
    return {'name': name, 'colors': colors.map((color) => color.toJson()).toList()};
  }

  // Méthode factory pour créer une instance Palette depuis une Map (depuis Firestore)
  factory Palette.fromJson(Map<String, dynamic> json) {
    var colorsList = json['colors'] as List<dynamic>? ?? [];
    List<ColorData> parsedColors = colorsList.map((colorJson) => ColorData.fromJson(colorJson as Map<String, dynamic>)).toList();

    return Palette(name: json['name'] ?? 'Palette sans nom', colors: parsedColors);
  }

  // Optionnel: Méthode pour créer une copie (utile pour la modification)
  Palette copyWith({String? name, List<ColorData>? colors}) {
    return Palette(
      name: name ?? this.name,
      colors: colors ?? List<ColorData>.from(this.colors.map((c) => ColorData(title: c.title, hexValue: c.hexValue))), // Copie profonde des couleurs
    );
  }
}
