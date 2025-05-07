import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

class Note {
  final String id;
  final String journalId;
  final String userId;
  String content;
  final String paletteElementId;
  final Timestamp eventTimestamp;
  final Timestamp createdAt;
  Timestamp lastUpdatedAt;

  Note({
    String? id,
    required this.journalId,
    required this.userId,
    required this.content,
    required this.paletteElementId,
    required this.eventTimestamp,
    required this.createdAt,
    required this.lastUpdatedAt,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'journalId': journalId,
      'userId': userId,
      'content': content,
      'paletteElementId': paletteElementId,
      'eventTimestamp': eventTimestamp,
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, String documentId) {
    return Note(
      id: documentId,
      journalId: map['journalId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      paletteElementId: map['paletteElementId'] as String? ?? '',
      eventTimestamp: map['eventTimestamp'] as Timestamp? ?? Timestamp.now(),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      lastUpdatedAt: map['lastUpdatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Note copyWith({
    String? id,
    String? journalId,
    String? userId,
    String? content,
    String? paletteElementId,
    Timestamp? eventTimestamp,
    Timestamp? createdAt,
    Timestamp? lastUpdatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      journalId: journalId ?? this.journalId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      paletteElementId: paletteElementId ?? this.paletteElementId,
      eventTimestamp: eventTimestamp ?? this.eventTimestamp,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
