import 'package:cloud_firestore/cloud_firestore.dart';

class AchievementModel {
  final String id;
  final String title;
  final String imagePath;
  final String message;
  final DateTime unlockedAt;
  final int focusMinutes;
  final int distractionCount;

  AchievementModel({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.message,
    DateTime? unlockedAt,
    this.focusMinutes = 0,
    this.distractionCount = 0,
  }) : unlockedAt = unlockedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'message': message,
      'unlockedAt': unlockedAt.toIso8601String(),
      'focusMinutes': focusMinutes,
      'distractionCount': distractionCount,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'imagePath': imagePath,
      'message': message,
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'focusMinutes': focusMinutes,
      'distractionCount': distractionCount,
    };
  }

  factory AchievementModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return AchievementModel(
      id: id.isNotEmpty ? id : (map['id'] ?? ''),
      title: map['title'] ?? '',
      imagePath: map['imagePath'] ?? '',
      message: map['message'] ?? '',
      unlockedAt: parseDate(map['unlockedAt']),
      focusMinutes: (map['focusMinutes'] as num?)?.toInt() ?? 0,
      distractionCount: (map['distractionCount'] as num?)?.toInt() ?? 0,
    );
  }
}
