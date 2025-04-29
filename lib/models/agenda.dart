import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:colors_notes/models/palette.dart';


class Agenda {
  final String id; // ID du document Firestore
  final String name;
  final String userId; // ID de l'utilisateur propriétaire
  final Palette embeddedPaletteInstance; // Palette intégrée directement

  Agenda({
    required this.id,
    required this.name,
    required this.userId,
    required this.embeddedPaletteInstance,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'userId': userId,
      // Convertit l'objet Palette en Map
      'embeddedPaletteInstance': embeddedPaletteInstance.toJson(),
      // Ne pas inclure l'ID ici, c'est l'ID du document
    };
  }

  factory Agenda.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Agenda(
      id: doc.id,
      name: data['name'] ?? 'Agenda sans nom',
      userId: data['userId'] ?? '',
      // Crée l'objet Palette depuis la Map stockée
      embeddedPaletteInstance: Palette.fromJson(data['embeddedPaletteInstance'] as Map<String, dynamic>? ?? {}),
    );
  }
}