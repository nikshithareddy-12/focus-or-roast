import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz_result_model.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveQuizResult(QuizResultModel result) async {
    // Private user collection: users/{uid}/quizResults/{resultId}
    await _firestore
        .collection('users')
        .doc(result.userId)
        .collection('quizResults')
        .doc(result.resultId)
        .set(result.toMap());
  }

  Stream<List<QuizResultModel>> getUserQuizResultsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('quizResults')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuizResultModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
