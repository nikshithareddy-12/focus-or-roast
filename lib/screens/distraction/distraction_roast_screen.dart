import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/distraction_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/timer_provider.dart';
import '../../services/roast_service.dart';

class DistractionRoastScreen extends StatefulWidget {
  const DistractionRoastScreen({super.key});

  @override
  State<DistractionRoastScreen> createState() => _DistractionRoastScreenState();
}

class _DistractionRoastScreenState extends State<DistractionRoastScreen> {
  late final String _roastImage;

  @override
  void initState() {
    super.initState();
    _roastImage = RoastService().getRandomRoastImage();
  }

  void _openAiQuizChallenge() async {
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final distractionProvider = Provider.of<DistractionProvider>(context, listen: false);

    distractionProvider.setQuizActive(true);
    distractionProvider.dismissRoastOverlay();

    // Generate quick 1-2 question quiz related to the active focus subject
    await quizProvider.generateQuiz(
      subject: timerProvider.selectedSubject,
      difficulty: 'Medium',
      count: 2,
    );

    if (mounted) {
      Navigator.pushNamed(context, AppRoutes.quiz).then((_) {
        distractionProvider.setQuizActive(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final distractionProvider = Provider.of<DistractionProvider>(context);
    final timerProvider = Provider.of<TimerProvider>(context);

    final roastModel = distractionProvider.latestRoast;
    final roastText = roastModel?.roast ?? "You really tried to open this during focus mode? 😂 Back to work!";

    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Fire Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.roastOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.roastOrange),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.local_fire_department, size: 20, color: AppColors.roastOrange),
                    SizedBox(width: 6),
                    Text(
                      'DISTRACTION DETECTED!',
                      style: TextStyle(
                        color: AppColors.roastOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Nice try 😏',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // Subject Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📚 Focus Task: ${timerProvider.selectedSubject}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Roast MEME Image Card
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  _roastImage,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 120,
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(Icons.sentiment_very_dissatisfied, size: 48, color: Colors.orange),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Roast TEXT Card
              Card(
                elevation: 4,
                color: const Color(0xFF1E1E2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF2E2E42)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      const Icon(Icons.format_quote, size: 28, color: AppColors.roastOrange),
                      const SizedBox(height: 4),
                      Text(
                        roastText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Distraction Stats Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Distractions this session: ${timerProvider.distractionCount}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // AI Challenge Button
              CustomButton(
                text: '⚡ Quick AI Challenge (Get Back on Track)',
                icon: Icons.psychology,
                backgroundColor: Colors.teal.shade700,
                textColor: Colors.white,
                onPressed: _openAiQuizChallenge,
              ),
              const SizedBox(height: 12),

              // Back to Focus Button
              CustomButton(
                text: '🎯 Back to Focus',
                icon: Icons.arrow_back,
                backgroundColor: AppColors.roastOrange,
                textColor: Colors.white,
                onPressed: () {
                  distractionProvider.dismissRoastOverlay();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
