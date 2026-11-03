import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/timer_provider.dart';

class BreakTimerScreen extends StatelessWidget {
  const BreakTimerScreen({super.key});

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, timerProvider, child) {
        if (timerProvider.state == TimerState.focusRunning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.focusTimer);
          });
        }

        final remaining = timerProvider.breakRemainingSeconds;
        final totalSeconds = timerProvider.sessionBreakDurationMinutes * 60;
        final progress = totalSeconds > 0 ? (totalSeconds - remaining) / totalSeconds : 0.0;

        return Scaffold(
          backgroundColor: AppColors.breakCalm.withOpacity(0.05),
          appBar: AppBar(
            title: const Text('Break Time'),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: const [
                      Icon(Icons.coffee, size: 48, color: AppColors.breakCalm),
                      SizedBox(height: 12),
                      Text(
                        'Take a Quick Refresh',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onBackground,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No distraction roasts active during break',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  // Real Break Countdown Dial
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 10,
                          backgroundColor: AppColors.breakCalm.withOpacity(0.2),
                          color: AppColors.breakCalm,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(remaining),
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: AppColors.breakCalm,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'BREAK TIME',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Interactive Break Activities Access
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const Icon(Icons.self_improvement, color: AppColors.breakCalm, size: 32),
                      title: const Text('Break Activities', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Breathing, Stretching, Walking, Eye Rest'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.breakActivities);
                      },
                    ),
                  ),

                  CustomButton(
                    text: 'Skip Break & Resume Focus',
                    backgroundColor: AppColors.breakCalm,
                    onPressed: () {
                      timerProvider.skipBreak();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
