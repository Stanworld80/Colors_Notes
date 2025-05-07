import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

class ColorData {
  String paletteElementId;
  String title;
  String hexCode;
  bool isDefault;

  ColorData({
    String? paletteElementId,
    required this.title,
    required this.hexCode,
    this.isDefault = false,
  }) : paletteElementId = paletteElementId ?? _uuid.v4();

  Color get color {
    final buffer = StringBuffer();
    if (hexCode.length == 6 || hexCode.length == 7) buffer.write('ff');
    buffer.write(hexCode.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'paletteElementId': paletteElementId,
      'title': title,
      'hexCode': hexCode,
      'isDefault': isDefault,
    };
  }

  factory ColorData.fromMap(Map<String, dynamic> map) {
    return ColorData(
      paletteElementId: map['paletteElementId'] as String? ?? _uuid.v4(),
      title: map['title'] as String? ?? 'Sans titre',
      hexCode: map['hexCode'] as String? ?? '808080',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

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
