import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/roast_model.dart';
import '../core/utils/csv_parser.dart';

class DistractionService {
  List<RoastModel> _roastDataset = [];
  bool _isLoaded = false;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final csvString = await rootBundle.loadString('assets/data/roast_memes.csv');
      _roastDataset = CsvParser.parseRoastCsv(csvString);
    } catch (_) {
      _roastDataset = [];
    }
    _isLoaded = true;
  }

  RoastModel getRandomRoast({required int distractionCount, String? subject}) {
    if (_roastDataset.isEmpty) {
      // Safe fallback if dataset missing
      return RoastModel(
        id: 'fallback',
        intensity: 1,
        category: 'General',
        tone: 'sarcastic',
        roast: 'Distraction detected! Return to your study session immediately.',
      );
    }

    // Determine target intensity based on distraction count
    int targetIntensity = 1;
    if (distractionCount == 2) {
      targetIntensity = 2;
    } else if (distractionCount >= 3) {
      targetIntensity = 3;
    }

    // Filter dataset by intensity
    var matching = _roastDataset.where((r) => r.intensity == targetIntensity).toList();
    if (matching.isEmpty) {
      matching = _roastDataset;
    }

    final rand = Random();
    return matching[rand.nextInt(matching.length)];
  }
}
