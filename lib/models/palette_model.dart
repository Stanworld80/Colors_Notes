
import 'package:cloud_firestore/cloud_firestore.dart';
import 'color_data.dart';

class PaletteModel {
  final String id; // ID du document Firestore
  final String userId;
  final String name;
  final List<ColorData> colors;

  PaletteModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.colors,
  });

  // Limites de taille (SF-PALETTE-04)
  static const int minColors = 3;
  static const int maxColors = 48;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'colors': colors.map((c) => c.toJson()).toList(),
    };
  }

  factory PaletteModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    var colorsList = data['colors'] as List<dynamic>? ?? [];
    List<ColorData> parsedColors = colorsList
        .map((json) => ColorData.fromJson(json as Map<String, dynamic>))
        .toList();

    return PaletteModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? 'Modèle sans nom',
      colors: parsedColors,
    );
  }
}