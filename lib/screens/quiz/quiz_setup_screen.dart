import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();

  String _difficulty = 'Medium';
  int _questionCount = 5;

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _startQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = _subjectController.text.trim();
    final topic = _topicController.text.trim();

    debugPrint('\n================ [USER CLICKED GENERATE QUIZ] ================');
    debugPrint('SELECTED SUBJECT: "$subject"');
    debugPrint('SELECTED TOPIC: "${topic.isNotEmpty ? topic : 'None'}"');
    debugPrint('SELECTED LEVEL: "$_difficulty"');
    debugPrint('SELECTED QUESTION COUNT: $_questionCount');
    debugPrint('===============================================================\n');

    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final success = await quizProvider.generateQuiz(
      subject: subject,
      topic: topic,
      difficulty: _difficulty,
      count: _questionCount,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.quiz);
    } else if (quizProvider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(quizProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizProvider = Provider.of<QuizProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini AI Quiz Setup ✨'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.accent, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Powered by Google Gemini API. Enter your study topic to generate custom MCQs.',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Subject Input
                CustomTextField(
                  controller: _subjectController,
                  label: 'Subject / Area of Study',
                  hint: 'e.g. DBMS, Data Structures, Physics, Java',
                  prefixIcon: Icons.menu_book_rounded,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a specific subject for the quiz.';
                    }
                    if (val.trim().toLowerCase() == 'general') {
                      return 'Please specify a real subject topic instead of "General".';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Specific Topic Input (Optional)
                CustomTextField(
                  controller: _topicController,
                  label: 'Specific Topic (Optional)',
                  hint: 'e.g. Normalization, SQL, Trees, Sound',
                  prefixIcon: Icons.topic_rounded,
                ),
                const SizedBox(height: 24),

                // Difficulty Picker
                const Text(
                  'Difficulty Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['Easy', 'Medium', 'Hard'].map((diff) {
                    final isSelected = _difficulty == diff;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Center(child: Text(diff)),
                          selected: isSelected,
                          selectedColor: AppColors.primaryLight,
                          onSelected: (selected) {
                            if (selected) setState(() => _difficulty = diff);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Number of Questions Picker
                const Text(
                  'Number of Questions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [5, 10, 15, 20].map((count) {
                    final isSelected = _questionCount == count;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Center(child: Text('$count')),
                          selected: isSelected,
                          selectedColor: AppColors.primaryLight,
                          onSelected: (selected) {
                            if (selected) setState(() => _questionCount = count);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 36),

                CustomButton(
                  text: 'Generate Quiz',
                  icon: Icons.auto_awesome_rounded,
                  isLoading: quizProvider.isLoading,
                  onPressed: _startQuiz,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
