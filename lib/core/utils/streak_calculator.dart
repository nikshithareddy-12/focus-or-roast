import '../../models/focus_session.dart';

class StreakResult {
  final int currentStreak;
  final int longestStreak;
  final int weeklySessions;
  final int monthlySessions;
  final Set<DateTime> activeDates;

  StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklySessions,
    required this.monthlySessions,
    required this.activeDates,
  });
}

class StreakCalculator {
  static StreakResult calculate(List<FocusSession> sessions) {
    if (sessions.isEmpty) {
      return StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        weeklySessions: 0,
        monthlySessions: 0,
        activeDates: {},
      );
    }

    final completedSessions = sessions.where((s) => s.completed).toList();
    if (completedSessions.isEmpty) {
      return StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        weeklySessions: 0,
        monthlySessions: 0,
        activeDates: {},
      );
    }

    // Extract unique normalized dates (year, month, day)
    final Set<DateTime> activeDates = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int weeklyCount = 0;
    int monthlyCount = 0;

    for (var s in completedSessions) {
      final date = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      activeDates.add(date);

      if (date.isAfter(weekStart.subtract(const Duration(seconds: 1)))) {
        weeklyCount++;
      }
      if (date.isAfter(monthStart.subtract(const Duration(seconds: 1)))) {
        monthlyCount++;
      }
    }

    final sortedDates = activeDates.toList()..sort((a, b) => b.compareTo(a));

    // Calculate current streak
    int currentStreak = 0;
    DateTime checkDate = today;

    if (!activeDates.contains(today)) {
      // Check if active yesterday
      final yesterday = today.subtract(const Duration(days: 1));
      if (activeDates.contains(yesterday)) {
        checkDate = yesterday;
      } else {
        checkDate = DateTime(1970); // No current active streak
      }
    }

    if (checkDate != DateTime(1970)) {
      while (activeDates.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? prevDate;

    for (var date in sortedDates) {
      if (prevDate == null) {
        tempStreak = 1;
      } else {
        final diff = prevDate.difference(date).inDays;
        if (diff == 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
      }
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
      }
      prevDate = date;
    }

    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      weeklySessions: weeklyCount,
      monthlySessions: monthlyCount,
      activeDates: activeDates,
    );
  }
}
