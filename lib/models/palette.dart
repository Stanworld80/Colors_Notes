import 'package:uuid/uuid.dart';
import 'color_data.dart';

/// A global Uuid instance for generating unique IDs.
const Uuid _uuid = Uuid();

/// Represents a color palette.
///
/// A palette has a unique [id], a [name], a list of [colors] ([ColorData]),
/// a flag [isPredefined] to indicate if it's a system-defined palette,
/// and an optional [userId] if it's a user-specific palette.
class Palette {
  /// The unique identifier for the palette.
  /// If not provided during construction, a new UUID will be generated.
  final String id;

  /// The name of the palette.
  String name;

  /// The list of [ColorData] objects belonging to this palette.
  List<ColorData> colors;

  /// A boolean indicating whether this palette is predefined (e.g., a system template).
  /// Defaults to `false`.
  bool isPredefined;

  /// The identifier of the user who owns this palette.
  /// This is nullable, as predefined palettes might not have a specific owner.
  String? userId;

  /// Creates an instance of [Palette].
  ///
  /// Requires [name] and [colors].
  /// [id] is optional; if not provided, a new UUID v4 will be generated.
  /// [isPredefined] defaults to `false`.
  /// [userId] is optional.
  Palette({
    String? id,
    required this.name,
    required this.colors,
    this.isPredefined = false,
    this.userId,
  }) : id = id ?? _uuid.v4();

  /// Converts this [Palette] instance to a map suitable for Firestore.
  ///
  /// Includes the palette's [id], [name], list of [colors] (converted to maps),
  /// [isPredefined] status, and [userId] if present.
  Map<String, dynamic> toMap() {
    return {
      'id': id, // The ID of the palette is now included
      'name': name,
      'colors': colors.map((color) => color.toMap()).toList(),
      'isPredefined': isPredefined,
      if (userId != null) 'userId': userId,
    };
  }

  /// Creates a [Palette] instance from a map (typically from Firestore) and a document ID.
  ///
  /// - [map]: The map containing the palette data.
  /// - [documentId]: The Firestore document ID, used as the palette's [id].
  ///
  /// Provides default values if certain fields are missing or null in the map:
  /// - [name]: Defaults to 'Palette sans nom' (Unnamed Palette) if missing.
  /// - [colors]: Defaults to an empty list if missing; each color map is parsed using [ColorData.fromMap].
  /// - [isPredefined]: Defaults to `false` if missing.
  /// - [userId]: Remains null if missing.
  factory Palette.fromMap(Map<String, dynamic> map, String documentId) {
    return Palette(
      id: documentId, // The ID comes from the Firestore document
      name: map['name'] as String? ?? 'Palette sans nom',
      colors: (map['colors'] as List<dynamic>? ?? [])
          .map((colorMap) => ColorData.fromMap(colorMap as Map<String, dynamic>))
          .toList(),
      isPredefined: map['isPredefined'] as bool? ?? false,
      userId: map['userId'] as String?,
    );
  }

  /// Creates a [Palette] instance from an embedded map (e.g., when a palette is part of another document like a Journal).
  ///
  /// - [map]: The map containing the embedded palette data.
  ///
  /// Expects an 'id' field within the [map] for the palette.
  /// Provides default values if certain fields are missing or null:
  /// - [id]: Generates a new UUID if 'id' is missing in the map.
  /// - [name]: Defaults to 'Palette sans nom' (Unnamed Palette) if missing.
  /// - [colors]: Defaults to an empty list if missing; each color map is parsed using [ColorData.fromMap].
  /// - [isPredefined]: Defaults to `false` if missing.
  /// - [userId]: Remains null if missing.
  factory Palette.fromEmbeddedMap(Map<String, dynamic> map) {
    return Palette(
      id: map['id'] as String? ?? _uuid.v4(), // Expects an 'id' in the embedded map
      name: map['name'] as String? ?? 'Palette sans nom',
      colors: (map['colors'] as List<dynamic>? ?? [])
          .map((colorMap) => ColorData.fromMap(colorMap as Map<String, dynamic>))
          .toList(),
      isPredefined: map['isPredefined'] as bool? ?? false,
      userId: map['userId'] as String?,
    );
  }


  /// Creates a copy of this [Palette] instance with the given fields
  /// replaced with new values.
  ///
  /// - [colors]: If provided, this list will be used. Otherwise, a deep copy of the
  ///   current [colors] list is made (each [ColorData] is copied using its `copyWith` method).
  /// - [clearUserId]: If `true`, the [userId] of the copied palette will be set to `null`.
  ///   Otherwise, the [userId] is copied or updated as specified.
  Palette copyWith({
    String? id,
    String? name,
    List<ColorData>? colors,
    bool? isPredefined,
    String? userId,
    bool clearUserId = false, // New parameter to explicitly clear userId
  }) {
    return Palette(
      id: id ?? this.id,
      name: name ?? this.name,
      colors: colors ?? this.colors.map((c) => c.copyWith()).toList(),
      isPredefined: isPredefined ?? this.isPredefined,
      userId: clearUserId ? null : (userId ?? this.userId),
    );
  }
}
