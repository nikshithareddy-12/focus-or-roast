import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String formatDateTime(DateTime dt) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(dt);
  }

  static String formatDateShort(DateTime dt) {
    return DateFormat('MMM dd').format(dt);
  }

  static String formatTimeOnly(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }
}
