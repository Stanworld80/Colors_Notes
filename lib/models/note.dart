// lib/models/note.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'color_data.dart'; // Importer ColorData

class Note {
  final String id; // ID du document Firestore
  final String journalId;
  final String userId; // Pourrait être utile pour les règles de sécurité
  final ColorData colorSnapshot; // Copie de la couleur au moment T
  final String comment;
  final Timestamp createdAt; // Date de création technique (non modifiable par l'utilisateur)
  final Timestamp eventTimestamp; // Date/heure de l'événement, MODIFIABLE par l'utilisateur

  Note({
    required this.id,
    required this.journalId,
    required this.userId,
    required this.colorSnapshot,
    required this.comment,
    required this.createdAt,
    required this.eventTimestamp, // Ancien commentUpdatedAt
  });

  Map<String, dynamic> toJson() {
    return {
      'journalId': journalId,
      'userId': userId,
      'colorSnapshot': colorSnapshot.toJson(), // Convertit ColorData en Map
      'comment': comment,
      'createdAt': createdAt, // Firestore gère les Timestamps
      'eventTimestamp': eventTimestamp, // Nouveau nom du champ
    };
  }

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    // Gérer la transition: si 'eventTimestamp' n'existe pas, utiliser 'commentUpdatedAt' ou 'createdAt'
    Timestamp eventTs = data['eventTimestamp'] ?? data['commentUpdatedAt'] ?? data['createdAt'] ?? Timestamp.now();

    return Note(
      id: doc.id,
      journalId: data['journalId'] ?? '',
      userId: data['userId'] ?? '',
      // Crée ColorData depuis la Map stockée
      colorSnapshot: ColorData.fromJson(data['colorSnapshot'] as Map<String, dynamic>? ?? {}),
      comment: data['comment'] ?? '',
      // Gérer le cas où les Timestamps pourraient être null initialement
      createdAt: data['createdAt'] ?? Timestamp.now(),
      eventTimestamp: eventTs, // Utiliser la valeur déterminée
    );
  }
}
