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
    String cleanedHex = hexCode.replaceFirst('#', '').toUpperCase();

    // Gérer différentes longueurs pour le parsing
    if (cleanedHex.length == 6) { // Format RRGGBB
      cleanedHex = 'FF$cleanedHex'; // Ajouter alpha opaque par défaut
    } else if (cleanedHex.length == 8) { // Format AARRGGBB
      // Déjà au bon format avec alpha
    } else {
      // Longueur invalide pour un code hexadécimal sans alpha ou avec alpha
      return const Color(0xFF808080); // Gris par défaut
    }

    try {
      final intValue = int.tryParse(cleanedHex, radix: 16);
      if (intValue == null) {
        return const Color(0xFF808080); // Échec du parsing
      }
      return Color(intValue);
    } catch (e) {
      // Autre erreur de parsing
      return const Color(0xFF808080); // Gris par défaut
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
