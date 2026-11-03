import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/focus_session.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/firestore_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Advanced Analytics')),
        body: const EmptyStateWidget(message: 'Not enough data yet.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
      ),
      body: StreamBuilder<List<FocusSession>>(
        stream: FirestoreService().getUserSessions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return const EmptyStateWidget(
              message: 'Not enough data yet.',
              icon: Icons.analytics_outlined,
            );
          }

          final metrics = AnalyticsService.calculateMetrics(sessions);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Summary Section
                const Text(
                  "Today's Summary",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: AppColors.analyticsBlue,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Focus Time Today', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${metrics.todayMinutes} mins',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        Container(height: 40, width: 1, color: Colors.white30),
                        Column(
                          children: [
                            const Text('Completed', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${metrics.totalCompletedSessions}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Detailed Metrics Grid
                const Text(
                  'Focus Performance Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildAnalyticsTile(
                      title: 'Weekly Focus Time',
                      value: '${metrics.weeklyMinutes} min',
                      icon: Icons.date_range,
                      color: AppColors.primary,
                    ),
                    _buildAnalyticsTile(
                      title: 'Monthly Focus Time',
                      value: '${metrics.monthlyMinutes} min',
                      icon: Icons.calendar_month,
                      color: Colors.purple,
                    ),
                    _buildAnalyticsTile(
                      title: 'Total Distractions',
                      value: '${metrics.totalDistractions}',
                      icon: Icons.notifications_active_outlined,
                      color: AppColors.roastOrange,
                    ),
                    _buildAnalyticsTile(
                      title: 'Avg Session Duration',
                      value: '${metrics.averageSessionMinutes.toStringAsFixed(1)} min',
                      icon: Icons.timer,
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Subject Distribution Section
                const Text(
                  'Most Studied Subjects',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (metrics.subjectDistribution.isEmpty)
                  const Text('No subject data yet.', style: TextStyle(color: AppColors.textSecondary))
                else
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: metrics.subjectDistribution.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.book, size: 18, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(
                                  '${entry.value} min',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
