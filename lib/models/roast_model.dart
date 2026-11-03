class RoastModel {
  final String id;
  final int intensity;
  final String category;
  final String tone;
  final String roast;

  RoastModel({
    required this.id,
    required this.intensity,
    required this.category,
    required this.tone,
    required this.roast,
  });

  factory RoastModel.fromMap(Map<String, dynamic> map) {
    return RoastModel(
      id: map['id'] ?? '',
      intensity: map['intensity'] ?? 1,
      category: map['category'] ?? 'General',
      tone: map['tone'] ?? 'sarcastic',
      roast: map['roast'] ?? '',
    );
  }
}
