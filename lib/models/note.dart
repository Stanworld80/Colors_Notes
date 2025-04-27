import 'package:cloud_firestore/cloud_firestore.dart';
import 'color_data.dart'; // Importer ColorData

class Note {
  final String id; // ID du document Firestore
  final String agendaId;
  final String userId; // Pourrait être utile pour les règles de sécurité
  final ColorData colorSnapshot; // Copie de la couleur au moment T
  final String comment;
  final Timestamp createdAt; // Utiliser Timestamp de Firestore
  final Timestamp commentUpdatedAt; // Date de dernière modif commentaire

  Note({
    required this.id,
    required this.agendaId,
    required this.userId,
    required this.colorSnapshot,
    required this.comment,
    required this.createdAt,
    required this.commentUpdatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'agendaId': agendaId,
      'userId': userId,
      'colorSnapshot': colorSnapshot.toJson(), // Convertit ColorData en Map
      'comment': comment,
      'createdAt': createdAt, // Firestore gère les Timestamps
      'commentUpdatedAt': commentUpdatedAt,
    };
  }

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    return Note(
      id: doc.id,
      agendaId: data['agendaId'] ?? '',
      userId: data['userId'] ?? '',
      // Crée ColorData depuis la Map stockée
      colorSnapshot: ColorData.fromJson(data['colorSnapshot'] as Map<String, dynamic>? ?? {}),
      comment: data['comment'] ?? '',
      // Gérer le cas où les Timestamps pourraient être null initialement
      createdAt: data['createdAt'] ?? Timestamp.now(),
      commentUpdatedAt: data['commentUpdatedAt'] ?? data['createdAt'] ?? Timestamp.now(),
    );
  }
}