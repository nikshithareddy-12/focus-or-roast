class QuizQuestionModel {
  final String question;
  final List<String> options;
  final int correctAnswer; // Index of correct option (0-3)
  final String explanation;

  QuizQuestionModel({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  int get correctAnswerIndex => correctAnswer;

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }

  factory QuizQuestionModel.fromMap(Map<String, dynamic> map) {
    return QuizQuestionModel(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswer: map['correctAnswer'] ?? 0,
      explanation: map['explanation'] ?? '',
    );
  }
}

class QuizModel {
  final String id;
  final String subject;
  final String difficulty;
  final List<QuizQuestionModel> questions;

  QuizModel({
    required this.id,
    required this.subject,
    required this.difficulty,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'difficulty': difficulty,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory QuizModel.fromMap(Map<String, dynamic> map, String id) {
    final list = map['questions'] as List? ?? [];
    return QuizModel(
      id: id,
      subject: map['subject'] ?? '',
      difficulty: map['difficulty'] ?? 'Medium',
      questions: list.map((q) => QuizQuestionModel.fromMap(q)).toList(),
    );
  }
}
