import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// A global Uuid instance for generating unique IDs.
const Uuid _uuid = Uuid();

/// Represents a single note entry within a journal.
///
/// Each [Note] is associated with a specific [journalId] and [userId].
/// It contains [content], a reference to a [paletteElementId] for its color,
/// an [eventTimestamp] for when the event described in the note occurred,
/// and timestamps for its creation ([createdAt]) and last update ([lastUpdatedAt]).
class Note {
  /// The unique identifier for the note.
  /// If not provided during construction, a new UUID will be generated.
  final String id;

  /// The identifier of the journal this note belongs to.
  final String journalId;

  /// The identifier of the user who created this note.
  final String userId;

  /// The textual content of the note.
  String content;

  /// The identifier of the [ColorData] element (from the journal's palette)
  /// associated with this note.
  final String paletteElementId;

  /// The timestamp indicating when the event or subject of the note occurred.
  /// This can be different from [createdAt].
  final Timestamp eventTimestamp;

  /// The timestamp when the note was created.
  final Timestamp createdAt;

  /// The timestamp when the note was last updated.
  Timestamp lastUpdatedAt;

  /// Creates an instance of [Note].
  ///
  /// All parameters except [id] are required.
  /// If [id] is not provided, a new UUID v4 will be generated.
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

  /// Converts this [Note] instance to a map suitable for Firestore.
  ///
  /// The [id] of the note (which typically corresponds to the document ID in Firestore)
  /// is not included in the returned map itself.
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

  /// Creates a [Note] instance from a map (typically from Firestore) and a document ID.
  ///
  /// - [map]: The map containing the note data.
  /// - [documentId]: The Firestore document ID, used as the note's [id].
  ///
  /// Provides default values if certain fields are missing or null in the map:
  /// - [journalId], [userId], [content], [paletteElementId]: Defaults to an empty string if missing.
  /// - [eventTimestamp], [createdAt], [lastUpdatedAt]: Defaults to the current time ([Timestamp.now()]) if missing.
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

  /// Creates a copy of this [Note] instance with the given fields
  /// replaced with new values.
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
