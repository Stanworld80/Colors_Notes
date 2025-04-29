// lib/core/predefined_templates.dart
import '../models/color_data.dart';
import '../models/palette.dart'; // Utiliser Palette pour la structure

// Modèles de Palettes Génériques (SF-TEMPLATE-02)
final predefinedGenericPalettes = <String, List<ColorData>>{
  'Palette simple 4 couleurs': [
    ColorData(title: 'Tomato', hexValue: '#FF6347'), // Tomato
    ColorData(title: 'SteelBlue', hexValue: '#4682B4'), // SteelBlue
    ColorData(title: 'LimeGreen', hexValue: '#32CD32'), // LimeGreen
    ColorData(title: 'Gold', hexValue: '#FFD700'), // Gold
  ],
  'Palette neutre (6 couleurs)': [
    ColorData(title: 'Gris 1', hexValue: '#D3D3D3'),
    ColorData(title: 'Gris 2', hexValue: '#A9A9A9'),
    ColorData(title: 'Gris 3', hexValue: '#808080'),
    ColorData(title: 'Beige 1', hexValue: '#F5F5DC'),
    ColorData(title: 'Beige 2', hexValue: '#FFE4C4'),
    ColorData(title: 'Blanc Cassé', hexValue: '#FAF0E6'),
  ],
  // Ajoutez d'autres modèles génériques ici
};

// Modèles d'Agendas Thématiques (SF-TEMPLATE-01)
class PredefinedAgendaTemplate {
  final String templateName;
  final String suggestedAgendaName;
  final Palette paletteDefinition;

  PredefinedAgendaTemplate({
    required this.templateName,
    required this.suggestedAgendaName,
    required this.paletteDefinition,
  });
}

final predefinedAgendaTemplates = <PredefinedAgendaTemplate>[
  PredefinedAgendaTemplate(
    templateName: 'Sport',
    suggestedAgendaName: 'Mon Suivi Sportif',
    paletteDefinition: Palette(name: 'Palette Sport', colors: [
      ColorData(title: 'Endurance', hexValue: '#4682B4'),
      ColorData(title: 'Force', hexValue: '#B22222'),
      ColorData(title: 'Repos', hexValue: '#90EE90'),
      ColorData(title: 'Compétition', hexValue: '#FFD700'),
      ColorData(title: 'Motivation', hexValue: '#FF4500'),
    ]),
  ),
  PredefinedAgendaTemplate(
    templateName: 'Humeur',
    suggestedAgendaName: 'Mon Journal d\'Humeur',
    paletteDefinition: Palette(name: 'Palette Humeur', colors: [
      ColorData(title: 'Joyeux', hexValue: '#FFFF00'),
      ColorData(title: 'Calme', hexValue: '#ADD8E6'),
      ColorData(title: 'Triste', hexValue: '#696969'),
      ColorData(title: 'En colère', hexValue: '#DC143C'),
      ColorData(title: 'Énergique', hexValue: '#FFA500'),
      ColorData(title: 'Stressé', hexValue: '#8B0000'),
    ]),
  ),
  // Ajoutez d'autres modèles thématiques ici
];