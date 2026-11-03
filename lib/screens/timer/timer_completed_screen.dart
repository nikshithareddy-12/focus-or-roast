import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/achievement_model.dart';
import '../../providers/timer_provider.dart';
import '../../services/achievement_service.dart';

class TimerCompletedScreen extends StatefulWidget {
  const TimerCompletedScreen({super.key});

  @override
  State<TimerCompletedScreen> createState() => _TimerCompletedScreenState();
}

class _TimerCompletedScreenState extends State<TimerCompletedScreen> {
  late AchievementModel _achievement;

  @override
  void initState() {
    super.initState();
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    // Reuse the achievement produced by the genuine completion; fall back to a
    // computed one (using captured session values) only if it is absent.
    _achievement = timerProvider.latestAchievement ??
        AchievementService().getCompletionAchievement(
          focusMinutes: timerProvider.sessionFocusDurationMinutes,
          distractionCount: timerProvider.distractionCount,
        );
  }

  @override
  Widget build(BuildContext context) {
    final timerProvider = Provider.of<TimerProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
              const SizedBox(height: 12),
              const Text(
                'Focus Session Completed!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onBackground,
                ),
              ),
              const SizedBox(height: 24),

              // Achievement IMAGE Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          _achievement.imagePath,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) {
                            return Container(
                              height: 160,
                              color: AppColors.primaryContainer,
                              child: const Center(
                                child: Icon(Icons.star, size: 64, color: AppColors.primary),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _achievement.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _achievement.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Session Details Summary Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session Statistics',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 20),
                      _buildSummaryRow(
                        icon: Icons.book,
                        label: 'Subject',
                        value: timerProvider.sessionSubject,
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        icon: Icons.timer,
                        label: 'Planned Duration',
                        value: '${timerProvider.sessionFocusDurationMinutes} minutes',
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        icon: Icons.notifications_active_outlined,
                        label: 'Distractions Count',
                        value: '${timerProvider.distractionCount}',
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        icon: Icons.coffee_outlined,
                        label: 'Breaks Completed',
                        value: '${timerProvider.breaksCompleted} / ${timerProvider.sessionNumberOfBreaks}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'Return to Home',
                onPressed: () {
                  timerProvider.dismissCompleted();
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
