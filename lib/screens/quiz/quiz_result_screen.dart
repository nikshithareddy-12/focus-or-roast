import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quizProvider = Provider.of<QuizProvider>(context);
    final quiz = quizProvider.currentQuiz;
    final result = quizProvider.lastResult;
    final userAnswers = quizProvider.userAnswers;

    if (quiz == null || result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz Result')),
        body: const Center(child: Text('No result found.')),
      );
    }

    final isPassed = result.scorePercentage >= 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Score Banner Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isPassed ? AppColors.successBackground : AppColors.roastBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPassed ? AppColors.successGreen : AppColors.roastOrange,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isPassed ? Icons.workspace_premium_rounded : Icons.sentiment_dissatisfied_rounded,
                      size: 56,
                      color: isPassed ? AppColors.successGreen : AppColors.roastOrange,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${result.scorePercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isPassed ? AppColors.successGreen : AppColors.roastOrange,
                      ),
                    ),
                    Text(
                      '${result.correctAnswers} of ${result.totalQuestions} Correct',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Note: Your quiz score is private to your account.',
                      style: TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detailed Question Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              // Question Explanations List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quiz.questions.length,
                itemBuilder: (context, index) {
                  final q = quiz.questions[index];
                  final userAns = userAnswers[index];
                  final isCorrect = userAns == q.correctAnswer;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isCorrect ? AppColors.successGreen : AppColors.roastOrange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Q${index + 1}: ${q.question}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Your Answer: ${userAns != null ? q.options[userAns] : "Not answered"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isCorrect ? AppColors.successGreen : AppColors.roastOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isCorrect)
                            Text(
                              'Correct Answer: ${q.options[q.correctAnswer]}',
                              style: const TextStyle(fontSize: 13, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Explanation: ${q.explanation}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Back to Home',
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
