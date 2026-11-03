import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quizProvider = Provider.of<QuizProvider>(context);
    final quiz = quizProvider.currentQuiz;
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;

    if (quiz == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('No active quiz.')),
      );
    }

    final currentIndex = quizProvider.currentQuestionIndex;
    final question = quiz.questions[currentIndex];
    final selectedAnswer = quizProvider.userAnswers[currentIndex];
    final isLastQuestion = currentIndex == quiz.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('${quiz.subject} Quiz'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (currentIndex + 1) / quiz.questions.length,
            backgroundColor: AppColors.primaryLight.withOpacity(0.3),
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${currentIndex + 1} of ${quiz.questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quiz.difficulty,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                question.question,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView.builder(
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    final isOptionSelected = selectedAnswer == index;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isOptionSelected ? AppColors.primaryLight.withOpacity(0.3) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isOptionSelected ? AppColors.primary : const Color(0xFFE0E0E0),
                          width: isOptionSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isOptionSelected ? AppColors.primary : Colors.grey.shade200,
                          foregroundColor: isOptionSelected ? Colors.white : AppColors.textPrimary,
                          radius: 16,
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        title: Text(
                          question.options[index],
                          style: TextStyle(
                            fontWeight: isOptionSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () => quizProvider.selectAnswer(index),
                      ),
                    );
                  },
                ),
              ),

              Row(
                children: [
                  Expanded(
                    child: isLastQuestion
                        ? CustomButton(
                            text: 'Submit Quiz',
                            onPressed: () {
                              if (user != null) {
                                quizProvider.nextQuestion(user.uid);
                                Navigator.pushReplacementNamed(context, AppRoutes.quizResult);
                              }
                            },
                          )
                        : CustomButton(
                            text: 'Next Question',
                            onPressed: () {
                              if (user != null) {
                                quizProvider.nextQuestion(user.uid);
                              }
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
