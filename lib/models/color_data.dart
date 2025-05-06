// lib/models/color_data.dart
import 'package:uuid/uuid.dart';

class ColorData {
  final String paletteElementId;
  String title;
  String hexValue;

  ColorData({
    String? id,
    required this.title,
    required this.hexValue,
  }) : paletteElementId = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'paletteElementId': paletteElementId,
      'title': title,
      'hexValue': hexValue,
    };
  }

  factory ColorData.fromJson(Map<String, dynamic> json) {
    return ColorData(
      id: json['paletteElementId'] as String? ?? const Uuid().v4(),
      title: json['title'] ?? 'Sans titre',
      hexValue: json['hexValue'] ?? '#FFFFFF',
    );
  }

  ColorData copyWith({
    String? title,
    String? hexValue,
  }) {
    return ColorData(
      id: paletteElementId,
      title: title ?? this.title,
      hexValue: hexValue ?? this.hexValue,
    );
  }
}