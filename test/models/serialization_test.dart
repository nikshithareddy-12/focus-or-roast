import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_roast/models/focus_session.dart';
import 'package:focus_roast/models/user_model.dart';
import 'package:focus_roast/models/quiz_result_model.dart';
import 'package:focus_roast/models/message_model.dart';
import 'package:focus_roast/models/document_model.dart';
import 'package:focus_roast/models/group_model.dart';

void main() {
  final epoch = DateTime.utc(2024, 1, 2, 3, 4, 5);

  group('FocusSession serialization', () {
    test('reads Timestamp, ISO-8601 string and millis-int for dates', () {
      final fromTs = FocusSession.fromMap({
        'sessionId': 's1',
        'userId': 'u1',
        'startTime': Timestamp.fromDate(epoch),
        'endTime': Timestamp.fromDate(epoch),
      }, 's1');
      expect(fromTs.startTime.toUtc(), epoch);

      final fromStr = FocusSession.fromMap({
        'startTime': epoch.toIso8601String(),
        'endTime': epoch.toIso8601String(),
      }, 's2');
      expect(fromStr.startTime.toUtc(), epoch);

      final fromInt = FocusSession.fromMap({
        'startTime': epoch.millisecondsSinceEpoch,
        'endTime': epoch.millisecondsSinceEpoch,
      }, 's3');
      expect(fromInt.startTime.millisecondsSinceEpoch,
          epoch.millisecondsSinceEpoch);
    });

    test('coerces double-typed ints without crashing (legacy/double docs)', () {
      final s = FocusSession.fromMap({
        'plannedDuration': 25.0,
        'actualDuration': 24.0,
        'numberOfBreaks': 2.0,
        'breakDuration': 5.0,
        'breaksCompleted': 1.0,
        'distractionCount': 3.0,
        'startTime': Timestamp.fromDate(epoch),
        'endTime': Timestamp.fromDate(epoch),
      }, 's4');

      expect(s.plannedDuration, 25);
      expect(s.actualDuration, 24);
      expect(s.numberOfBreaks, 2);
      expect(s.breakDuration, 5);
      expect(s.breaksCompleted, 1);
      expect(s.distractionCount, 3);
    });

    test('applies safe defaults for missing fields', () {
      final s = FocusSession.fromMap({}, 'id-from-doc');
      expect(s.sessionId, 'id-from-doc');
      expect(s.subject, 'General');
      expect(s.plannedDuration, 30);
      expect(s.breakDuration, 5);
      expect(s.completed, false);
    });

    test('round-trips through toMap (ISO) and toFirestoreMap (Timestamp)', () {
      final original = FocusSession(
        sessionId: 'rt',
        userId: 'u',
        subject: 'Math',
        plannedDuration: 30,
        actualDuration: 28,
        numberOfBreaks: 2,
        breakDuration: 5,
        breaksCompleted: 2,
        distractionCount: 1,
        completed: true,
        startTime: epoch,
        endTime: epoch,
      );

      final viaIso = FocusSession.fromMap(original.toMap(), 'rt');
      expect(viaIso.completed, true);
      expect(viaIso.actualDuration, 28);
      expect(viaIso.startTime.toUtc(), epoch);

      final viaFs = FocusSession.fromMap(original.toFirestoreMap(), 'rt');
      expect(viaFs.subject, 'Math');
      expect(viaFs.endTime.toUtc(), epoch);
    });
  });

  group('UserModel serialization', () {
    test('parses createdAt from Timestamp, string, int and missing', () {
      expect(
        UserModel.fromMap({'createdAt': Timestamp.fromDate(epoch)}, 'u')
            .createdAt
            .toUtc(),
        epoch,
      );
      expect(
        UserModel.fromMap({'createdAt': epoch.toIso8601String()}, 'u')
            .createdAt
            .toUtc(),
        epoch,
      );
      expect(
        UserModel.fromMap({'createdAt': epoch.millisecondsSinceEpoch}, 'u')
            .createdAt
            .millisecondsSinceEpoch,
        epoch.millisecondsSinceEpoch,
      );
      // Missing createdAt falls back to "now" rather than throwing.
      expect(UserModel.fromMap({}, 'u').createdAt.isAfter(DateTime(2000)), true);
    });

    test('coerces numeric stats and defaults allowGroupInvites to true', () {
      final u = UserModel.fromMap({
        'name': 'Ada',
        'username': 'ada',
        'totalFocusMinutes': 120.0,
        'currentStreak': 3.0,
      }, 'uid-1');

      expect(u.uid, 'uid-1'); // doc id wins over map['uid']
      expect(u.totalFocusMinutes, 120);
      expect(u.currentStreak, 3);
      expect(u.allowGroupInvites, true);
      expect(u.distractionApps, isEmpty);
    });

    test('public projection exposes ONLY whitelisted safe fields', () {
      final u = UserModel(
        uid: 'uid-1',
        name: 'Ada',
        username: 'ada',
        email: 'ada@example.com',
        distractionApps: const ['com.secret.app'],
        totalFocusMinutes: 42,
        allowGroupInvites: false,
        createdAt: epoch,
      );

      final pub = u.toPublicProfileMap();

      // Must never leak private fields.
      expect(pub.containsKey('email'), false);
      expect(pub.containsKey('distractionApps'), false);
      expect(pub.containsKey('createdAt'), false);

      // Must match the firestore.rules whitelist exactly.
      expect(
        pub.keys.toSet(),
        {
          'uid',
          'username',
          'name',
          'totalFocusMinutes',
          'allowGroupInvites',
          'updatedAt',
        },
      );
      expect(pub['uid'], 'uid-1');
      expect(pub['totalFocusMinutes'], 42);
      expect(pub['allowGroupInvites'], false);
    });
  });

  group('QuizResultModel serialization', () {
    test('coerces score/totalQuestions and parses timestamp variants', () {
      final q = QuizResultModel.fromMap({
        'score': 7.0,
        'totalQuestions': 10.0,
        'timestamp': Timestamp.fromDate(epoch),
      }, 'r1');

      expect(q.score, 7);
      expect(q.totalQuestions, 10);
      expect(q.timestamp.toUtc(), epoch);
      expect(q.scorePercentage, 70.0);
    });

    test('scorePercentage guards divide-by-zero', () {
      final q = QuizResultModel.fromMap({'score': 0, 'totalQuestions': 0}, 'r');
      expect(q.scorePercentage, 0.0);
    });
  });

  group('MessageModel serialization', () {
    test('coerces fileSize from num and parses serverTimestamp-style values', () {
      final m = MessageModel.fromMap({
        'senderId': 'u',
        'content': 'hi',
        'fileSize': 2048.0,
        'timestamp': Timestamp.fromDate(epoch),
      }, 'm1');

      expect(m.fileSize, 2048);
      expect(m.timestamp.toUtc(), epoch);
      expect(m.senderUsername, isNotEmpty); // falls back to senderName/user
    });
  });

  group('DocumentModel serialization', () {
    test('coerces fileSize from double', () {
      final d = DocumentModel.fromMap({
        'fileName': 'notes.pdf',
        'fileSize': 1024.0,
        'timestamp': epoch.toIso8601String(),
      }, 'd1');

      expect(d.fileSize, 1024);
      expect(d.timestamp.toUtc(), epoch);
    });
  });

  group('GroupModel serialization', () {
    test('parses members list and createdAt variants', () {
      final g = GroupModel.fromMap({
        'name': 'Study',
        'members': ['a', 'b'],
        'isPublic': false,
        'createdAt': Timestamp.fromDate(epoch),
      }, 'g1');

      expect(g.members, ['a', 'b']);
      expect(g.isPublic, false);
      expect(g.createdAt.toUtc(), epoch);
    });

    test('defaults members to empty and isPublic to true when missing', () {
      final g = GroupModel.fromMap({}, 'g2');
      expect(g.members, isEmpty);
      expect(g.isPublic, true);
    });
  });
}
