import 'color_data.dart';

class Palette {
  // Pas forcément d'ID propre si elle est toujours intégrée (embedded) dans l'Agenda
  final String name; // Nom copié du modèle ou défini
  final List<ColorData> colors;

  Palette({
    required this.name,
    required this.colors,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      // Convertit chaque ColorData en Map
      'colors': colors.map((color) => color.toJson()).toList(),
    };
  }

  factory Palette.fromJson(Map<String, dynamic> json) {
    var colorsList = json['colors'] as List<dynamic>? ?? [];
    List<ColorData> parsedColors = colorsList
        .map((colorJson) => ColorData.fromJson(colorJson as Map<String, dynamic>))
        .toList();

    return Palette(
      name: json['name'] ?? 'Palette sans nom',
      colors: parsedColors,
    );
  }
}