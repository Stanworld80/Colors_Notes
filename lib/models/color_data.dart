import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// A global Uuid instance for generating unique IDs.
const Uuid _uuid = Uuid();

/// Represents a single color entry within a palette.
///
/// Each [ColorData] has a unique [paletteElementId], a [title],
/// a [hexCode] for the color, and a flag [isDefault] to indicate
/// if it's a default color.
class ColorData {
  /// The unique identifier for this color element within a palette.
  /// If not provided during construction, a new UUID will be generated.
  String paletteElementId;

  /// The title or name of the color.
  String title;

  /// The hexadecimal string representation of the color (e.g., "FF0000", "#FF0000").
  String hexCode;

  /// A boolean indicating whether this color is a default color.
  /// Defaults to `false`.
  bool isDefault;

  /// Creates an instance of [ColorData].
  ///
  /// Requires [title] and [hexCode].
  /// [paletteElementId] is optional and will be auto-generated if null.
  /// [isDefault] defaults to `false`.
  ColorData({
    String? paletteElementId,
    required this.title,
    required this.hexCode,
    this.isDefault = false,
  }) : paletteElementId = paletteElementId ?? _uuid.v4();

  /// Gets the [Color] object from the [hexCode] string.
  ///
  /// It handles hex codes with or without a leading '#' and
  /// supports both RRGGBB and AARRGGBB formats.
  /// Returns a default grey color if the hex code is invalid or parsing fails.
  Color get color {
    String cleanedHex = hexCode.replaceFirst('#', '').toUpperCase();

    // Handle different lengths for parsing
    if (cleanedHex.length == 6) { // RRGGBB format
      cleanedHex = 'FF$cleanedHex'; // Add default opaque alpha
    } else if (cleanedHex.length == 8) { // AARRGGBB format
      // Already in the correct format with alpha
    } else {
      // Invalid length for a hex code without or with alpha
      return const Color(0xFF808080); // Default grey
    }

    try {
      final intValue = int.tryParse(cleanedHex, radix: 16);
      if (intValue == null) {
        return const Color(0xFF808080); // Parsing failed
      }
      return Color(intValue);
    } catch (e) {
      // Other parsing error
      return const Color(0xFF808080); // Default grey
    }
  }

  /// Converts this [ColorData] instance to a map.
  ///
  /// This is typically used for storing the data, for example, in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'paletteElementId': paletteElementId,
      'title': title,
      'hexCode': hexCode,
      'isDefault': isDefault,
    };
  }

  /// Creates a [ColorData] instance from a map (typically from Firestore).
  ///
  /// Provides default values if certain fields are missing or null in the map:
  /// - [paletteElementId]: new UUID if missing.
  /// - [title]: 'Sans titre' (Untitled) if missing.
  /// - [hexCode]: '808080' (grey) if missing.
  /// - [isDefault]: `false` if missing.
  factory ColorData.fromMap(Map<String, dynamic> map) {
    return ColorData(
      paletteElementId: map['paletteElementId'] as String? ?? _uuid.v4(),
      title: map['title'] as String? ?? 'Sans titre',
      hexCode: map['hexCode'] as String? ?? '808080',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  /// Creates a copy of this [ColorData] instance with the given fields
  /// replaced with new values.
  ColorData copyWith({
    String? paletteElementId,
    String? title,
    String? hexCode,
    bool? isDefault,
  }) {
    return ColorData(
      paletteElementId: paletteElementId ?? this.paletteElementId,
      title: title ?? this.title,
      hexCode: hexCode ?? this.hexCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
