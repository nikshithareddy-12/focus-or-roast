import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/streak_calculator.dart';
import '../../models/focus_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Streak'),
      ),
      body: user == null
          ? const Center(child: Text('Please log in to view streak.'))
          : StreamBuilder<List<FocusSession>>(
              stream: FirestoreService().getUserSessions(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data ?? [];
                final streakResult = StreakCalculator.calculate(sessions);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fire Streak Hero Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        color: AppColors.roastOrange,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(Icons.local_fire_department, size: 72, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(
                                '${streakResult.currentStreak} Day${streakResult.currentStreak == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'CURRENT STREAK',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Metrics Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _buildMetricCard(
                            label: 'Longest Streak',
                            value: '${streakResult.longestStreak} Days',
                            icon: Icons.emoji_events_outlined,
                            color: Colors.amber.shade800,
                          ),
                          _buildMetricCard(
                            label: 'Weekly Sessions',
                            value: '${streakResult.weeklySessions}',
                            icon: Icons.calendar_view_week,
                            color: AppColors.primary,
                          ),
                          _buildMetricCard(
                            label: 'Monthly Sessions',
                            value: '${streakResult.monthlySessions}',
                            icon: Icons.calendar_month,
                            color: AppColors.analyticsBlue,
                          ),
                          _buildMetricCard(
                            label: 'Total Active Days',
                            value: '${streakResult.activeDates.length}',
                            icon: Icons.check_circle_outline,
                            color: AppColors.successGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick 7-Day Visual Progress Row
                      const Text(
                        'Past 7 Days Activity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(7, (index) {
                          final date = DateTime.now().subtract(Duration(days: 6 - index));
                          final normDate = DateTime(date.year, date.month, date.day);
                          final isActive = streakResult.activeDates.contains(normDate);
                          final dayName = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];

                          return Column(
                            children: [
                              Text(dayName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isActive ? AppColors.roastOrange : AppColors.surfaceVariant,
                                child: Icon(
                                  isActive ? Icons.local_fire_department : Icons.close,
                                  size: 18,
                                  color: isActive ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // View Analytics Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text('View Analytics'),
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.analytics);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
