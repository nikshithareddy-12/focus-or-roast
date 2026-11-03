import 'package:cloud_firestore/cloud_firestore.dart';

class FocusSession {
  final String sessionId;
  final String userId;
  final String subject;
  final int plannedDuration;  // in minutes
  final int actualDuration;   // in minutes
  final int numberOfBreaks;
  final int breakDuration;    // in minutes
  final int breaksCompleted;
  final int distractionCount;
  final bool completed;
  final DateTime startTime;
  final DateTime endTime;

  FocusSession({
    required this.sessionId,
    required this.userId,
    required this.subject,
    required this.plannedDuration,
    required this.actualDuration,
    required this.numberOfBreaks,
    required this.breakDuration,
    this.breaksCompleted = 0,
    this.distractionCount = 0,
    this.completed = false,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'subject': subject,
      'plannedDuration': plannedDuration,
      'actualDuration': actualDuration,
      'numberOfBreaks': numberOfBreaks,
      'breakDuration': breakDuration,
      'breaksCompleted': breaksCompleted,
      'distractionCount': distractionCount,
      'completed': completed,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'subject': subject,
      'plannedDuration': plannedDuration,
      'actualDuration': actualDuration,
      'numberOfBreaks': numberOfBreaks,
      'breakDuration': breakDuration,
      'breaksCompleted': breaksCompleted,
      'distractionCount': distractionCount,
      'completed': completed,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return FocusSession(
      sessionId: id.isNotEmpty ? id : (map['sessionId'] ?? ''),
      userId: map['userId'] ?? '',
      subject: map['subject'] ?? 'General',
      plannedDuration: (map['plannedDuration'] as num?)?.toInt() ?? 30,
      actualDuration: (map['actualDuration'] as num?)?.toInt() ?? 0,
      numberOfBreaks: (map['numberOfBreaks'] as num?)?.toInt() ?? 0,
      breakDuration: (map['breakDuration'] as num?)?.toInt() ?? 5,
      breaksCompleted: (map['breaksCompleted'] as num?)?.toInt() ?? 0,
      distractionCount: (map['distractionCount'] as num?)?.toInt() ?? 0,
      completed: map['completed'] ?? false,
      startTime: parseDate(map['startTime']),
      endTime: parseDate(map['endTime']),
    );
  }
}
