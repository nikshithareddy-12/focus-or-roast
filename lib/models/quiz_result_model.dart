import 'package:cloud_firestore/cloud_firestore.dart';

class QuizResultModel {
  final String resultId;
  final String userId;
  final String subject;
  final String difficulty;
  final int score;
  final int totalQuestions;
  final DateTime timestamp;

  QuizResultModel({
    required this.resultId,
    required this.userId,
    required this.subject,
    required this.difficulty,
    required this.score,
    required this.totalQuestions,
    required this.timestamp,
  });

  int get correctAnswers => score;
  double get scorePercentage => totalQuestions > 0 ? (score / totalQuestions) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'resultId': resultId,
      'userId': userId,
      'subject': subject,
      'difficulty': difficulty,
      'score': score,
      'totalQuestions': totalQuestions,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'resultId': resultId,
      'userId': userId,
      'subject': subject,
      'difficulty': difficulty,
      'score': score,
      'totalQuestions': totalQuestions,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory QuizResultModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTimestamp = DateTime.now();
    final raw = map['timestamp'];
    if (raw is Timestamp) {
      parsedTimestamp = raw.toDate();
    } else if (raw is String) {
      parsedTimestamp = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(raw);
    }

    return QuizResultModel(
      resultId: id.isNotEmpty ? id : (map['resultId'] ?? ''),
      userId: map['userId'] ?? '',
      subject: map['subject'] ?? '',
      difficulty: map['difficulty'] ?? 'Medium',
      score: (map['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      timestamp: parsedTimestamp,
    );
  }
}
