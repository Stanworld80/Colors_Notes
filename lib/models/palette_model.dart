import 'package:uuid/uuid.dart';
import 'color_data.dart';

const Uuid _uuid = Uuid();

class PaletteModel {
  final String id;
  String name;
  List<ColorData> colors;
  String? userId;
  bool isPredefined;

  PaletteModel({
    String? id,
    required this.name,
    required this.colors,
    this.userId,
    this.isPredefined = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colors': colors.map((color) => color.toMap()).toList(),
      'userId': userId,
      'isPredefined': isPredefined,
    };
  }

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

  PaletteModel copyWith({
    String? id,
    String? name,
    List<ColorData>? colors,
    String? userId,
    bool? isPredefined,
  }) {
    return PaletteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colors: colors ?? this.colors.map((c) => c.copyWith()).toList(),
      userId: userId ?? this.userId,
      isPredefined: isPredefined ?? this.isPredefined,
    );
  }
}
