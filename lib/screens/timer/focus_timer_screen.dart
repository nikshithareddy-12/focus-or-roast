import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/timer_provider.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  bool _handledCompletion = false;
  bool _handledBreak = false;

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, timerProvider, child) {
        // Handle break transition
        if ((timerProvider.state == TimerState.breakRunning || timerProvider.state == TimerState.breakPaused) && !_handledBreak) {
          _handledBreak = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.breakTimer);
            }
          });
        }

        // Handle genuine session completion. Monitoring was already stopped by
        // TimerProvider._completeSession, so we only navigate to the praise flow.
        if (timerProvider.state == TimerState.completed && !_handledCompletion) {
          _handledCompletion = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.timerCompleted);
            }
          });
        }

        final remaining = timerProvider.focusRemainingSeconds;
        final totalSeconds = timerProvider.sessionFocusDurationMinutes * 60;
        final progress = totalSeconds > 0 ? (totalSeconds - remaining) / totalSeconds : 0.0;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldStop = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('End Focus Session?'),
                content: const Text('Are you sure you want to exit? Your session progress will be saved.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('End Session', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (shouldStop == true && context.mounted) {
              await timerProvider.cancelSession();
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Focus Session'),
              centerTitle: true,
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Subject Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.book, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            timerProvider.sessionSubject,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Countdown Timer Progress Dial
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            strokeWidth: 12,
                            backgroundColor: AppColors.primaryContainer,
                            color: AppColors.primary,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(remaining),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              timerProvider.isFocusRunning ? 'STAY FOCUSED' : 'PAUSED',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: timerProvider.isFocusRunning ? AppColors.successGreen : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Session Distraction & Break Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatChip(
                          icon: Icons.notifications_active_outlined,
                          label: 'Distractions',
                          value: '${timerProvider.distractionCount}',
                          color: AppColors.roastOrange,
                        ),
                        _buildStatChip(
                          icon: Icons.coffee_outlined,
                          label: 'Breaks',
                          value: '${timerProvider.breaksCompleted}/${timerProvider.sessionNumberOfBreaks}',
                          color: AppColors.breakCalm,
                        ),
                      ],
                    ),

                    // Controls (Pause, Resume, Stop)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (timerProvider.isFocusRunning)
                          FloatingActionButton.large(
                            heroTag: 'pause',
                            backgroundColor: Colors.orange,
                            onPressed: timerProvider.pauseTimer,
                            child: const Icon(Icons.pause, size: 36, color: Colors.white),
                          )
                        else
                          FloatingActionButton.large(
                            heroTag: 'resume',
                            backgroundColor: AppColors.primary,
                            onPressed: timerProvider.resumeTimer,
                            child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
                          ),
                        const SizedBox(width: 24),
                        FloatingActionButton.large(
                          heroTag: 'stop',
                          backgroundColor: Colors.red,
                          onPressed: () async {
                            await timerProvider.cancelSession();
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Icon(Icons.stop, size: 36, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
