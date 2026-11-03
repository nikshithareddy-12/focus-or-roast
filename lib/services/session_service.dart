import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/focus_session.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveSession(FocusSession session) async {
    await _firestore
        .collection('users')
        .doc(session.userId)
        .collection('sessions')
        .doc(session.sessionId)
        .set(session.toMap());
  }

  Stream<List<FocusSession>> getUserSessionsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FocusSession.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<List<FocusSession>> getUserSessions(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => FocusSession.fromMap(doc.data(), doc.id))
        .toList();
  }
}
