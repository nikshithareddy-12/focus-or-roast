import '../models/focus_session.dart';

class AnalyticsMetrics {
  final int todayMinutes;
  final int weeklyMinutes;
  final int monthlyMinutes;
  final int totalCompletedSessions;
  final int totalDistractions;
  final double averageSessionMinutes;
  final Map<String, int> subjectDistribution;
  final int totalBreaksTaken;

  AnalyticsMetrics({
    required this.todayMinutes,
    required this.weeklyMinutes,
    required this.monthlyMinutes,
    required this.totalCompletedSessions,
    required this.totalDistractions,
    required this.averageSessionMinutes,
    required this.subjectDistribution,
    required this.totalBreaksTaken,
  });
}

class AnalyticsService {
  static AnalyticsMetrics calculateMetrics(List<FocusSession> sessions) {
    if (sessions.isEmpty) {
      return AnalyticsMetrics(
        todayMinutes: 0,
        weeklyMinutes: 0,
        monthlyMinutes: 0,
        totalCompletedSessions: 0,
        totalDistractions: 0,
        averageSessionMinutes: 0,
        subjectDistribution: {},
        totalBreaksTaken: 0,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayMins = 0;
    int weeklyMins = 0;
    int monthlyMins = 0;
    int completedCount = 0;
    int totalDistractionCount = 0;
    int totalBreaks = 0;
    int totalActualMinutes = 0;

    final Map<String, int> subjectMap = {};

    for (var s in sessions) {
      final sessionDate = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      final duration = s.actualDuration;

      totalDistractionCount += s.distractionCount;
      totalBreaks += s.breaksCompleted;
      totalActualMinutes += duration;

      if (s.completed) {
        completedCount++;
      }

      // Subject distribution
      subjectMap[s.subject] = (subjectMap[s.subject] ?? 0) + duration;

      if (sessionDate.isAtSameMomentAs(today)) {
        todayMins += duration;
      }
      if (!sessionDate.isBefore(weekStart)) {
        weeklyMins += duration;
      }
      if (!sessionDate.isBefore(monthStart)) {
        monthlyMins += duration;
      }
    }

    final avgMins = sessions.isNotEmpty ? (totalActualMinutes / sessions.length) : 0.0;

    return AnalyticsMetrics(
      todayMinutes: todayMins,
      weeklyMinutes: weeklyMins,
      monthlyMinutes: monthlyMins,
      totalCompletedSessions: completedCount,
      totalDistractions: totalDistractionCount,
      averageSessionMinutes: avgMins,
      subjectDistribution: subjectMap,
      totalBreaksTaken: totalBreaks,
    );
  }
}
