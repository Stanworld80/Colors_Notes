// lib/models/color_data.dart
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
    // S'assurer que le hexCode est valide avant de tenter de le parser
    if (hexCode.isEmpty || !(hexCode.length == 6 || hexCode.length == 7 || hexCode.length == 3 || hexCode.length == 4)) {
      return const Color(0xFF808080); // Gris par défaut pour hex invalide ou vide
    }

    String cleanedHex = hexCode.replaceFirst('#', '');
    if (cleanedHex.length == 6 || cleanedHex.length == 8) { // Supporte AARRGGBB et RRGGBB
      buffer.write(cleanedHex.length == 6 ? 'ff' : ''); // Ajoute alpha si seulement RGB
      buffer.write(cleanedHex);
    } else {
      return const Color(0xFF808080); // Gris par défaut pour autres formats incorrects
    }

    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      // Log l'erreur si nécessaire, puis retourne une couleur par défaut
      // print('Erreur de parsing couleur hex "$hexCode": $e');
      return const Color(0xFF808080); // Gris par défaut en cas d'échec du parsing
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
      hexCode: map['hexCode'] as String? ?? '808080', // Default hex
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
