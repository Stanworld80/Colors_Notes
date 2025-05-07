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
      'name': name,
      'colors': colors.map((color) => color.toMap()).toList(),
      'isPredefined': isPredefined,
      if (userId != null) 'userId': userId,
    };
  }

  factory Palette.fromMap(Map<String, dynamic> map, String documentId) {
    return Palette(
      id: documentId,
      name: map['name'] as String? ?? 'Palette sans nom',
      colors: (map['colors'] as List<dynamic>? ?? [])
          .map((colorMap) => ColorData.fromMap(colorMap as Map<String, dynamic>))
          .toList(),
      isPredefined: map['isPredefined'] as bool? ?? false,
      userId: map['userId'] as String?,
    );
  }

  factory Palette.fromEmbeddedMap(Map<String, dynamic> map) {
    return Palette(
      id: map['id'] as String? ?? _uuid.v4(),
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
