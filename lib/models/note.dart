// lib/models/note.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String journalId;
  final String userId;
  final String comment;
  final Timestamp createdAt;
  final Timestamp eventTimestamp;
  final String paletteElementId;

  Note({
    required this.id,
    required this.journalId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    required this.eventTimestamp,
    required this.paletteElementId,
  });

  Map<String, dynamic> toJson() {
    return {
      'journalId': journalId,
      'userId': userId,
      'comment': comment,
      'createdAt': createdAt,
      'eventTimestamp': eventTimestamp,
      'paletteElementId': paletteElementId,
    };
  }

  factory Note.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!;
    Timestamp eventTs = data['eventTimestamp'] ?? data['commentUpdatedAt'] ?? data['createdAt'] ?? Timestamp.now();
    final String elementId = data['paletteElementId'] as String? ?? 'ID_INCONNU';
    if (elementId == 'ID_INCONNU') {
      print("Note Warning: 'paletteElementId' was missing or null for note ${doc.id}. Defaulting to 'ID_INCONNU'.");
    }

    return Note(
      id: doc.id,
      journalId: data['journalId'] ?? '',
      userId: data['userId'] ?? '',
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      eventTimestamp: eventTs,
      paletteElementId: elementId,
    );
  }
}