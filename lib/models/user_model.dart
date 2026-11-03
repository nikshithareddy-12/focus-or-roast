import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String username;
  final String email;
  final List<String> distractionApps;
  final bool allowGroupInvites;
  final DateTime createdAt;
  final int totalFocusMinutes;
  final int completedSessions;
  final int currentStreak;
  final int longestStreak;
  final int totalSessions;
  final int totalDistractions;
  final int todayMinutes;
  final int weeklyMinutes;
  final int monthlyMinutes;
  final int achievementCount;

  UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.distractionApps,
    this.allowGroupInvites = true,
    required this.createdAt,
    this.totalFocusMinutes = 0,
    this.completedSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalSessions = 0,
    this.totalDistractions = 0,
    this.todayMinutes = 0,
    this.weeklyMinutes = 0,
    this.monthlyMinutes = 0,
    this.achievementCount = 0,
  });

  /// Map suitable for JSON encoding / SharedPreferences local persistence
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'email': email,
      'distractionApps': distractionApps,
      'allowGroupInvites': allowGroupInvites,
      'createdAt': createdAt.toIso8601String(),
      'totalFocusMinutes': totalFocusMinutes,
      'completedSessions': completedSessions,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalSessions': totalSessions,
      'totalDistractions': totalDistractions,
      'todayMinutes': todayMinutes,
      'weeklyMinutes': weeklyMinutes,
      'monthlyMinutes': monthlyMinutes,
      'achievementCount': achievementCount,
    };
  }

  /// Map for the public `publicProfiles/{uid}` projection. Contains ONLY fields
  /// that are safe to expose to other authenticated users (no email, no
  /// distractionApps, no private stats). Must stay in sync with the field
  /// whitelist enforced in firestore.rules.
  Map<String, dynamic> toPublicProfileMap() {
    return {
      'uid': uid,
      'username': username,
      'name': name,
      'totalFocusMinutes': totalFocusMinutes,
      'allowGroupInvites': allowGroupInvites,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Map suitable for Firestore documents (uses Firestore Timestamp)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'email': email,
      'distractionApps': distractionApps,
      'allowGroupInvites': allowGroupInvites,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalFocusMinutes': totalFocusMinutes,
      'completedSessions': completedSessions,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalSessions': totalSessions,
      'totalDistractions': totalDistractions,
      'todayMinutes': todayMinutes,
      'weeklyMinutes': weeklyMinutes,
      'monthlyMinutes': monthlyMinutes,
      'achievementCount': achievementCount,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedCreatedAt = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.toDate();
    } else if (rawCreated is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else if (rawCreated is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    }

    return UserModel(
      uid: id.isNotEmpty ? id : (map['uid'] ?? ''),
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      distractionApps: List<String>.from(map['distractionApps'] ?? []),
      allowGroupInvites: map['allowGroupInvites'] ?? true,
      createdAt: parsedCreatedAt,
      totalFocusMinutes: (map['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      completedSessions: (map['completedSessions'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      totalSessions: (map['totalSessions'] as num?)?.toInt() ?? 0,
      totalDistractions: (map['totalDistractions'] as num?)?.toInt() ?? 0,
      todayMinutes: (map['todayMinutes'] as num?)?.toInt() ?? 0,
      weeklyMinutes: (map['weeklyMinutes'] as num?)?.toInt() ?? 0,
      monthlyMinutes: (map['monthlyMinutes'] as num?)?.toInt() ?? 0,
      achievementCount: (map['achievementCount'] as num?)?.toInt() ?? 0,
    );
  }

  UserModel copyWith({
    String? name,
    String? username,
    String? email,
    List<String>? distractionApps,
    bool? allowGroupInvites,
    int? totalFocusMinutes,
    int? completedSessions,
    int? currentStreak,
    int? longestStreak,
    int? totalSessions,
    int? totalDistractions,
    int? todayMinutes,
    int? weeklyMinutes,
    int? monthlyMinutes,
    int? achievementCount,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      distractionApps: distractionApps ?? this.distractionApps,
      allowGroupInvites: allowGroupInvites ?? this.allowGroupInvites,
      createdAt: createdAt,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      completedSessions: completedSessions ?? this.completedSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalSessions: totalSessions ?? this.totalSessions,
      totalDistractions: totalDistractions ?? this.totalDistractions,
      todayMinutes: todayMinutes ?? this.todayMinutes,
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      monthlyMinutes: monthlyMinutes ?? this.monthlyMinutes,
      achievementCount: achievementCount ?? this.achievementCount,
    );
  }
}
