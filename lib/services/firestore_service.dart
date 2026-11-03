import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/streak_calculator.dart';
import '../models/achievement_model.dart';
import '../models/focus_session.dart';
import '../models/quiz_result_model.dart';
import '../models/user_model.dart';
import 'analytics_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save completed or interrupted focus session under /users/{uid}/sessions/{sessionId}
  /// and automatically update user aggregated statistics (streak, metrics, totals)
  Future<void> saveFocusSession(FocusSession session) async {
    final userDocRef = _firestore.collection('users').doc(session.userId);

    // 1. Save session doc to Firestore
    await userDocRef
        .collection('sessions')
        .doc(session.sessionId)
        .set(session.toFirestoreMap());

    // 2. Aggregate all sessions for this user to compute accurate streak & metrics
    try {
      final sessionsSnapshot = await userDocRef.collection('sessions').get();
      final allSessions = sessionsSnapshot.docs
          .map((doc) => FocusSession.fromMap(doc.data(), doc.id))
          .toList();

      final streak = StreakCalculator.calculate(allSessions);
      final metrics = AnalyticsService.calculateMetrics(allSessions);
      final totalSessionsCount = allSessions.length;

      int totalFocusMinutes = 0;
      for (final s in allSessions) {
        if (s.completed) {
          totalFocusMinutes += s.actualDuration;
        }
      }

      await userDocRef.update({
        'totalFocusMinutes': totalFocusMinutes,
        'completedSessions': metrics.totalCompletedSessions,
        'totalSessions': totalSessionsCount,
        'totalDistractions': metrics.totalDistractions,
        'currentStreak': streak.currentStreak,
        'longestStreak': streak.longestStreak,
        'todayMinutes': metrics.todayMinutes,
        'weeklyMinutes': metrics.weeklyMinutes,
        'monthlyMinutes': metrics.monthlyMinutes,
      });
    } catch (e) {
      developer.log('Error updating aggregated user stats: $e', name: 'FirestoreService');
      // Fallback atomic increment if full aggregation query had a transient error
      if (session.completed) {
        await userDocRef.update({
          'totalFocusMinutes': FieldValue.increment(session.actualDuration),
          'completedSessions': FieldValue.increment(1),
          'totalSessions': FieldValue.increment(1),
          'totalDistractions': FieldValue.increment(session.distractionCount),
        }).catchError((_) {});
      } else {
        await userDocRef.update({
          'totalSessions': FieldValue.increment(1),
          'totalDistractions': FieldValue.increment(session.distractionCount),
        }).catchError((_) {});
      }
    }
  }

  /// Save unlocked achievement under /users/{uid}/achievements/{achievementId}
  Future<void> saveAchievement(String uid, AchievementModel achievement) async {
    if (uid.isEmpty) return;
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef
          .collection('achievements')
          .doc(achievement.id)
          .set(achievement.toFirestoreMap());

      await userDocRef.update({
        'achievementCount': FieldValue.increment(1),
      }).catchError((_) {});
    } catch (e) {
      developer.log('Error saving achievement: $e', name: 'FirestoreService');
    }
  }

  /// Stream unlocked achievements for a user ordered by unlockedAt descending
  Stream<List<AchievementModel>> getUserAchievements(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AchievementModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Synchronize and update user statistics for a given user from their session history
  Future<void> syncUserStats(String uid) async {
    if (uid.isEmpty) return;
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final sessionsSnapshot = await userDocRef.collection('sessions').get();
      if (sessionsSnapshot.docs.isEmpty) return;

      final allSessions = sessionsSnapshot.docs
          .map((doc) => FocusSession.fromMap(doc.data(), doc.id))
          .toList();

      final streak = StreakCalculator.calculate(allSessions);
      final metrics = AnalyticsService.calculateMetrics(allSessions);
      final totalSessionsCount = allSessions.length;

      int totalFocusMinutes = 0;
      for (final s in allSessions) {
        if (s.completed) {
          totalFocusMinutes += s.actualDuration;
        }
      }

      final achSnapshot = await userDocRef.collection('achievements').get();

      await userDocRef.update({
        'totalFocusMinutes': totalFocusMinutes,
        'completedSessions': metrics.totalCompletedSessions,
        'totalSessions': totalSessionsCount,
        'totalDistractions': metrics.totalDistractions,
        'currentStreak': streak.currentStreak,
        'longestStreak': streak.longestStreak,
        'todayMinutes': metrics.todayMinutes,
        'weeklyMinutes': metrics.weeklyMinutes,
        'monthlyMinutes': metrics.monthlyMinutes,
        'achievementCount': achSnapshot.docs.length,
      });
    } catch (e) {
      developer.log('Error syncing user stats: $e', name: 'FirestoreService');
    }
  }

  /// Get real focus sessions for a user sorted by startTime descending
  Stream<List<FocusSession>> getUserSessions(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FocusSession.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Save private quiz result under /users/{uid}/quizResults/{resultId}
  Future<void> saveQuizResult(QuizResultModel result) async {
    await _firestore
        .collection('users')
        .doc(result.userId)
        .collection('quizResults')
        .doc(result.resultId)
        .set(result.toFirestoreMap());
  }

  /// Stream private quiz results for a user
  Stream<List<QuizResultModel>> getUserQuizResults(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('quizResults')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuizResultModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get leaderboard rankings from the public projection, ordered by
  /// totalFocusMinutes descending. Reads `publicProfiles` (safe public fields
  /// only) instead of other users' private `users` documents, so it works under
  /// the default-deny security rules and never exposes email/distractionApps.
  Stream<List<UserModel>> getLeaderboard() {
    return _firestore
        .collection('publicProfiles')
        .orderBy('totalFocusMinutes', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Create-or-refresh the public projection for a user. Keeps the leaderboard
  /// and invite-lookup data in sync with the private profile, and lazily
  /// backfills `publicProfiles` for accounts created before this collection
  /// existed. Failures are logged, not thrown — the private profile write is
  /// the source of truth and must not be blocked by a projection update.
  Future<void> upsertPublicProfile(UserModel user) async {
    if (user.uid.isEmpty) return;
    try {
      await _firestore
          .collection('publicProfiles')
          .doc(user.uid)
          .set(user.toPublicProfileMap(), SetOptions(merge: true));
    } catch (e) {
      developer.log('Error upserting public profile: $e', name: 'FirestoreService');
    }
  }
}
