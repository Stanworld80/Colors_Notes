import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'palette.dart';

/// A global Uuid instance for generating unique IDs.
const Uuid _uuid = Uuid();

/// Represents a user's journal.
///
/// Each journal has a unique [id], an associated [userId], a [name],
/// a [palette] of colors, and timestamps for creation and last update.
class Journal {
  /// The unique identifier for the journal.
  /// If not provided during construction, a new UUID will be generated.
  final String id;

  /// The identifier of the user who owns this journal.
  final String userId;

  /// The name of the journal.
  String name;

  /// The color palette associated with this journal.
  Palette palette;

  /// The timestamp when the journal was created.
  final Timestamp createdAt;

  /// The timestamp when the journal was last updated.
  Timestamp lastUpdatedAt;

  /// Creates an instance of [Journal].
  ///
  /// The [userId], [name], [palette], [createdAt], and [lastUpdatedAt] are required.
  /// The [id] is optional; if not provided, a new UUID v4 will be generated.
  Journal({
    String? id,
    required this.userId,
    required this.name,
    required this.palette,
    required this.createdAt,
    required this.lastUpdatedAt,
  }) : id = id ?? _uuid.v4();

  /// Converts this [Journal] instance to a map suitable for Firestore.
  ///
  /// The [id] is not included as it's typically used as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'palette': palette.toMap(),
      'createdAt': createdAt,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }

  /// Creates a [Journal] instance from a map (typically from Firestore) and a document ID.
  ///
  /// - [map]: The map containing the journal data.
  /// - [documentId]: The Firestore document ID, used as the journal's [id].
  ///
  /// Provides default values if certain fields are missing or null in the map:
  /// - [userId]: Defaults to an empty string if missing.
  /// - [name]: Defaults to 'Journal sans nom' (Unnamed Journal) if missing.
  /// - [palette]: Defaults to a new [Palette] with a default name,
  ///   empty colors, and the journal's [userId] if missing or null.
  /// - [createdAt]: Defaults to the current time ([Timestamp.now()]) if missing.
  /// - [lastUpdatedAt]: Defaults to the current time ([Timestamp.now()]) if missing.
  factory Journal.fromMap(Map<String, dynamic> map, String documentId) {
    return Journal(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'Journal sans nom',
      palette: map['palette'] != null
          ? Palette.fromEmbeddedMap(map['palette'] as Map<String, dynamic>)
      // Assumes Palette has a fromEmbeddedMap factory constructor
          : Palette(id: _uuid.v4(), name: "Palette par défaut", colors: [], userId: map['userId'] as String?),
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      lastUpdatedAt: map['lastUpdatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Creates a copy of this [Journal] instance with the given fields
  /// replaced with new values.
  ///
  /// If [palette] is provided, it will be used; otherwise, a copy of the
  /// current [palette] is created using its `copyWith` method.
  Journal copyWith({
    String? id,
    String? userId,
    String? name,
    Palette? palette,
    Timestamp? createdAt,
    Timestamp? lastUpdatedAt,
  }) {
    return Journal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      palette: palette ?? this.palette.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
