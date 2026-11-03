import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/achievement_model.dart';

class AchievementService {
  static const List<String> _praiseImages = [
    'assets/images/praise/image 1.jpg',
    'assets/images/praise/image 3.jpg',
    'assets/images/praise/image 8.jpg',
    'assets/images/praise/image 9.jpg',
    'assets/images/praise/image 19.jpg',
    'assets/images/praise/images 2.jpg',
    'assets/images/praise/images 4.jpg',
    'assets/images/praise/images 5.jpg',
    'assets/images/praise/images 6.jpg',
    'assets/images/praise/images 7.jpg',
    'assets/images/praise/images 8.jpg',
    'assets/images/praise/images 11.jpg',
    'assets/images/praise/images 12.jpg',
    'assets/images/praise/images 13.jpg',
    'assets/images/praise/images 14.jpg',
    'assets/images/praise/images 15.jpg',
    'assets/images/praise/images 16.jpg',
    'assets/images/praise/images 17.jpg',
    'assets/images/praise/images 18.jpg',
  ];

  static const List<String> _praiseMessages = [
    "You actually did it! 🔥 Phenomenal focus!",
    "Distraction-free mastery! Keep up the momentum!",
    "Study goal unlocked! Outstanding dedication!",
    "Laser focus activated! You're unstoppable!",
    "Great job staying on task! Excellence in progress!",
    "Mission accomplished! Your focus streak is burning bright!",
  ];

  Future<AchievementModel> getCompletionAchievementAsync({
    required int focusMinutes,
    required int distractionCount,
  }) async {
    List<String> messages = List.from(_praiseMessages);
    try {
      final csvString = await rootBundle.loadString('assets/data/achievement_messages.csv');
      final lines = csvString.split('\n');
      final parsed = lines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .map((l) => l.contains('|') ? l.split('|').last.trim() : l)
          .toList();
      if (parsed.isNotEmpty) {
        messages = parsed;
      }
    } catch (_) {}

    final random = Random();
    final imagePath = _praiseImages[random.nextInt(_praiseImages.length)];
    final message = messages[random.nextInt(messages.length)];

    return AchievementModel(
      id: 'ach_${DateTime.now().millisecondsSinceEpoch}',
      title: distractionCount == 0 ? 'Flawless Focus Badge 🔥' : 'You Did It! Focus Champion 🏆',
      imagePath: imagePath,
      message: message,
      focusMinutes: focusMinutes,
      distractionCount: distractionCount,
    );
  }

  AchievementModel getCompletionAchievement({
    required int focusMinutes,
    required int distractionCount,
  }) {
    final random = Random();
    final imagePath = _praiseImages[random.nextInt(_praiseImages.length)];
    final message = _praiseMessages[random.nextInt(_praiseMessages.length)];

    return AchievementModel(
      id: 'ach_${DateTime.now().millisecondsSinceEpoch}',
      title: distractionCount == 0 ? 'Flawless Focus Badge 🔥' : 'You Did It! Focus Champion 🏆',
      imagePath: imagePath,
      message: message,
      focusMinutes: focusMinutes,
      distractionCount: distractionCount,
    );
  }
}
