class ColorData {
  final String title;
  final String hexValue; // ex: '#FF0000' ou 'FFFF0000' (avec alpha)
  // Peut-être un ID unique si nécessaire pour la gestion au sein d'une palette
  // final String id;

  ColorData({
    required this.title,
    required this.hexValue,
    // required this.id
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'hexValue': hexValue,
      // 'id': id,
    };
  }

  factory ColorData.fromJson(Map<String, dynamic> json) {
    return ColorData(
      title: json['title'] ?? 'Sans titre',
      hexValue: json['hexValue'] ?? '#FFFFFF', // Blanc par défaut ?
      // id: json['id'] ?? '',
    );
  }
}
