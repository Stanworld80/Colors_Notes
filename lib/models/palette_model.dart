import 'package:uuid/uuid.dart';
import 'color_data.dart';

/// A global Uuid instance for generating unique IDs.
const Uuid _uuid = Uuid();

/// Represents a template or model for a color palette.
///
/// A [PaletteModel] serves as a reusable structure for creating palettes.
/// It includes a unique [id], a [name], a list of [colors] ([ColorData]),
/// an optional [userId] indicating the creator, and a flag [isPredefined]
/// to mark system-provided templates.
class PaletteModel {
  /// The unique identifier for the palette model.
  /// If not provided during construction, a new UUID will be generated.
  final String id;

  /// The name of the palette model.
  String name;

  /// The list of [ColorData] objects that define the colors in this model.
  List<ColorData> colors;

  /// The identifier of the user who created or owns this palette model.
  /// This is nullable, as predefined models might not have a specific user owner.
  String? userId;

  /// A boolean indicating whether this palette model is predefined (e.g., a system template).
  /// Defaults to `false`.
  bool isPredefined;

  /// Creates an instance of [PaletteModel].
  ///
  /// Requires [name] and [colors].
  /// [id] is optional; if not provided, a new UUID v4 will be generated.
  /// [userId] is optional.
  /// [isPredefined] defaults to `false`.
  PaletteModel({
    String? id,
    required this.name,
    required this.colors,
    this.userId,
    this.isPredefined = false,
  }) : id = id ?? _uuid.v4();

  /// Converts this [PaletteModel] instance to a map suitable for Firestore.
  ///
  /// The [id] of the [PaletteModel] (which typically corresponds to the document ID in Firestore)
  /// is not included in the returned map itself.
  /// Each [ColorData] object in the [colors] list is converted to a map
  /// by calling its `toMap` method.
  Map<String, dynamic> toMap() {
    return {
      // The PaletteModel's ID (documentId) is not stored within its own map.
      'name': name,
      'colors': colors.map((color) => color.toMap()).toList(),
      'userId': userId,
      'isPredefined': isPredefined,
    };
  }

  /// Creates a [PaletteModel] instance from a map (typically from Firestore) and a document ID.
  ///
  /// - [map]: The map containing the palette model data.
  /// - [documentId]: The Firestore document ID, used as the palette model's [id].
  ///
  /// Provides default values if certain fields are missing or null in the map:
  /// - [name]: Defaults to 'Modèle sans nom' (Unnamed Model) if missing.
  /// - [colors]: Defaults to an empty list if missing; each color map is parsed
  ///   by calling `ColorData.fromMap`.
  /// - [userId]: Remains null if missing.
  /// - [isPredefined]: Defaults to `false` if missing.
  factory PaletteModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PaletteModel(
      id: documentId,
      name: map['name'] as String? ?? 'Modèle sans nom',
      colors: (map['colors'] as List<dynamic>? ?? [])
          .map((colorMap) => ColorData.fromMap(colorMap as Map<String, dynamic>))
          .toList(),
      userId: map['userId'] as String?,
      isPredefined: map['isPredefined'] as bool? ?? false,
    );
  }

  /// Creates a copy of this [PaletteModel] instance with the given fields
  /// replaced with new values.
  ///
  /// - [colors]: If provided, this list will be used. Otherwise, a deep copy of the
  ///   current [colors] list is made (each [ColorData] is copied using its `copyWith` method).
  /// - [clearUserId]: If `true`, the [userId] of the copied palette model will be set to `null`.
  ///   This parameter is included for consistency with similar models.
  ///   Otherwise, the [userId] is copied or updated as specified.
  PaletteModel copyWith({
    String? id,
    String? name,
    List<ColorData>? colors,
    String? userId,
    bool? isPredefined,
    bool clearUserId = false, // Added for consistency
  }) {
    return PaletteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colors: colors ?? this.colors.map((c) => c.copyWith()).toList(),
      userId: clearUserId ? null : (userId ?? this.userId), // Consistent logic
      isPredefined: isPredefined ?? this.isPredefined,
    );
  }
}
