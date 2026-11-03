import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_indicator.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
      if (user != null) {
        Provider.of<SessionProvider>(context, listen: false).fetchSessions(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Activities'),
      ),
      body: sessionProvider.isLoading
          ? const LoadingIndicator(message: 'Loading sessions...')
          : sessionProvider.userSessions.isEmpty
              ? const EmptyStateWidget(
                  message: 'No activities yet.',
                  icon: Icons.history_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessionProvider.userSessions.length,
                  itemBuilder: (context, index) {
                    final session = sessionProvider.userSessions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: session.completed
                                            ? AppColors.successBackground
                                            : AppColors.roastBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        session.completed
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        color: session.completed
                                            ? AppColors.successGreen
                                            : AppColors.roastOrange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      session.subject,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${session.actualDuration} min',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormatter.formatDateTime(session.startTime),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.roastOrange),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${session.distractionCount} roasts',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.coffee_rounded, size: 14, color: AppColors.breakTeal),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${session.breaksCompleted} breaks',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
