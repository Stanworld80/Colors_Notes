// lib/models/palette.dart
import 'package:uuid/uuid.dart';
import 'color_data.dart';

const Uuid _uuid = Uuid();

class Palette {
  final String id;
  String name;
  List<ColorData> colors;
  bool isPredefined;
  String? userId;

  Palette({
    String? id,
    required this.name,
    required this.colors,
    this.isPredefined = false,
    this.userId,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id, // AJOUTÉ : L'ID de la palette est maintenant inclus
      'name': name,
      'colors': colors.map((color) => color.toMap()).toList(),
      'isPredefined': isPredefined,
      if (userId != null) 'userId': userId,
    };
  }

  factory Palette.fromMap(Map<String, dynamic> map, String documentId) {
    return Palette(
      id: documentId, // L'ID vient du document Firestore
      name: map['name'] as String? ?? 'Palette sans nom',
      colors: (map['colors'] as List<dynamic>? ?? [])
          .map((colorMap) => ColorData.fromMap(colorMap as Map<String, dynamic>))
          .toList(),
      isPredefined: map['isPredefined'] as bool? ?? false,
      userId: map['userId'] as String?,
    );
  }

  // Utilisé pour désérialiser une palette imbriquée dans un document Journal
  factory Palette.fromEmbeddedMap(Map<String, dynamic> map) {
    return Palette(
      id: map['id'] as String? ?? _uuid.v4(), // Attend un 'id' dans la map imbriquée
      name: map['name'] as String? ?? 'Palette sans nom',
      colors: (map['colors'] as List<dynamic>? ?? [])
          .map((colorMap) => ColorData.fromMap(colorMap as Map<String, dynamic>))
          .toList(),
      isPredefined: map['isPredefined'] as bool? ?? false,
      userId: map['userId'] as String?,
    );
  }


  Palette copyWith({
    String? id,
    String? name,
    List<ColorData>? colors,
    bool? isPredefined,
    String? userId,
    bool clearUserId = false,
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
