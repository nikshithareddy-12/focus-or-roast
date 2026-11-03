import '../../models/roast_model.dart';

class CsvParser {
  /// Parses pipe `|` separated CSV text into a list of [RoastModel].
  static List<RoastModel> parseRoastCsv(String csvContent) {
    final List<RoastModel> roasts = [];
    final lines = csvContent.split('\n');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Split by pipe '|'
      final parts = trimmed.split('|');
      if (parts.length >= 5) {
        final id = parts[0].trim();
        final intensity = int.tryParse(parts[1].trim()) ?? 1;
        final category = parts[2].trim();
        final tone = parts[3].trim();
        final roastText = parts.sublist(4).join('|').trim();

        roasts.add(
          RoastModel(
            id: id,
            intensity: intensity,
            category: category,
            tone: tone,
            roast: roastText,
          ),
        );
      }
    }

    return roasts;
  }
}
