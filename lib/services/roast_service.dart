import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../core/config/app_config.dart';
import '../core/utils/csv_parser.dart';
import '../models/roast_model.dart';

class RoastService {
  List<RoastModel> _roasts = [];
  bool _isLoaded = false;

  static const List<String> _roastImages = [
    'assets/images/roast/image 18.jpg',
    'assets/images/roast/image 19.jpg',
    'assets/images/roast/image 28.jpg',
    'assets/images/roast/image 7.jpg',
    'assets/images/roast/image8.jpg',
    'assets/images/roast/images (1).jpg',
    'assets/images/roast/images (2).jpg',
    'assets/images/roast/images (3).jpg',
    'assets/images/roast/images 10.jpg',
    'assets/images/roast/images 11.jpg',
    'assets/images/roast/images 12.jpg',
    'assets/images/roast/images 13.jpg',
    'assets/images/roast/images 14.jpg',
    'assets/images/roast/images 15.jpg',
    'assets/images/roast/images 16.jpg',
    'assets/images/roast/images 17.jpg',
    'assets/images/roast/images 20.jpg',
    'assets/images/roast/images 21.jpg',
    'assets/images/roast/images 22.jpg',
    'assets/images/roast/images 23.jpg',
    'assets/images/roast/images 29.jpg',
    'assets/images/roast/images 30.jpg',
    'assets/images/roast/images 5.jpg',
    'assets/images/roast/images 6.jpg',
    'assets/images/roast/images.jpg',
    'assets/images/roast/images4.jpg',
  ];

  bool get isLoaded => _isLoaded;

  /// Load roast dataset from asset CSV file
  Future<void> loadRoasts() async {
    if (_isLoaded && _roasts.isNotEmpty) return;

    try {
      final csvString = await rootBundle.loadString(AppConfig.defaultRoastCsvPath);
      _roasts = CsvParser.parseRoastCsv(csvString);
      _isLoaded = true;
    } catch (_) {
      _roasts = [];
      _isLoaded = false;
    }
  }

  /// Select a random roast meme image
  String getRandomRoastImage() {
    final random = Random();
    return _roastImages[random.nextInt(_roastImages.length)];
  }

  /// Select a text roast dynamically based on distraction count (intensity)
  RoastModel getRandomRoast({int distractionCount = 1, String? subject}) {
    if (_roasts.isEmpty) {
      return RoastModel(
        id: 'fallback_01',
        intensity: 1,
        category: 'General',
        tone: 'sarcastic',
        roast: "You really tried to open this during focus mode? 😂 Back to your goals!",
      );
    }

    final targetIntensity = distractionCount.clamp(1, 4);

    var matching = _roasts.where((r) => r.intensity == targetIntensity).toList();
    if (matching.isEmpty) {
      matching = _roasts;
    }

    final random = Random();
    return matching[random.nextInt(matching.length)];
  }
}
