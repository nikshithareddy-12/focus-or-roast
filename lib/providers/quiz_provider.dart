import 'package:flutter/foundation.dart';
import '../models/quiz_model.dart';
import '../models/quiz_result_model.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

class QuizProvider with ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

  QuizModel? _currentQuiz;
  int _currentQuestionIndex = 0;
  final Map<int, int> _userAnswers = {}; // questionIndex -> selectedOptionIndex
  bool _isLoading = false;
  String? _errorMessage;
  QuizResultModel? _lastResult;

  QuizModel? get currentQuiz => _currentQuiz;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<int, int> get userAnswers => _userAnswers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  QuizResultModel? get lastResult => _lastResult;

  QuizQuestionModel? get currentQuestion {
    if (_currentQuiz == null || _currentQuestionIndex >= _currentQuiz!.questions.length) {
      return null;
    }
    return _currentQuiz!.questions[_currentQuestionIndex];
  }

  bool get isQuizFinished {
    if (_currentQuiz == null) return false;
    return _currentQuestionIndex >= _currentQuiz!.questions.length;
  }

  Future<bool> generateQuiz({
    required String subject,
    String? topic,
    required String difficulty,
    required int count,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _currentQuiz = null;
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _lastResult = null;
    notifyListeners();

    try {
      final topicStr = (topic != null && topic.trim().isNotEmpty) ? topic.trim() : 'N/A';
      print('\n=========================================');
      print('SELECTED SUBJECT: $subject | TOPIC: $topicStr | LEVEL: $difficulty | COUNT: $count');
      print('=========================================\n');
      
      _currentQuiz = await _geminiService.generateQuiz(
        subject: subject,
        topic: topic,
        difficulty: difficulty,
        count: count,
      );
      
      print('[QUIZ PROVIDER FINAL] Final displayed question count: ${_currentQuiz!.questions.length} for: ${_currentQuiz!.subject}');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void selectAnswer(int optionIndex) {
    if (_currentQuiz == null) return;
    _userAnswers[_currentQuestionIndex] = optionIndex;
    notifyListeners();
  }

  void nextQuestion(String userId) {
    if (_currentQuiz == null) return;

    if (_currentQuestionIndex < _currentQuiz!.questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    } else {
      _finishQuiz(userId);
    }
  }

  void _finishQuiz(String userId) async {
    if (_currentQuiz == null) return;

    int correctCount = 0;
    for (int i = 0; i < _currentQuiz!.questions.length; i++) {
      if (_userAnswers[i] == _currentQuiz!.questions[i].correctAnswer) {
        correctCount++;
      }
    }

    final result = QuizResultModel(
      resultId: 'quiz_res_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      subject: _currentQuiz!.subject,
      difficulty: _currentQuiz!.difficulty,
      score: correctCount,
      totalQuestions: _currentQuiz!.questions.length,
      timestamp: DateTime.now(),
    );

    _lastResult = result;
    _currentQuestionIndex = _currentQuiz!.questions.length; // mark finished

    try {
      await _firestoreService.saveQuizResult(result);
    } catch (_) {}

    notifyListeners();
  }

  void resetQuiz() {
    _currentQuiz = null;
    _currentQuestionIndex = 0;
    _userAnswers.clear();
    _lastResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  void resetState() {
    resetQuiz();
  }
}
